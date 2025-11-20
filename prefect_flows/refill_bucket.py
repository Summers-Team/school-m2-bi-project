"""
Flow Prefect pour générer et ingérer les données brutes dans GCS

Ce module orchestre la génération des données de seed (couche Bronze) et leur
upload vers Google Cloud Storage. Il constitue la première étape du pipeline
data engineering avant les transformations dbt.

Architecture du pipeline :
    1. Génération locale : Exécution du seed_script.py via subprocess
    2. Upload GCS : Transfert des fichiers CSV/JSON vers le bucket d'ingestion
    3. Validation : Vérification que tous les fichiers sont bien uploadés

Usage :
    # Exécution locale
    uv run python prefect_flows/refill_bucket.py
    
    # Avec Prefect Cloud (déploiement)
    prefect deployment build prefect_flows/refill_bucket.py:refill_bucket_flow -n "refill-bucket" -p default-pool
    prefect deployment apply refill_bucket_flow-deployment.yaml
    prefect deployment run refill-bucket-flow/refill-bucket

Prérequis :
    - Bloc Prefect 'gcp-credentials' configuré avec les credentials GCP
    - Bucket GCS 'test-terraform-473818-ingested-data' provisionné via Terraform
    - Script seed_script.py présent dans prefect_flows/seed_scripts/
"""

from datetime import datetime
from prefect import flow, task, get_run_logger
from prefect_gcp import GcpCredentials
from google.cloud import storage
from pathlib import Path
import subprocess
import sys


# Configuration globale du bucket et des fichiers
GCS_BUCKET_NAME = "test-terraform-473818-ingested-data"
GCS_PREFIX = "raw_data/"  # Préfixe pour organiser les fichiers dans le bucket
RAW_DATA_DIR = Path(__file__).parent.parent / "raw_data"
SEED_SCRIPT_PATH = Path(__file__).parent / "seed_scripts" / "seed_script.py"

# Liste des fichiers attendus après génération
EXPECTED_FILES = [
    "contents.csv",
    "users.csv", 
    "viewing_logs.json",
    "social_media_mentions.json"
]


@task(name="generate-seed-data", retries=1, retry_delay_seconds=10)
def generate_seed_data():
    """
    Génère les données de seed en exécutant le script seed_script.py.
    
    Cette tâche utilise subprocess pour exécuter le script Python de génération
    de données. Le script crée 4 fichiers dans le dossier raw_data/ :
        - contents.csv : Catalogue de contenus (50 entrées)
        - users.csv : Utilisateurs du service VoD (500 entrées)
        - viewing_logs.json : Logs de visionnage (10000 entrées)
        - social_media_mentions.json : Mentions réseaux sociaux (2000 entrées)
    
    Pourquoi subprocess plutôt qu'un import direct ?
    - Isolation : Le script de seed peut être exécuté indépendamment
    - Flexibilité : On peut facilement modifier le script sans casser le flow
    - Logs séparés : Les prints du seed_script sont capturés distinctement
    
    Returns:
        Path: Le chemin vers le dossier contenant les fichiers générés
        
    Raises:
        subprocess.CalledProcessError: Si le script de génération échoue
    """
    logger = get_run_logger()
    
    # Vérification de l'existence du script de seed
    if not SEED_SCRIPT_PATH.exists():
        logger.error(f"Le script de seed n'existe pas : {SEED_SCRIPT_PATH}")
        raise FileNotFoundError(f"Script introuvable : {SEED_SCRIPT_PATH}")
    
    logger.info(f"Démarrage de la génération des données de seed...")
    logger.info(f"Script utilisé : {SEED_SCRIPT_PATH}")
    logger.info(f"Dossier de sortie : {RAW_DATA_DIR}")
    
    try:
        # Exécution du script de génération
        # check=True : Lève une exception si le script retourne un code d'erreur
        # capture_output=True : Capture stdout/stderr pour les logs
        # text=True : Retourne des strings plutôt que des bytes
        result = subprocess.run(
            [sys.executable, str(SEED_SCRIPT_PATH)],
            check=True,
            capture_output=True,
            text=True,
            cwd=Path(__file__).parent.parent  # Exécute depuis la racine du projet
        )
        
        # Affichage des logs du script dans les logs Prefect
        if result.stdout:
            logger.info(f"Sortie du script de seed :\n{result.stdout}")
        
        logger.info(f"Génération terminée avec succès")
        
        # Vérification que tous les fichiers attendus ont été créés
        missing_files = []
        for filename in EXPECTED_FILES:
            file_path = RAW_DATA_DIR / filename
            if not file_path.exists():
                missing_files.append(filename)
        
        if missing_files:
            logger.error(f"Fichiers manquants après génération : {missing_files}")
            raise FileNotFoundError(f"Fichiers manquants : {missing_files}")
        
        logger.info(f"Tous les fichiers attendus ont été générés : {EXPECTED_FILES}")
        return RAW_DATA_DIR
        
    except subprocess.CalledProcessError as e:
        logger.error(f"Erreur lors de l'exécution du script de seed")
        logger.error(f"Code de retour : {e.returncode}")
        if e.stdout:
            logger.error(f"stdout : {e.stdout}")
        if e.stderr:
            logger.error(f"stderr : {e.stderr}")
        raise


@task(name="upload-to-gcs", retries=3, retry_delay_seconds=30)
def upload_files_to_gcs(data_dir: Path):
    """
    Upload les fichiers de données brutes vers Google Cloud Storage.
    
    Cette tâche transfère tous les fichiers générés vers le bucket GCS
    d'ingestion. Les fichiers sont organisés avec un préfixe pour faciliter
    leur gestion et leur traçabilité dans le bucket.
    
    Architecture GCS :
        Bucket : test-terraform-473818-ingested-data
        └── raw_data/
            ├── contents.csv
            ├── users.csv
            ├── viewing_logs.json
            └── social_media_mentions.json
    
    Pourquoi plusieurs retries ?
    - Réseau : Les uploads peuvent échouer temporairement
    - Quota : GCP peut throttler les requêtes en cas de pic
    - Robustesse : On veut maximiser la fiabilité du pipeline
    
    Stratégie d'authentification :
    1. Tente de charger le bloc Prefect 'gcp-credentials' (mode Cloud)
    2. Fallback sur Application Default Credentials (mode local)
    
    Args:
        data_dir: Chemin vers le dossier contenant les fichiers à uploader
        
    Returns:
        dict: Métadonnées sur les fichiers uploadés (nom, taille, URI GCS)
        
    Raises:
        Exception: Si l'upload échoue après tous les retries
    """
    logger = get_run_logger()
    
    run_timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

    logger.info(f"Démarrage de l'upload vers GCS...")
    logger.info(f"Bucket cible : gs://{GCS_BUCKET_NAME}/{GCS_PREFIX}")
    
    # Tentative de chargement du bloc GCP Credentials
    # Ce bloc centralise les credentials dans Prefect Cloud
    storage_client = None
    try:
        logger.info("Tentative de chargement du bloc 'gcp-credentials'...")
        gcp_credentials_block = GcpCredentials.load("gcp-credentials")
        logger.info("Bloc GCP Credentials chargé avec succès (mode Cloud)")
        
        # Création du client Storage authentifié via le bloc
        storage_client = storage.Client(
            credentials=gcp_credentials_block.get_credentials_from_service_account(),
            project=gcp_credentials_block.project
        )
    except Exception as e:
        logger.warning(f"Impossible de charger le bloc 'gcp-credentials': {e}")
        logger.info("Basculement sur Application Default Credentials (mode local)...")
        
        # Fallback : utilise les credentials par défaut (ex: gcloud auth)
        # Pratique pour le développement local
        storage_client = storage.Client()
    
    # Récupération du bucket
    try:
        bucket = storage_client.bucket(GCS_BUCKET_NAME)
        logger.info(f"Bucket '{GCS_BUCKET_NAME}' accessible")
    except Exception as e:
        logger.error(f"Impossible d'accéder au bucket '{GCS_BUCKET_NAME}': {e}")
        logger.error("Vérifiez que le bucket existe et que vous avez les permissions nécessaires")
        raise
    
    # Upload de chaque fichier
    uploaded_files = []
    total_size = 0
    
    for filename in EXPECTED_FILES:
        file_path = data_dir / filename
        
        if not file_path.exists():
            logger.warning(f"Fichier ignoré (non trouvé) : {filename}")
            continue
        
        # Construction du chemin GCS avec préfixe
        # Ex: raw_data/contents.csv
        gcs_path = f"{GCS_PREFIX}{run_timestamp}/{filename}"
        
        logger.info(f"Upload de {filename}...")
        logger.info(f"  - Source locale : {file_path}")
        logger.info(f"  - Destination GCS : gs://{GCS_BUCKET_NAME}/{gcs_path}")
        
        try:
            # Création du blob (objet GCS) et upload
            blob = bucket.blob(gcs_path)
            blob.upload_from_filename(str(file_path))
            
            # Récupération des métadonnées pour confirmation
            file_size = file_path.stat().st_size
            total_size += file_size
            
            uploaded_files.append({
                "filename": filename,
                "gcs_uri": f"gs://{GCS_BUCKET_NAME}/{gcs_path}",
                "size_bytes": file_size,
                "size_mb": round(file_size / (1024 * 1024), 2)
            })
            
            logger.info(f"Upload réussi : {filename} ({round(file_size / 1024, 2)} KB)")
            
        except Exception as e:
            logger.error(f"Erreur lors de l'upload de {filename}: {e}")
            raise
    
    # Résumé de l'opération
    logger.info(f"Upload terminé avec succès")
    logger.info(f"  - Fichiers uploadés : {len(uploaded_files)}/{len(EXPECTED_FILES)}")
    logger.info(f"  - Taille totale : {round(total_size / (1024 * 1024), 2)} MB")
    
    return {
        "bucket": GCS_BUCKET_NAME,
        "prefix": GCS_PREFIX,
        "files": uploaded_files,
        "total_files": len(uploaded_files),
        "total_size_mb": round(total_size / (1024 * 1024), 2)
    }


@flow(name="refill-bucket-flow", log_prints=True)
def refill_bucket_flow():
    """
    Flow principal : Génère les données de seed et les upload vers GCS.
    
    Ce flow orchestre le pipeline complet d'ingestion de la couche Bronze :
        1. Génération des données fictives (seed_script.py)
        2. Upload vers Google Cloud Storage
        3. Retour des métadonnées pour traçabilité
    
    Architecture du pipeline data :
    
        [seed_script.py] --> [raw_data/] --> [GCS Bucket] --> [dbt models] --> [BigQuery]
              (Bronze)         (local)       (Bronze)          (Silver/Gold)   (Data Warehouse)
    
    Ce flow constitue la première étape du pipeline ELT (Extract-Load-Transform) :
    - Extract : Génération de données (simulation de sources externes)
    - Load : Upload vers GCS (Data Lake)
    - Transform : Sera géré par dbt dans le flow pipeline.py
    
    Pourquoi séparer génération et transformation ?
    - Modularité : Chaque flow a une responsabilité unique et claire
    - Réutilisabilité : On peut re-générer les données sans re-transformer
    - Debugging : Plus facile d'identifier où se situe un problème
    - Scheduling : On peut planifier différemment (ex: seed 1x/mois, transform 1x/jour)
    
    Cas d'usage :
    - Développement : Régénérer des données de test fraîches
    - Demo : Créer un nouveau jeu de données pour une présentation
    - Testing : Valider le pipeline E2E avec des données cohérentes
    
    Returns:
        dict: Résumé de l'exécution (fichiers générés, uploadés, métadonnées)
        
    Exemples d'utilisation:
        
        # Exécution locale immédiate
        uv run python prefect_flows/refill_bucket.py
        
        # Création d'un déploiement Prefect Cloud (scheduling)
        prefect deployment build prefect_flows/refill_bucket.py:refill_bucket_flow \\
            -n "refill-bucket-weekly" \\
            -p default-pool \\
            --cron "0 0 * * 0"  # Tous les dimanches à minuit
        
        prefect deployment apply refill_bucket_flow-deployment.yaml
        
        # Déclenchement manuel via l'UI ou la CLI
        prefect deployment run refill-bucket-flow/refill-bucket-weekly
    """
    logger = get_run_logger()
    
    logger.info("Démarrage du flow de remplissage du bucket GCS")
    logger.info("=" * 60)
    
    # Étape 1 : Génération des données de seed
    logger.info("ÉTAPE 1/2 : Génération des données fictives")
    logger.info("-" * 60)
    data_dir = generate_seed_data()
    logger.info(f"Données générées dans : {data_dir}")
    
    # Étape 2 : Upload vers GCS
    logger.info("\nÉTAPE 2/2 : Upload des données vers Google Cloud Storage")
    logger.info("-" * 60)
    upload_result = upload_files_to_gcs(data_dir)
    
    # Résumé final
    logger.info("\n" + "=" * 60)
    logger.info("PIPELINE TERMINÉ AVEC SUCCÈS")
    logger.info("=" * 60)
    logger.info(f"Bucket GCS : gs://{upload_result['bucket']}")
    logger.info(f"Préfixe : {upload_result['prefix']}")
    logger.info(f"Fichiers uploadés : {upload_result['total_files']}")
    logger.info(f"Taille totale : {upload_result['total_size_mb']} MB")
    logger.info("\nDétail des fichiers :")
    for file_info in upload_result['files']:
        logger.info(f"  - {file_info['filename']} : {file_info['size_mb']} MB")
        logger.info(f"    URI : {file_info['gcs_uri']}")
    
    logger.info("\nProchaine étape : Exécuter le pipeline dbt pour transformer ces données")
    logger.info("Commande : uv run python prefect_flows/pipeline.py")
    
    return {
        "status": "success",
        "data_directory": str(data_dir),
        "gcs_upload": upload_result
    }


if __name__ == "__main__":
    """
    Point d'entrée pour l'exécution locale du flow.
    
    Usage :
        uv run python prefect_flows/refill_bucket.py
    """
    # Exécution locale du flow
    result = refill_bucket_flow()
    
    print("\n" + "=" * 60)
    print("RÉSUMÉ DE L'EXÉCUTION")
    print("=" * 60)
    print(f"Statut : {result['status']}")
    print(f"Données générées : {result['data_directory']}")
    print(f"Fichiers uploadés : {result['gcs_upload']['total_files']}")
    print(f"Taille totale : {result['gcs_upload']['total_size_mb']} MB")
    print("=" * 60)


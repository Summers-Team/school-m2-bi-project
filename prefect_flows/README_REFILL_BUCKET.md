# Guide d'Utilisation : Flow refill_bucket.py

## Vue d'Ensemble

Ce flow Prefect génère des données fictives (seed) et les upload automatiquement dans le bucket GCS pour alimenter la couche Bronze de votre pipeline data.

## Prérequis

### 1. Infrastructure GCP Provisionnée

Vérifier que Terraform a créé les ressources :

```bash
cd infrastructure
terraform output
```

Sortie attendue :
```
project_id = "test-terraform-473818"
ingested_data_bucket = "test-terraform-473818-ingested-data"
sa_email = "test-terraform-473818-sa@test-terraform-473818.iam.gserviceaccount.com"
```

### 2. Authentification GCP

**Option A : Prefect Cloud (Production)**

Le bloc `gcp-credentials` doit être configuré dans Prefect Cloud avec les credentials du service account.

Vérification :
```bash
prefect block ls
```

Vous devez voir le bloc `gcp-credentials` dans la liste.

**Option B : Développement Local**

Authentification via gcloud CLI :
```bash
# Authentification avec votre compte Google
gcloud auth application-default login

# OU utiliser le service account directement
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/sa_key.json"
```

### 3. Dépendances Python

Vérifier que les packages sont installés :
```bash
uv pip list | grep -E "(prefect|google|faker)"
```

Packages requis :
- `prefect-gcp` : Intégration GCP dans Prefect
- `google-cloud-storage` : Client Python pour GCS
- `faker` : Génération de données fictives

Si manquant :
```bash
uv sync
```

## Utilisation

### Exécution Locale (Mode Dev)

```bash
# Depuis la racine du projet
uv run python prefect_flows/refill_bucket.py
```

**Ce que fait le flow :**

1. **Génération** (task `generate_seed_data`)
   - Exécute `seed_script.py`
   - Crée 4 fichiers dans `raw_data/` :
     - `contents.csv` (50 contenus)
     - `users.csv` (500 utilisateurs)
     - `viewing_logs.json` (10 000 logs)
     - `social_media_mentions.json` (2 000 mentions)

2. **Upload** (task `upload_files_to_gcs`)
   - Upload vers `gs://test-terraform-473818-ingested-data/raw_data/`
   - Affiche les URIs et tailles des fichiers

**Sortie attendue :**

```
Démarrage du flow de remplissage du bucket GCS
============================================================
ÉTAPE 1/2 : Génération des données fictives
------------------------------------------------------------
Génération de 50 contenus...
Génération de 500 utilisateurs...
Génération de 10000 logs de visionnage...
Génération de 2000 mentions sur les réseaux sociaux...
✅ Génération des données terminée avec succès !

ÉTAPE 2/2 : Upload des données vers Google Cloud Storage
------------------------------------------------------------
Tentative de chargement du bloc 'gcp-credentials'...
⚠️  Impossible de charger le bloc 'gcp-credentials': ...
Basculement sur Application Default Credentials (mode local)...
Upload de contents.csv...
  - Source locale : /path/to/raw_data/contents.csv
  - Destination GCS : gs://test-terraform-473818-ingested-data/raw_data/contents.csv
✅ Upload réussi : contents.csv (12.34 KB)
...

============================================================
PIPELINE TERMINÉ AVEC SUCCÈS
============================================================
Fichiers uploadés : 4
Taille totale : 2.45 MB

Détail des fichiers :
  - contents.csv : 0.01 MB
    URI : gs://test-terraform-473818-ingested-data/raw_data/contents.csv
  ...
```

### Vérification de l'Upload

**Via gcloud CLI :**

```bash
# Lister les fichiers dans le bucket
gsutil ls gs://test-terraform-473818-ingested-data/raw_data/

# Afficher le contenu d'un fichier
gsutil cat gs://test-terraform-473818-ingested-data/raw_data/contents.csv | head -5
```

**Via Console GCP :**

1. Aller sur https://console.cloud.google.com/storage
2. Sélectionner le projet `test-terraform-473818`
3. Cliquer sur le bucket `test-terraform-473818-ingested-data`
4. Vérifier la présence du dossier `raw_data/` avec les 4 fichiers

### Déploiement sur Prefect Cloud

**1. Créer le déploiement**

```bash
# Déploiement simple (exécution manuelle)
prefect deployment build \
    prefect_flows/refill_bucket.py:refill_bucket_flow \
    -n "refill-bucket-manual" \
    -p default-pool

# OU déploiement avec scheduling (hebdomadaire)
prefect deployment build \
    prefect_flows/refill_bucket.py:refill_bucket_flow \
    -n "refill-bucket-weekly" \
    -p default-pool \
    --cron "0 0 * * 0"  # Dimanches à minuit
```

**2. Appliquer le déploiement**

```bash
prefect deployment apply refill_bucket_flow-deployment.yaml
```

**3. Déclencher le déploiement**

**Via CLI :**
```bash
prefect deployment run refill-bucket-flow/refill-bucket-manual
```

**Via UI Prefect Cloud :**
1. Aller sur https://app.prefect.cloud
2. Naviguer vers "Deployments"
3. Cliquer sur "refill-bucket-manual"
4. Cliquer sur "Quick Run"

## Configuration Avancée

### Personnaliser le Volume de Données

Éditer `prefect_flows/seed_scripts/seed_script.py` :

```python
# Ligne 13-17
NUM_CONTENTS = 100          # Défaut : 50
NUM_USERS = 1000            # Défaut : 500
NUM_VIEWING_LOGS = 50000    # Défaut : 10000
NUM_SOCIAL_MENTIONS = 5000  # Défaut : 2000
```

**Impact sur le pipeline :**
- Plus de données → temps d'upload plus long
- Plus de données → transformations dbt plus longues
- Recommandation dev : garder les valeurs par défaut
- Recommandation prod : augmenter pour tester la scalabilité

### Changer le Bucket GCS Cible

Éditer `prefect_flows/refill_bucket.py` :

```python
# Ligne 41
GCS_BUCKET_NAME = "mon-autre-bucket"
GCS_PREFIX = "data/bronze/"  # Changer l'organisation
```

**Attention :** Le bucket doit exister et vous devez avoir les permissions `storage.objectAdmin`.

### Organiser les Fichiers par Date

Pour éviter d'écraser les données à chaque run (utile pour l'analyse historique) :

```python
# Dans upload_files_to_gcs(), ligne 154
from datetime import datetime
date_prefix = datetime.now().strftime("%Y/%m/%d")
gcs_path = f"{GCS_PREFIX}{date_prefix}/{filename}"
```

Structure résultante :
```
gs://bucket/raw_data/
  ├── 2025/11/10/
  │   ├── contents.csv
  │   ├── users.csv
  │   └── ...
  └── 2025/11/11/
      ├── contents.csv
      └── ...
```

**Avantage :** Historisation des données
**Inconvénient :** Nécessite d'ajuster les sources dbt pour lire la dernière partition

## Troubleshooting

### Erreur : "Script introuvable"

```
FileNotFoundError: Script introuvable : /path/to/seed_scripts/seed_script.py
```

**Cause :** Le script de seed n'est pas au bon emplacement.

**Solution :**
```bash
# Vérifier l'existence du fichier
ls prefect_flows/seed_scripts/seed_script.py

# Si manquant, le recréer depuis la racine du projet
```

### Erreur : "Impossible d'accéder au bucket"

```
Impossible d'accéder au bucket 'test-terraform-473818-ingested-data': 403 Forbidden
```

**Cause :** Problème d'authentification ou de permissions.

**Solutions :**

1. **Vérifier l'authentification locale :**
```bash
gcloud auth application-default login
gcloud config set project test-terraform-473818
```

2. **Vérifier les permissions du service account :**
```bash
# Lister les IAM bindings
gcloud projects get-iam-policy test-terraform-473818 \
    --flatten="bindings[].members" \
    --filter="bindings.members:serviceAccount:test-terraform-473818-sa@*"
```

Le service account doit avoir `roles/storage.objectAdmin`.

3. **Vérifier que le bloc Prefect est correct :**
```bash
prefect block inspect gcp-credentials
```

### Erreur : "Fichiers manquants après génération"

```
FileNotFoundError: Fichiers manquants : ['viewing_logs.json']
```

**Cause :** Le script de seed a échoué partiellement.

**Solution :**
```bash
# Exécuter le script de seed manuellement pour voir l'erreur
cd prefect_flows/seed_scripts
python seed_script.py

# Vérifier les dépendances
uv pip list | grep faker
```

### Le Flow est Lent

**Symptôme :** L'upload prend plus de 5 minutes.

**Causes possibles :**
1. Connexion internet lente
2. Volume de données trop important
3. Throttling GCP (quota dépassé)

**Solutions :**
1. Réduire `NUM_VIEWING_LOGS` dans `seed_script.py`
2. Compresser les fichiers avant upload (modification du flow nécessaire)
3. Vérifier les quotas GCP : https://console.cloud.google.com/iam-admin/quotas

## Intégration avec le Pipeline dbt

Une fois les données uploadées dans GCS, elles sont prêtes pour dbt :

```bash
# 1. Uploader les données (ce flow)
uv run python prefect_flows/refill_bucket.py

# 2. Transformer avec dbt
uv run python prefect_flows/pipeline.py
```

**Dans les modèles dbt**, les données GCS sont référencées via `sources.yml` :

```yaml
# dbt/models/staging/sources.yml
sources:
  - name: gcs
    description: Données brutes depuis Google Cloud Storage
    tables:
      - name: contents
        identifier: raw_data/contents.csv
      - name: viewing_logs
        identifier: raw_data/viewing_logs.json
```

## Métriques et Monitoring

### Logs Prefect

**Local :**
Les logs sont affichés dans le terminal.

**Prefect Cloud :**
1. Aller sur https://app.prefect.cloud
2. Naviguer vers "Flow Runs"
3. Cliquer sur l'exécution du flow
4. Voir les logs détaillés par task

### Métriques Clés

À surveiller dans les logs :
- **Temps de génération** : Devrait être < 10 secondes (valeurs par défaut)
- **Temps d'upload** : Devrait être < 30 secondes (valeurs par défaut)
- **Taille totale des fichiers** : ~2-3 MB (valeurs par défaut)
- **Taux de retry** : 0 en conditions normales

### Alertes (Prefect Cloud)

Configurer des alertes sur :
- Échec du flow après tous les retries
- Durée d'exécution > 5 minutes (indicateur de problème)
- Upload incomplet (< 4 fichiers uploadés)

## Évolutions Futures

### Idées d'Amélioration

1. **Incrémentalité** : Ajouter de nouvelles données sans écraser les anciennes
2. **Validation** : Tester la qualité des données générées (Great Expectations)
3. **Compression** : Compresser les fichiers JSON (réduction de 70-80% de la taille)
4. **Parallélisme** : Uploader les 4 fichiers en parallèle (gain de temps)
5. **Notification** : Envoyer un email/Slack après succès ou échec

### Exemple : Upload Parallèle

```python
from prefect import task
import asyncio

@task
async def upload_file_async(file_path, bucket, gcs_path):
    # Upload asynchrone
    ...

@flow
def refill_bucket_flow_parallel():
    # Upload des 4 fichiers en parallèle
    tasks = [
        upload_file_async.submit(f, bucket, gcs_path)
        for f in EXPECTED_FILES
    ]
    results = await asyncio.gather(*tasks)
```

**Gain estimé :** 3-4x plus rapide pour l'upload.

## Ressources

- **Documentation Prefect** : https://docs.prefect.io
- **Documentation prefect-gcp** : https://prefecthq.github.io/prefect-gcp/
- **Documentation Faker** : https://faker.readthedocs.io
- **Best Practices GCS** : https://cloud.google.com/storage/docs/best-practices

## Support

En cas de problème :
1. Vérifier les logs Prefect (détaillés)
2. Tester le script de seed isolément : `python prefect_flows/seed_scripts/seed_script.py`
3. Tester l'accès GCS manuellement : `gsutil ls gs://test-terraform-473818-ingested-data/`
4. Consulter la documentation complète : `documentation/architecture_pipeline_complet.md`


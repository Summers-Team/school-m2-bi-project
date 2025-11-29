"""
Prefect flows for dbt profile generation and block configuration.
"""
from pathlib import Path
from typing import Dict, Any

from prefect import flow

from .tasks import (
    parse_template_targets,
    load_terraform_outputs,
    build_profile_context,
    render_profile_template,
    write_local_profile,
    setup_gcp_credentials,
    setup_bigquery_target,
    setup_dbt_profile,
    setup_dbt_operation,
)


@flow(name="generate-local-profiles", log_prints=True)
def generate_local_profiles_pipeline(
    outputs_json_path: Path | None = None,
    template_path: Path | None = None,
    output_path: Path | None = None,
):
    """
    Pipeline pour générer les profils dbt locaux depuis les outputs Terraform
    
    Cette pipeline:
    1. Charge les outputs Terraform
    2. Construit le contexte de rendu
    3. Rend le template
    4. Écrit le fichier profiles.yml local
    
    En local:
        uv run python -m infrastructure.setup_profiles --local-only
    
    Args:
        outputs_json_path: Chemin vers terraform-outputs.json (default: infrastructure/terraform-outputs.json)
        template_path: Chemin vers le template (default: dbt/profiles.tpl.yml)
        output_path: Chemin de sortie (default: dbt/profiles.yml)
    
    Returns:
        Path du fichier profiles.yml généré
    """
    project_root = Path(__file__).parent.parent.parent
    
    if outputs_json_path is None:
        outputs_json_path = project_root / "infrastructure" / "terraform-outputs.json"
    if template_path is None:
        template_path = project_root / "dbt" / "profiles.tpl.yml"
    if output_path is None:
        output_path = project_root / "dbt" / "profiles.yml"
    
    print("🔧 Génération des profils dbt locaux...")
    print(f"  Template: {template_path.relative_to(project_root)}")
    print(f"  Outputs: {outputs_json_path.relative_to(project_root)}")
    print(f"  Destination: {output_path.relative_to(project_root)}")
    
    # 1. Charge les outputs Terraform
    print("\n📥 Étape 1/4 : Chargement des outputs Terraform...")
    outputs = load_terraform_outputs(outputs_json_path)
    
    # 2. Construit le contexte
    print("\n🏗️  Étape 2/4 : Construction du contexte...")
    context = build_profile_context(outputs, project_root, output_path)
    
    # 3. Rend le template
    print("\n📝 Étape 3/4 : Rendu du template...")
    rendered_content = render_profile_template(template_path, context)
    
    # 4. Écrit le fichier
    print("\n💾 Étape 4/4 : Écriture du fichier...")
    result_path = write_local_profile(rendered_content, output_path)
    
    print(f"\n✅ Profils dbt générés avec succès dans {result_path.relative_to(project_root)}")
    return result_path


@flow(name="setup-dbt-blocks", log_prints=True)
def setup_dbt_blocks_pipeline(
    gcp_project: str,
    credentials_block_name: str = "gcp-credentials",
    service_account_file: Path | None = None,
    template_path: Path | None = None,
    outputs_json_path: Path | None = None,
    dbt_commands: list[str] = None,
):
    """
    Pipeline complète pour configurer tous les blocs Prefect nécessaires pour dbt
    
    Cette pipeline:
    1. Parse le template pour identifier tous les targets définis
    2. Charge les outputs Terraform pour obtenir les datasets
    3. Crée les credentials GCP
    4. Pour chaque target du template:
       - Configure BigQuery avec le dataset approprié
       - Configure le profil dbt
       - Configure l'opération dbt
    
    En local:
        uv run python -m infrastructure.setup_profiles --blocks-only
    
    Args:
        gcp_project: ID du projet GCP
        credentials_block_name: Nom du bloc où sauvegarder les credentials GCP
        service_account_file: Chemin vers le fichier JSON du service account (default: .secrets/sa_key.json)
        template_path: Chemin vers le template profiles.tpl.yml (default: dbt/profiles.tpl.yml)
        outputs_json_path: Chemin vers terraform-outputs.json (default: infrastructure/terraform-outputs.json)
        dbt_commands: Liste des commandes dbt (default: ["dbt debug"])
    
    Returns:
        Dict avec les noms des blocs créés pour chaque target
    """
    if dbt_commands is None:
        dbt_commands = ["dbt debug"]
    
    project_root = Path(__file__).parent.parent.parent
    
    if service_account_file is None:
        service_account_file = project_root / ".secrets" / "sa_key.json"
    
    if template_path is None:
        template_path = project_root / "dbt" / "profiles.tpl.yml"
    
    if outputs_json_path is None:
        outputs_json_path = project_root / "infrastructure" / "terraform-outputs.json"
    
    dbt_project_dir = project_root / "dbt"

    print("🚀 Démarrage de la configuration des blocs dbt...")
    
    # 1. Parse le template pour extraire les targets
    print("\n📋 Étape 1/5 : Parsing du template dbt...")
    template_info = parse_template_targets(template_path)
    profile_name = template_info["profile_name"]
    targets = template_info["targets"]
    default_target = template_info["default_target"]
    
    print(f"   Profile: {profile_name}")
    print(f"   Default target: {default_target}")
    print(f"   Targets trouvés: {', '.join(targets.keys())}")
    
    # 2. Charge les outputs Terraform
    print("\n📥 Étape 2/5 : Chargement des outputs Terraform...")
    outputs = load_terraform_outputs(outputs_json_path)
    
    # 3. Crée les credentials GCP depuis le fichier
    print("\n🔑 Étape 3/5 : Création des credentials GCP...")
    credentials = setup_gcp_credentials(credentials_block_name, gcp_project, service_account_file)
    
    # 4. Pour chaque target, crée les blocs appropriés
    print(f"\n🎯 Étape 4/5 : Configuration des blocs pour {len(targets)} target(s)...")
    
    results = {
        "profile_name": profile_name,
        "default_target": default_target,
        "credentials": credentials_block_name,
        "targets": {}
    }
    
    for target_name, target_config in targets.items():
        print(f"\n  📊 Configuration du target '{target_name}'...")
        
        # Récupérer le dataset depuis les outputs Terraform
        dataset_key = f"bq_{target_name}_dataset_id"
        if dataset_key not in outputs:
            print(f"     ⚠️  Warning: {dataset_key} non trouvé dans les outputs Terraform, utilisation du nom par défaut")
            schema_name = f"{gcp_project.replace('-', '_')}_{target_name}"
        else:
            schema_name = outputs[dataset_key].get("value") if isinstance(outputs[dataset_key], dict) else outputs[dataset_key]
        
        # Récupérer threads et location depuis le template
        threads = target_config.get("threads", 1)
        location = target_config.get("location", "europe-west9")
        
        # Remplacer les variables du template dans location (ex: ${region})
        if isinstance(location, str) and "${" in location:
            from string import Template
            location_template = Template(location)
            # Préparer le contexte avec les outputs Terraform
            location_context = {
                "region": outputs.get("region", {}).get("value") if isinstance(outputs.get("region"), dict) else outputs.get("region", "europe-west9")
            }
            location = location_template.safe_substitute(location_context)
        
        # Noms des blocs pour ce target
        target_configs_block_name = f"bigquery-target-configs-{target_name}"
        dbt_profile_block_name = f"dbt-cli-profile-{target_name}"
        dbt_operation_run_block_name = f"dbt-operation-run-{target_name}"
        dbt_operation_test_block_name = f"dbt-operation-test-{target_name}"
        dbt_operation_debug_block_name = f"dbt-operation-debug-{target_name}"
        
        print(f"     - Dataset: {schema_name}")
        print(f"     - Threads: {threads}")
        print(f"     - Location: {location}")
        
        # Configure BigQuery
        target_configs = setup_bigquery_target(
            credentials=credentials,
            schema_name=schema_name,
            target_configs_block_name=target_configs_block_name,
            threads=threads,
            location=location
        )
        
        # Configure le profil dbt
        dbt_profile = setup_dbt_profile(
            target_configs=target_configs,
            profile_name=profile_name,
            target_name=target_name,
            dbt_profile_block_name=dbt_profile_block_name
        )
        
        # Configure les opérations dbt (run, test, debug)
        print(f"     - Création des blocs d'opération...")
        
        dbt_operation_run = setup_dbt_operation(
            dbt_profile=dbt_profile,
            dbt_profile_block_name=dbt_profile_block_name,
            dbt_commands=[f"dbt run --target {target_name}"],
            dbt_operation_block_name=dbt_operation_run_block_name,
            project_dir=dbt_project_dir
        )
        
        dbt_operation_test = setup_dbt_operation(
            dbt_profile=dbt_profile,
            dbt_profile_block_name=dbt_profile_block_name,
            dbt_commands=[f"dbt test --target {target_name}"],
            dbt_operation_block_name=dbt_operation_test_block_name,
            project_dir=dbt_project_dir
        )
        
        dbt_operation_debug = setup_dbt_operation(
            dbt_profile=dbt_profile,
            dbt_profile_block_name=dbt_profile_block_name,
            dbt_commands=[f"dbt debug --target {target_name}"],
            dbt_operation_block_name=dbt_operation_debug_block_name,
            project_dir=dbt_project_dir
        )
        
        results["targets"][target_name] = {
            "target_configs": target_configs_block_name,
            "dbt_profile": dbt_profile_block_name,
            "dbt_operation_run": dbt_operation_run_block_name,
            "dbt_operation_test": dbt_operation_test_block_name,
            "dbt_operation_debug": dbt_operation_debug_block_name,
            "schema": schema_name,
            "threads": threads,
            "location": location
        }
        
        print(f"     ✅ Target '{target_name}' configuré avec succès")
    
    print("\n📝 Étape 5/5 : Résumé de la configuration...")
    print(f"\n✅ Configuration des blocs dbt terminée avec succès !")
    print(f"   Profile dbt: {profile_name}")
    print(f"   Credentials: {credentials_block_name}")
    print(f"\n   Targets configurés:")
    for target_name, target_blocks in results["targets"].items():
        marker = " (default)" if target_name == default_target else ""
        print(f"     • {target_name}{marker}:")
        print(f"       - Profile block: {target_blocks['dbt_profile']}")
        print(f"       - Operation blocks:")
        print(f"         * run: {target_blocks['dbt_operation_run']}")
        print(f"         * test: {target_blocks['dbt_operation_test']}")
        print(f"         * debug: {target_blocks['dbt_operation_debug']}")
        print(f"       - Dataset: {target_blocks['schema']}")
    
    return results


@flow(name="setup-dbt-complete", log_prints=True)
def setup_dbt_complete_pipeline(
    gcp_project: str,
    credentials_block_name: str = "gcp-credentials",
    service_account_file: Path | None = None,
    outputs_json_path: Path | None = None,
    template_path: Path | None = None,
    profiles_output_path: Path | None = None,
    dbt_commands: list[str] = None,
    skip_local_profiles: bool = False,
):
    """
    Pipeline complète pour configurer dbt en local ET dans Prefect
    
    Cette pipeline:
    1. Génère les profils dbt locaux depuis le template (sauf si skip_local_profiles=True)
    2. Configure tous les blocs Prefect pour chaque target du template
    
    En local:
        uv run python -m infrastructure.setup_profiles
    
    Args:
        gcp_project: ID du projet GCP
        credentials_block_name: Nom du bloc credentials GCP
        service_account_file: Chemin vers le service account JSON
        outputs_json_path: Chemin vers terraform-outputs.json
        template_path: Chemin vers profiles.tpl.yml
        profiles_output_path: Chemin de sortie pour profiles.yml
        dbt_commands: Commandes dbt à exécuter
        skip_local_profiles: Skip la génération des profils locaux
    
    Returns:
        Dict avec les chemins/noms des ressources créées
    """
    print("🎯 Configuration complète de dbt (local + Prefect)")
    
    local_profile_path = None
    if not skip_local_profiles:
        print("\n" + "="*60)
        print("PARTIE 1 : GÉNÉRATION DES PROFILS LOCAUX")
        print("="*60)
        local_profile_path = generate_local_profiles_pipeline(
            outputs_json_path=outputs_json_path,
            template_path=template_path,
            output_path=profiles_output_path,
        )
    
    print("\n" + "="*60)
    print("PARTIE 2 : CONFIGURATION DES BLOCS PREFECT")
    print("="*60)
    blocks = setup_dbt_blocks_pipeline(
        gcp_project=gcp_project,
        credentials_block_name=credentials_block_name,
        service_account_file=service_account_file,
        template_path=template_path,
        outputs_json_path=outputs_json_path,
        dbt_commands=dbt_commands,
    )
    
    print("\n" + "="*60)
    print("✨ CONFIGURATION COMPLÈTE TERMINÉE !")
    print("="*60)
    
    result = {
        "local_profile": str(local_profile_path) if local_profile_path else None,
        **blocks
    }
    
    for key, value in result.items():
        if value:
            print(f"  {key}: {value}")
    
    return result

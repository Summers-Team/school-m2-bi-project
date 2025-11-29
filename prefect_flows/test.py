"""
Simple test flow to validate dbt operation blocks
"""
from pathlib import Path
from prefect import flow
from prefect_dbt.cli import DbtCoreOperation, DbtCliProfile, BigQueryTargetConfigs

@flow(name="test-dbt-debug", log_prints=True)
def test_dbt_debug_flow():
    """
    Test flow pour valider le bloc d'opération dbt debug
    
    Charge et exécute le bloc dbt-operation-debug-dev
    
    Usage:
        uv run python prefect_flows/test.py
    """
    project_dir = Path(__file__).parent.parent / "dbt"

    bigquery_target_configs = BigQueryTargetConfigs.load("dbt-bq-target-dev")
    # print(f"Block BigQueryTargetConfigs : {bigquery_target_configs.model_dump_json()}")
    print(f"Block BigQueryTargetConfigs : {bigquery_target_configs.get_configs()}")
    

    # Charger le bloc profil dbt
    dbt_cli_profile_block = DbtCliProfile.load("dbt-cli-profile-dev")
    # print(f"Block DbtCliProfile : {dbt_cli_profile_block.model_dump_json()}")
    print(f"Block DbtCliProfile : {dbt_cli_profile_block.get_profile()}")
    
    

    # Recreate the full profile with updated target configs
    dbt_cli_profile = DbtCliProfile(
        name=dbt_cli_profile_block.name,
        target=dbt_cli_profile_block.target,
        target_configs=bigquery_target_configs
    )
    
    print(f"Recreated DbtCliProfile: {dbt_cli_profile.get_profile()}")
    
    # Construire l'opération dbt run
    dbt_operation = DbtCoreOperation(
        project_dir=project_dir,
        overwrite_profiles=True,
        dbt_cli_profile=dbt_cli_profile,
        commands=["dbt debug"],
        target="dev",
    )
    print(f"Using dbt operation: {dbt_operation}")  
    result = dbt_operation.run()
    
    return result


if __name__ == "__main__":
    # Exécution locale pour tester
    test_dbt_debug_flow()

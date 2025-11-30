{% macro create_external_sources() %}
  {# 
    Crée les tables externes BigQuery pointant vers GCS
    Utilise les variables du target (profiles.yml) pour être dynamique
    
    Structure GCS attendue (Hive Partitioning) :
    gs://bucket/raw_data/ingestion_date=YYYY-MM-DD/fichier.csv
  #}
  
  {% set bucket_name = target.project ~ '-ingested-data-' ~ target.name %}
  {% set gcs_prefix = 'raw_data/' %}
  
  
  {% if target.name in ['dev', 'prod'] %}
    
    -- Table externe pour les contenus
    CREATE OR REPLACE EXTERNAL TABLE `{{ target.project }}.{{ target.dataset }}.raw_contents`
    WITH PARTITION COLUMNS (
      ingestion_date DATE
    )
    OPTIONS (
      format = 'CSV',
      uris = ['gs://{{ bucket_name }}/{{ gcs_prefix }}ingestion_date=*/contents.csv'],
      skip_leading_rows = 1,
      hive_partition_uri_prefix = 'gs://{{ bucket_name }}/{{ gcs_prefix }}',
      require_hive_partition_filter = false
    );
    {{ log("Table externe créée: raw_contents", info=True) }}

    -- Table externe pour les utilisateurs
    CREATE OR REPLACE EXTERNAL TABLE `{{ target.project }}.{{ target.dataset }}.raw_users`
    WITH PARTITION COLUMNS (
      ingestion_date DATE
    )
    OPTIONS (
      format = 'CSV',
      uris = ['gs://{{ bucket_name }}/{{ gcs_prefix }}ingestion_date=*/users.csv'],
      skip_leading_rows = 1,
      hive_partition_uri_prefix = 'gs://{{ bucket_name }}/{{ gcs_prefix }}',
      require_hive_partition_filter = false
    );
    {{ log("Table externe créée: raw_users", info=True) }}

    -- Table externe pour les logs de visionnage
    CREATE OR REPLACE EXTERNAL TABLE `{{ target.project }}.{{ target.dataset }}.raw_viewing_logs`
    WITH PARTITION COLUMNS (
      ingestion_date DATE
    )
    OPTIONS (
      format = 'JSON',
      uris = ['gs://{{ bucket_name }}/{{ gcs_prefix }}ingestion_date=*/viewing_logs.json'],
      hive_partition_uri_prefix = 'gs://{{ bucket_name }}/{{ gcs_prefix }}',
      require_hive_partition_filter = false
    );
    {{ log("Table externe créée: raw_viewing_logs", info=True) }}

    -- Table externe pour les mentions sociales
    CREATE OR REPLACE EXTERNAL TABLE `{{ target.project }}.{{ target.dataset }}.raw_social_media_mentions`
    WITH PARTITION COLUMNS (
      ingestion_date DATE
    )
    OPTIONS (
      format = 'JSON',
      uris = ['gs://{{ bucket_name }}/{{ gcs_prefix }}ingestion_date=*/social_media_mentions.json'],
      hive_partition_uri_prefix = 'gs://{{ bucket_name }}/{{ gcs_prefix }}',
      require_hive_partition_filter = false
    );
    {{ log("Table externe créée: raw_social_media_mentions", info=True) }}
    
    {{ log("Toutes les tables externes ont été créées avec succès!", info=True) }}
    
  {% else %}
    {{ log("Environnement non reconnu: " ~ target.name ~ ". Tables externes non créées.", info=True) }}
  {% endif %}
  
{% endmacro %}
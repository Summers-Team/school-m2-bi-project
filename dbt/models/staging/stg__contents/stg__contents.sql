{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT 
    content_id,
    title,
    series_name,
    season_number,
    episode_number,
    genre,
    target_age_group,
    production_type,
    release_date,
    duration_minutes,
    CAST(production_cost_euros AS INT64) AS production_cost_euros,
    CAST(ingestion_date AS DATE) as ingestion_date
FROM {{ source('raw_gcs', 'raw_contents') }}
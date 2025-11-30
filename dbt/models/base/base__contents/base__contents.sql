{{ config(
    materialized='view',
    schema='base'
) }}

WITH source AS (
    SELECT * FROM {{ ref('stg__contents') }}
),

-- SNAPSHOT STRATEGY
latest_source AS (
    SELECT *
    FROM source
    WHERE ingestion_date = (SELECT MAX(ingestion_date) FROM source)
),

cleaned AS (
    SELECT
        TRIM(content_id) AS content_id,
        TRIM(title) AS title,
        TRIM(series_name) AS series_name,
        CAST(season_number AS INT64) AS season_number,
        CAST(episode_number AS INT64) AS episode_number,
        TRIM(genre) AS genre,
        TRIM(target_age_group) AS target_age_group,
        TRIM(production_type) AS production_type,
        release_date,
        CAST(duration_minutes AS INT64) AS duration_minutes,
        CAST(production_cost_euros AS INT64) AS production_cost_euros,
        ingestion_date,
        CURRENT_TIMESTAMP() AS _loaded_at
    FROM latest_source
    WHERE content_id IS NOT NULL
),

-- Deduplication interne
deduplicated AS (
    SELECT *
    FROM cleaned
    QUALIFY ROW_NUMBER() OVER (PARTITION BY content_id ORDER BY release_date DESC) = 1
)

SELECT * FROM deduplicated

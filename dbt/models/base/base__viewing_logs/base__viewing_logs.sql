{{ config(
    materialized='view',
    schema='base'
) }}

WITH source AS (
    SELECT * FROM {{ ref('stg__viewing_logs') }}
),

-- SNAPSHOT STRATEGY
latest_source AS (
    SELECT *
    FROM source
    WHERE ingestion_date = (SELECT MAX(ingestion_date) FROM source)
),

cleaned AS (
    SELECT
        TRIM(session_id) AS session_id,
        TRIM(user_id) AS user_id,
        TRIM(content_id) AS content_id,
        start_timestamp,
        end_timestamp,
        CAST(watch_duration_seconds AS INT64) AS watch_duration_seconds,
        LOWER(TRIM(device_type)) AS device_type,
        LOWER(TRIM(os)) AS os,
        ingestion_date,
        CURRENT_TIMESTAMP() AS _loaded_at
    FROM latest_source
    WHERE 
        session_id IS NOT NULL
        AND watch_duration_seconds > 0
),

-- Deduplication interne (au cas où le csv du jour contienne des doublons)
deduplicated AS (
    SELECT *
    FROM cleaned
    QUALIFY ROW_NUMBER() OVER (PARTITION BY session_id ORDER BY start_timestamp DESC) = 1
)

SELECT * FROM deduplicated

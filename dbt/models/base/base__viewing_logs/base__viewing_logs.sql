{{ config(
    materialized='view',
    schema='base'
) }}

WITH source AS (
    SELECT * FROM {{ ref('stg__viewing_logs') }}
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
    FROM source
    WHERE 
        session_id IS NOT NULL
        AND watch_duration_seconds > 0
),

-- Deduplication: keep only one occurrence per session_id
-- Strategy: Latest ingestion wins (ingestion_date DESC)
deduplicated AS (
    SELECT *
    FROM cleaned
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY session_id 
        ORDER BY ingestion_date DESC, start_timestamp DESC
    ) = 1
)

SELECT * FROM deduplicated

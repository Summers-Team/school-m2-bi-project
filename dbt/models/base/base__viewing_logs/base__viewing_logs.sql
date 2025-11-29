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
        CURRENT_TIMESTAMP() AS _loaded_at
    FROM source
    WHERE 
        session_id IS NOT NULL
        AND watch_duration_seconds > 0
),

-- Deduplication: keep only one occurrence per session_id
-- In case of duplicates across multiple runs, keep the session with the most recent start timestamp
-- (business logic: we want to keep the most recent version of a session)
deduplicated AS (
    SELECT *
    FROM cleaned
    QUALIFY ROW_NUMBER() OVER (PARTITION BY session_id ORDER BY start_timestamp DESC, end_timestamp DESC) = 1
)

SELECT * FROM deduplicated

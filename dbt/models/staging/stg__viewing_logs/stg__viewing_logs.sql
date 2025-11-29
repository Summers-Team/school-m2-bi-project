{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT 
    session_id,
    user_id,
    content_id,
    start_timestamp,
    end_timestamp,
    watch_duration_seconds,
    device_type,
    os
FROM {{ source('raw_gcs', 'raw_viewing_logs') }}
{{ config(
    materialized='table',
    schema='marts'
) }}

WITH base_viewing_logs AS (
    SELECT DISTINCT
        device_type,
        os
    FROM {{ ref('base__viewing_logs') }}
    WHERE device_type IS NOT NULL
      AND os IS NOT NULL
),

dim_devices AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['device_type', 'os']) }} AS device_sk,
        device_type,
        os
    FROM base_viewing_logs
)

SELECT * FROM dim_devices


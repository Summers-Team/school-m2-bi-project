{{ config(
    materialized='view',
    schema='marts'
) }}

WITH fct_viewings AS (
    SELECT * FROM {{ ref('fct__viewings') }}
),

dim_devices AS (
    SELECT * FROM {{ ref('dim__devices') }}
),

device_metrics AS (
    SELECT
        dd.device_type,
        dd.os,
        COUNT(*) AS total_views,
        COUNT(DISTINCT fv.user_fk) AS unique_viewers,
        SUM(fv.view_duration_minutes) / 60.0 AS total_viewing_hours,
        AVG(fv.completion_rate) AS avg_completion_rate
    FROM fct_viewings fv
    INNER JOIN dim_devices dd
        ON fv.device_fk = dd.device_sk
    GROUP BY
        dd.device_type,
        dd.os
)

SELECT
    device_type,
    os,
    total_views,
    unique_viewers,
    total_viewing_hours,
    avg_completion_rate,
    CAST(total_views AS FLOAT64) / SUM(total_views) OVER () AS views_percentage
FROM device_metrics
ORDER BY total_views DESC


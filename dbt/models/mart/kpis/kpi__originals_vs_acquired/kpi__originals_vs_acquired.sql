{{ config(
    materialized='view',
    schema='marts'
) }}

WITH fct_viewings AS (
    SELECT * FROM {{ ref('fct__viewings') }}
),

dim_content AS (
    SELECT * FROM {{ ref('dim__content') }}
),

production_metrics AS (
    SELECT
        dc.production_type,
        COUNT(*) AS total_views,
        COUNT(DISTINCT fv.user_fk) AS unique_viewers,
        SUM(fv.view_duration_minutes) / 60.0 AS total_viewing_hours,
        AVG(fv.completion_rate) AS avg_completion_rate,
        SUM(CASE WHEN fv.is_completed_view THEN 1 ELSE 0 END) AS completed_views,
        CAST(SUM(CASE WHEN fv.is_completed_view THEN 1 ELSE 0 END) AS FLOAT64) / COUNT(*) AS completion_percentage
    FROM fct_viewings fv
    INNER JOIN dim_content dc
        ON fv.content_fk = dc.content_sk
    GROUP BY dc.production_type
)

SELECT
    production_type,
    total_views,
    unique_viewers,
    total_viewing_hours,
    avg_completion_rate,
    completed_views,
    completion_percentage
FROM production_metrics
ORDER BY production_type


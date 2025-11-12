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

completion_metrics AS (
    SELECT
        dc.series_name,
        dc.genre,
        COUNT(*) AS total_views,
        AVG(fv.completion_rate) AS avg_completion_rate,
        SUM(CASE WHEN fv.is_completed_view THEN 1 ELSE 0 END) AS completed_views,
        CAST(SUM(CASE WHEN fv.is_completed_view THEN 1 ELSE 0 END) AS FLOAT64) / COUNT(*) AS completion_percentage
    FROM fct_viewings fv
    INNER JOIN dim_content dc
        ON fv.content_fk = dc.content_sk
    GROUP BY
        dc.series_name,
        dc.genre
)

SELECT
    series_name,
    genre,
    total_views,
    avg_completion_rate,
    completed_views,
    completion_percentage
FROM completion_metrics
ORDER BY avg_completion_rate DESC


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
dim_series AS (
    SELECT * FROM {{ ref('dim__series') }}
),

program_metrics AS (
    SELECT
        dc.content_id,
        dc.title,
        ds.series_name,
        ds.genre,
        dc.production_type,
        COUNT(*) AS total_views,
        COUNT(DISTINCT fv.user_fk) AS unique_viewers,
        SUM(fv.view_duration_minutes) / 60.0 AS total_viewing_hours,
        AVG(fv.completion_rate) AS avg_completion_rate
    FROM fct_viewings fv
    INNER JOIN dim_content dc
        ON fv.content_fk = dc.content_sk
    INNER JOIN dim_series ds
        ON fv.series_fk = ds.series_sk
    GROUP BY
        dc.content_id,
        dc.title,
        ds.series_name,
        ds.genre,
        dc.production_type
),

ranked_programs AS (
    SELECT
        *,
        ROW_NUMBER() OVER (ORDER BY total_views DESC) AS rank_by_views,
        ROW_NUMBER() OVER (ORDER BY unique_viewers DESC) AS rank_by_viewers,
        ROW_NUMBER() OVER (ORDER BY total_viewing_hours DESC) AS rank_by_hours
    FROM program_metrics
)

SELECT
    content_id,
    title,
    series_name,
    genre,
    production_type,
    total_views,
    unique_viewers,
    total_viewing_hours,
    avg_completion_rate,
    rank_by_views,
    rank_by_viewers,
    rank_by_hours
FROM ranked_programs
WHERE rank_by_views <= 10
ORDER BY rank_by_views


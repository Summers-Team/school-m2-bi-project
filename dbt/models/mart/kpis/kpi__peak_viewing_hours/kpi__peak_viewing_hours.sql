{{ config(
    materialized='view',
    schema='marts'
) }}

WITH int_enriched AS (
    SELECT
        session_id,
        user_id,
        start_timestamp,
        viewing_date,
        view_duration_minutes,
        EXTRACT(HOUR FROM start_timestamp) AS viewing_hour
    FROM {{ ref('int__viewing_enriched') }}
),

dim_date AS (
    SELECT * FROM {{ ref('dim__date') }}
),

dim_users AS (
    SELECT * FROM {{ ref('dim__users') }}
),

hourly_viewings AS (
    SELECT
        iv.viewing_hour,
        dd.day_of_week,
        COUNT(*) AS total_views,
        COUNT(DISTINCT du.user_sk) AS unique_viewers,
        SUM(iv.view_duration_minutes) / 60.0 AS total_viewing_hours
    FROM int_enriched iv
    INNER JOIN dim_users du
        ON iv.user_id = du.user_id
    INNER JOIN dim_date dd
        ON iv.viewing_date = dd.full_date
    GROUP BY
        iv.viewing_hour,
        dd.day_of_week
)

SELECT
    viewing_hour,
    day_of_week,
    total_views,
    unique_viewers,
    total_viewing_hours
FROM hourly_viewings
ORDER BY total_views DESC


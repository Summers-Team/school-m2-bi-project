{{ config(
    materialized='view',
    schema='marts'
) }}

WITH fct_viewings AS (
    SELECT * FROM {{ ref('fct__viewings') }}
),

dim_date AS (
    SELECT * FROM {{ ref('dim__date') }}
),

viewing_hours AS (
    SELECT
        dd.full_date,
        dd.year,
        dd.quarter,
        dd.month,
        dd.day_of_week,
        -- Weekly aggregation: get the start of week (Monday)
        DATE_SUB(dd.full_date, INTERVAL EXTRACT(DAYOFWEEK FROM dd.full_date) - 2 DAY) AS week_start_date,
        SUM(fv.view_duration_minutes) / 60.0 AS total_viewing_hours
    FROM fct_viewings fv
    INNER JOIN dim_date dd
        ON fv.date_fk = dd.date_sk
    GROUP BY
        dd.full_date,
        dd.year,
        dd.quarter,
        dd.month,
        dd.day_of_week
)

SELECT
    full_date,
    year,
    quarter,
    month,
    day_of_week,
    week_start_date,
    total_viewing_hours
FROM viewing_hours
ORDER BY full_date DESC


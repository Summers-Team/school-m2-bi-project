{{ config(
    materialized='table',
    schema='marts'
) }}

WITH date_spine AS (
    {{ dbt_date.date_spine(
        datepart="day",
        start_date="cast('2020-01-01' as date)",
        end_date="cast('2030-12-31' as date)"
    )}}
),

dim_date AS (
    SELECT
        CAST(FORMAT_DATE('%Y%m%d', date_day) AS INT64) AS date_sk,
        date_day AS full_date,
        EXTRACT(YEAR FROM date_day) AS year,
        EXTRACT(QUARTER FROM date_day) AS quarter,
        EXTRACT(MONTH FROM date_day) AS month,
        FORMAT_DATE('%A', date_day) AS day_of_week,
        CASE 
            WHEN EXTRACT(DAYOFWEEK FROM date_day) IN (1, 7) THEN TRUE
            ELSE FALSE
        END AS is_weekend
    FROM date_spine
)

SELECT * FROM dim_date


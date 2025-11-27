{{ config(
    materialized='table',
    schema='marts'
) }}

WITH base_contents AS (
    SELECT * FROM {{ ref('base__contents') }}
),

dim_content AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['content_id']) }} AS content_sk,
        content_id,
        title,
        season_number,
        episode_number,
        release_date,
        EXTRACT(YEAR FROM release_date) AS release_year,
        duration_minutes,
        production_cost_euros
    FROM base_contents
)

SELECT * FROM dim_content


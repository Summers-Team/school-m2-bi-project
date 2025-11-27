{{ config(
    materialized='table',
    schema='marts'
) }}

WITH base_contents AS (
    SELECT * FROM {{ ref('base__contents') }}
),

dim_series AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['series_id']) }} AS series_sk,

        series_name,
        genre,
        target_age_group,
        production_type,
        EXTRACT(YEAR FROM MIN(release_date)) AS first_release_year,
        COUNT(DISTINCT season_number) AS total_seasons,
        COUNT(DISTINCT episode_number) AS total_episodes
        
    FROM base_contents
)

SELECT * FROM dim_series

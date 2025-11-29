{{ config(
    materialized='table',
    schema='marts'
) }}

WITH base_contents AS (
    SELECT * FROM {{ ref('base__contents') }}
),

viewing_enriched AS (
    SELECT * FROM {{ ref('int__viewing_enriched') }}
),

user_viewing_sessions AS (
    SELECT
        user_id,
        viewing_date,
        series_name,
        COUNT(DISTINCT content_id) AS episodes_watched
    FROM viewing_enriched
    GROUP BY
        user_id,
        viewing_date,
        series_name
),

binge_stats AS (
    SELECT
        series_name,
        COUNT(DISTINCT CASE WHEN episodes_watched >= 3 THEN user_id END) AS binge_watchers_count,
        COUNT(DISTINCT user_id) AS total_viewers
    FROM user_viewing_sessions
    GROUP BY series_name
),

base_series_stats AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['series_name']) }} AS series_sk,

        series_name,
        genre,
        target_age_group,
        EXTRACT(YEAR FROM MIN(release_date)) AS first_release_year,
        COUNT(DISTINCT season_number) AS total_seasons,
        COUNT(DISTINCT episode_number) AS total_episodes
        
    FROM base_contents
    GROUP BY
        series_name,
        genre,
        target_age_group,
        production_type
),

final AS (
    SELECT
        bss.*,
        COALESCE(bs.binge_watchers_count, 0) AS binge_watchers_count,
        COALESCE(bs.total_viewers, 0) AS total_viewers
    FROM base_series_stats bss
    LEFT JOIN binge_stats bs
        ON bss.series_name = bs.series_name
)

SELECT * FROM final

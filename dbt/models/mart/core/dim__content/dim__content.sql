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

base_social_media AS (
    SELECT * FROM {{ ref('base__social_media') }}
),

-- 1. Viewing Stats (for Cost per Viewing Hour)
viewing_stats AS (
    SELECT
        content_id,
        SUM(view_duration_minutes) / 60.0 AS total_viewing_hours
    FROM viewing_enriched
    GROUP BY content_id
),

-- 2. Sentiment Analysis
sentiment_scoring AS (
    SELECT
        content_id,
        mention_text,
        CASE
            WHEN LOWER(mention_text) LIKE '%ador%' 
                 OR LOWER(mention_text) LIKE '%super%'
                 OR LOWER(mention_text) LIKE '%incroyable%'
                 OR LOWER(mention_text) LIKE '%magnifique%'
                 OR LOWER(mention_text) LIKE '%excellent%'
                 OR LOWER(mention_text) LIKE '%bravo%'
            THEN 1.0
            WHEN LOWER(mention_text) LIKE '%déçu%'
                 OR LOWER(mention_text) LIKE '%nul%'
                 OR LOWER(mention_text) LIKE '%mauvais%'
                 OR LOWER(mention_text) LIKE '%décevant%'
            THEN -1.0
            ELSE 0.0
        END AS sentiment_score
    FROM base_social_media
    WHERE content_id IS NOT NULL
),

sentiment_stats AS (
    SELECT
        content_id,
        COUNT(*) AS total_mentions,
        AVG(sentiment_score) AS avg_sentiment_score,
        SUM(CASE WHEN sentiment_score > 0 THEN 1 ELSE 0 END) AS positive_mentions,
        SUM(CASE WHEN sentiment_score < 0 THEN 1 ELSE 0 END) AS negative_mentions,
        SUM(CASE WHEN sentiment_score = 0 THEN 1 ELSE 0 END) AS neutral_mentions
    FROM sentiment_scoring
    GROUP BY content_id
),

dim_content AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['bc.content_id']) }} AS content_sk,
        bc.content_id,
        bc.title,
        bc.season_number,
        bc.episode_number,
        bc.release_date,
        bc.production_type,
        EXTRACT(YEAR FROM bc.release_date) AS release_year,
        bc.duration_minutes,
        bc.production_cost_euros,

        -- Cost per Viewing Hour
        COALESCE(vs.total_viewing_hours, 0) AS total_viewing_hours,
        CASE 
            WHEN COALESCE(vs.total_viewing_hours, 0) > 0 THEN
                bc.production_cost_euros / vs.total_viewing_hours
            ELSE NULL
        END AS cost_per_viewing_hour,

        -- Sentiment Analysis
        COALESCE(ss.total_mentions, 0) AS total_mentions,
        ss.avg_sentiment_score,
        COALESCE(ss.positive_mentions, 0) AS positive_mentions,
        COALESCE(ss.negative_mentions, 0) AS negative_mentions,
        COALESCE(ss.neutral_mentions, 0) AS neutral_mentions,
        CASE 
            WHEN COALESCE(ss.total_mentions, 0) > 0 THEN
                CAST(ss.positive_mentions AS FLOAT64) / ss.total_mentions
            ELSE NULL
        END AS positive_rate,
        CASE 
            WHEN COALESCE(ss.total_mentions, 0) > 0 THEN
                CAST(ss.negative_mentions AS FLOAT64) / ss.total_mentions
            ELSE NULL
        END AS negative_rate

    FROM base_contents bc
    LEFT JOIN viewing_stats vs
        ON bc.content_id = vs.content_id
    LEFT JOIN sentiment_stats ss
        ON bc.content_id = ss.content_id
)

SELECT * FROM dim_content


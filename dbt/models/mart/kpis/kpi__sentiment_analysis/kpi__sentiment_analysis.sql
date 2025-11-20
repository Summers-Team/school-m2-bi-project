{{ config(
    materialized='view',
    schema='marts'
) }}

WITH base_social_media AS (
    SELECT * FROM {{ ref('base__social_media') }}
),

dim_content AS (
    SELECT * FROM {{ ref('dim__content') }}
),

sentiment_scoring AS (
    SELECT
        bsm.mention_id,
        bsm.content_id,
        bsm.content_title_mentioned,
        bsm.mention_text,
        dc.production_type,
        -- Simple sentiment analysis based on keywords
        CASE
            WHEN LOWER(bsm.mention_text) LIKE '%ador%' 
                 OR LOWER(bsm.mention_text) LIKE '%super%'
                 OR LOWER(bsm.mention_text) LIKE '%incroyable%'
                 OR LOWER(bsm.mention_text) LIKE '%magnifique%'
                 OR LOWER(bsm.mention_text) LIKE '%excellent%'
                 OR LOWER(bsm.mention_text) LIKE '%bravo%'
            THEN 1.0  -- Positive
            WHEN LOWER(bsm.mention_text) LIKE '%déçu%'
                 OR LOWER(bsm.mention_text) LIKE '%nul%'
                 OR LOWER(bsm.mention_text) LIKE '%mauvais%'
                 OR LOWER(bsm.mention_text) LIKE '%décevant%'
            THEN -1.0  -- Negative
            ELSE 0.0  -- Neutral
        END AS sentiment_score
    FROM base_social_media bsm
    LEFT JOIN dim_content dc
        ON bsm.content_id = dc.content_id
    WHERE dc.production_type = 'Original BigMedia'
      OR dc.production_type IS NULL  -- Include unmatched mentions for now
),

sentiment_by_content AS (
    SELECT
        sm.content_id,
        sm.content_title_mentioned,
        COUNT(*) AS total_mentions,
        AVG(sm.sentiment_score) AS avg_sentiment_score,
        SUM(CASE WHEN sm.sentiment_score > 0 THEN 1 ELSE 0 END) AS positive_mentions,
        SUM(CASE WHEN sm.sentiment_score < 0 THEN 1 ELSE 0 END) AS negative_mentions,
        SUM(CASE WHEN sm.sentiment_score = 0 THEN 1 ELSE 0 END) AS neutral_mentions
    FROM sentiment_scoring sm
    GROUP BY sm.content_id, sm.content_title_mentioned
)

SELECT
    content_id,
    content_title_mentioned,
    total_mentions,
    avg_sentiment_score,
    positive_mentions,
    negative_mentions,
    neutral_mentions,
    CAST(positive_mentions AS FLOAT64) / total_mentions AS positive_rate,
    CAST(negative_mentions AS FLOAT64) / total_mentions AS negative_rate
FROM sentiment_by_content
WHERE total_mentions > 0
ORDER BY avg_sentiment_score DESC


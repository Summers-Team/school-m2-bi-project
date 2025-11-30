{{ config(
    materialized='view',
    schema='base'
) }}

WITH source AS (
    SELECT * FROM {{ ref('stg__social_media_mentions') }}
),

-- SNAPSHOT STRATEGY
latest_source AS (
    SELECT *
    FROM source
    WHERE ingestion_date = (SELECT MAX(ingestion_date) FROM source)
),

cleaned AS (
    SELECT
        -- Primary key
        TRIM(mention_id) AS mention_id,
        
        -- Mentioned content (for matching with base_contents)
        TRIM(content_title_mentioned) AS content_title_mentioned,
        
        -- Unique content identifier
        TRIM(content_id) AS content_id,

        -- Mention metadata
        TRIM(platform) AS platform,
        TRIM(author_id) AS author_id,
        TRIM(mention_text) AS mention_text,

        -- Engagement metrics (basic typing only)
        CAST(likes_count AS INT64) AS likes_count,
        CAST(shares_count AS INT64) AS shares_count,
        
        -- Publication timestamp
        publication_timestamp,
        
        -- Technical metadata
        ingestion_date,
        CURRENT_TIMESTAMP() AS _loaded_at
        
    FROM latest_source
    WHERE 
        -- Validation: filter invalid mentions
        mention_id IS NOT NULL
        AND mention_text IS NOT NULL
        AND content_title_mentioned IS NOT NULL
),

-- Deduplication interne
deduplicated AS (
    SELECT *
    FROM cleaned
    QUALIFY ROW_NUMBER() OVER (PARTITION BY mention_id ORDER BY publication_timestamp DESC) = 1
)

SELECT * FROM deduplicated

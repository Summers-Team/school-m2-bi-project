{{ config(
    materialized='view',
    schema='base'
) }}

WITH source AS (
    SELECT * FROM {{ ref('stg__social_media_mentions') }}
),

cleaned AS (
    SELECT
        -- Primary key
        TRIM(mention_id) AS mention_id,
        
        -- Mentioned content (for matching with base_contents)
        TRIM(content_title_mentioned) AS content_title_mentioned,
        
        -- Mention metadata
        TRIM(platform) AS platform,
        TRIM(author_id) AS author_id,
        TRIM(mention_text) AS mention_text,
        
        -- Engagement metrics (basic typing only)
        CAST(likes_count AS INT64) AS likes_count,
        CAST(shares_count AS INT64) AS shares_count,
        
        -- Publication timestamp
        publication_timestamp,
        
        -- Loading metadata
        CURRENT_TIMESTAMP() AS _loaded_at
        
    FROM source
    WHERE 
        -- Validation: filter invalid mentions
        mention_id IS NOT NULL
        AND mention_text IS NOT NULL
        AND content_title_mentioned IS NOT NULL
),

-- Deduplication: keep only one occurrence per mention_id
-- In case of duplicates across multiple runs, keep the mention with the most recent publication timestamp
-- (business logic: we want to keep the most recent version of a mention)
deduplicated AS (
    SELECT *
    FROM cleaned
    QUALIFY ROW_NUMBER() OVER (PARTITION BY mention_id ORDER BY publication_timestamp DESC, likes_count DESC) = 1
)

SELECT * FROM deduplicated


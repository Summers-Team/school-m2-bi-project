{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT 
    mention_id,
    content_title_mentioned,
    content_id,
    platform,
    author_id,
    mention_text,
    likes_count,
    shares_count,
    publication_timestamp
FROM {{ source('raw_gcs', 'raw_social_media_mentions') }}


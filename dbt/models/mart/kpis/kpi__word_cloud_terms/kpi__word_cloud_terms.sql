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

-- Split mention_text into words
words AS (
    SELECT
        bsm.content_title_mentioned,
        dc.series_name,
        TRIM(word) AS term,
        COUNT(*) AS term_frequency
    FROM base_social_media bsm
    LEFT JOIN dim_content dc
        ON bsm.content_title_mentioned = dc.title
    CROSS JOIN UNNEST(SPLIT(LOWER(REGEXP_REPLACE(bsm.mention_text, r'[^\w\s]', ' ')), ' ')) AS word
    WHERE TRIM(word) != ''
      AND LENGTH(TRIM(word)) > 2  -- Filter out very short words
      AND TRIM(word) NOT IN ('les', 'des', 'une', 'dans', 'pour', 'avec', 'sans', 'sur', 'par', 'est', 'son', 'ses', 'cest', 'mon', 'ma', 'mes', 'le', 'la', 'de', 'du', 'et', 'ou', 'à', 'un')
    GROUP BY
        bsm.content_title_mentioned,
        dc.series_name,
        TRIM(word)
),

ranked_terms AS (
    SELECT
        content_title_mentioned,
        series_name,
        term,
        term_frequency,
        ROW_NUMBER() OVER (PARTITION BY content_title_mentioned ORDER BY term_frequency DESC) AS term_rank
    FROM words
)

SELECT
    content_title_mentioned,
    series_name,
    term,
    term_frequency,
    term_rank
FROM ranked_terms
WHERE term_rank <= 20  -- Top 20 terms per content
ORDER BY content_title_mentioned, term_rank


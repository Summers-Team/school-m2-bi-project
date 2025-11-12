{{ config(
    materialized='view',
    schema='marts'
) }}

WITH fct_viewings AS (
    SELECT * FROM {{ ref('fct__viewings') }}
),

dim_content AS (
    SELECT * FROM {{ ref('dim__content') }}
),

unique_viewers AS (
    SELECT
        dc.content_id,
        dc.title,
        dc.genre,
        COUNT(DISTINCT fv.user_fk) AS unique_viewers_count
    FROM fct_viewings fv
    INNER JOIN dim_content dc
        ON fv.content_fk = dc.content_sk
    GROUP BY
        dc.content_id,
        dc.title,
        dc.genre
)

SELECT * FROM unique_viewers
ORDER BY unique_viewers_count DESC


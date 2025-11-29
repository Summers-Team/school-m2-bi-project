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
dim_series AS (
    SELECT * FROM {{ ref('dim__series') }}
),

unique_viewers AS (
    SELECT
        dc.content_id,
        dc.title,
        ds.genre,
        COUNT(DISTINCT fv.user_fk) AS unique_viewers_count
    FROM fct_viewings fv
    INNER JOIN dim_content dc
        ON fv.content_fk = dc.content_sk
    INNER JOIN dim_series ds
        ON fv.series_fk = ds.series_sk
    GROUP BY
        dc.content_id,
        dc.title,
        ds.genre
)

SELECT * FROM unique_viewers
ORDER BY unique_viewers_count DESC


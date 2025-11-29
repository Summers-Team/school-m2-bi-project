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

dim_date AS (
    SELECT * FROM {{ ref('dim__date') }}
),

dim_series AS (
    SELECT * FROM {{ ref('dim__series') }}
),

user_viewing_sessions AS (
    SELECT
        fv.user_fk,
        fv.date_fk,
        dd.full_date,
        ds.series_name,
        COUNT(DISTINCT fv.content_fk) AS episodes_watched
    FROM fct_viewings fv
    INNER JOIN dim_content dc
        ON fv.content_fk = dc.content_sk
    INNER JOIN dim_date dd
        ON fv.date_fk = dd.date_sk
    INNER JOIN dim_series ds
        ON fv.series_fk = ds.series_sk
    GROUP BY
        fv.user_fk,
        fv.date_fk,
        dd.full_date,
        ds.series_name
),

binge_watchers AS (
    SELECT
        uvs.series_name,
        COUNT(DISTINCT CASE WHEN uvs.episodes_watched >= 3 THEN uvs.user_fk END) AS binge_watchers_count,
        COUNT(DISTINCT uvs.user_fk) AS total_viewers
    FROM user_viewing_sessions uvs
    GROUP BY uvs.series_name
),

series_content_id AS (
    SELECT DISTINCT
        ds.series_name,
        ANY_VALUE(content_id) AS content_id
    FROM dim_content
    INNER JOIN fct_viewings fv
        ON dim_content.content_sk = fv.content_fk
    INNER JOIN dim_series ds
        ON fv.series_fk = ds.series_sk

    GROUP BY ds.series_name
)

SELECT
    sci.content_id,
    bw.series_name,
    bw.binge_watchers_count,
    bw.total_viewers

FROM binge_watchers bw
LEFT JOIN series_content_id sci
    ON bw.series_name = sci.series_name
WHERE bw.total_viewers > 0
ORDER BY bw.binge_watchers_count DESC


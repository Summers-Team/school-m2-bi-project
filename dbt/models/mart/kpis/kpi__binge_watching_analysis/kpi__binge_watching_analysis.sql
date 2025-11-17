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

user_viewing_sessions AS (
    SELECT
        fv.user_fk,
        fv.date_fk,
        dd.full_date,
        dc.series_name,
        dc.content_id,
        COUNT(DISTINCT fv.content_fk) AS episodes_watched
    FROM fct_viewings fv
    INNER JOIN dim_content dc
        ON fv.content_fk = dc.content_sk
    INNER JOIN dim_date dd
        ON fv.date_fk = dd.date_sk
    GROUP BY
        fv.user_fk,
        fv.date_fk,
        dd.full_date,
        dc.series_name
),

binge_watchers AS (
    SELECT
        series_name,
        COUNT(DISTINCT CASE WHEN episodes_watched >= 3 THEN user_fk END) AS binge_watchers_count,
        COUNT(DISTINCT user_fk) AS total_viewers
    FROM user_viewing_sessions
    GROUP BY series_name
)

SELECT
    content_id,
    series_name,
    binge_watchers_count,
    total_viewers,

FROM binge_watchers
WHERE total_viewers > 0
ORDER BY binge_watchers_count DESC


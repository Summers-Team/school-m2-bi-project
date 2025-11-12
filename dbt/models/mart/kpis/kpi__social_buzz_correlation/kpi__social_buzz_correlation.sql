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

base_social_media AS (
    SELECT * FROM {{ ref('base__social_media') }}
),

social_metrics AS (
    SELECT
        bsm.content_title_mentioned,
        COUNT(*) AS total_mentions,
        SUM(bsm.likes_count) AS total_likes,
        SUM(bsm.shares_count) AS total_shares,
        AVG(bsm.likes_count) AS avg_likes_per_mention
    FROM base_social_media bsm
    GROUP BY bsm.content_title_mentioned
),

viewing_metrics AS (
    SELECT
        dc.title,
        COUNT(*) AS total_views,
        COUNT(DISTINCT fv.user_fk) AS unique_viewers,
        SUM(fv.view_duration_minutes) / 60.0 AS total_viewing_hours
    FROM fct_viewings fv
    INNER JOIN dim_content dc
        ON fv.content_fk = dc.content_sk
    GROUP BY dc.title
)

SELECT
    COALESCE(sm.content_title_mentioned, vm.title) AS content_title,
    COALESCE(sm.total_mentions, 0) AS total_mentions,
    COALESCE(sm.total_likes, 0) AS total_likes,
    COALESCE(sm.total_shares, 0) AS total_shares,
    COALESCE(sm.avg_likes_per_mention, 0) AS avg_likes_per_mention,
    COALESCE(vm.total_views, 0) AS total_views,
    COALESCE(vm.unique_viewers, 0) AS unique_viewers,
    COALESCE(vm.total_viewing_hours, 0) AS total_viewing_hours
FROM social_metrics sm
FULL OUTER JOIN viewing_metrics vm
    ON sm.content_title_mentioned = vm.title
ORDER BY total_mentions DESC, total_views DESC


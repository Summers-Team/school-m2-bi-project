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

base_contents AS (
    SELECT * FROM {{ ref('base__contents') }}
),

content_costs AS (
    SELECT
        dc.content_sk,
        dc.content_id,
        dc.title,
        dc.production_type,
        bc.production_cost_euros
    FROM dim_content dc
    INNER JOIN base_contents bc
        ON dc.content_id = bc.content_id
      AND bc.production_cost_euros IS NOT NULL
),

viewing_hours_by_content AS (
    SELECT
        fv.content_fk,
        SUM(fv.view_duration_minutes) / 60.0 AS total_viewing_hours
    FROM fct_viewings fv
    INNER JOIN dim_content dc
        ON fv.content_fk = dc.content_sk
    GROUP BY fv.content_fk
)

SELECT
    cc.content_id,
    cc.title,
    cc.production_cost_euros,
    COALESCE(vh.total_viewing_hours, 0) AS total_viewing_hours,
    CASE 
        WHEN COALESCE(vh.total_viewing_hours, 0) > 0 THEN
            cc.production_cost_euros / vh.total_viewing_hours
        ELSE NULL
    END AS cost_per_viewing_hour
FROM content_costs cc
LEFT JOIN viewing_hours_by_content vh
    ON cc.content_sk = vh.content_fk
ORDER BY cost_per_viewing_hour ASC NULLS LAST


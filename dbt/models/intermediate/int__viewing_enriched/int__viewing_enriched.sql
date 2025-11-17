{{ config(
    materialized='view',
    schema='intermediate'
) }}

WITH viewing_logs AS (
    SELECT * FROM {{ ref('base__viewing_logs') }}
),

users AS (
    SELECT * FROM {{ ref('base__users') }}
),

contents AS (
    SELECT * FROM {{ ref('base__contents') }}
),

enriched AS (
    SELECT
        -- Identifiers
        vl.session_id,
        vl.user_id,
        vl.content_id,
        
        -- Viewing metrics
        vl.watch_duration_seconds,
        c.duration_minutes AS total_duration_minutes,
        CAST(vl.watch_duration_seconds AS FLOAT64) / 60.0 AS view_duration_minutes,
        
        -- Completion rate calculation
        CASE 
            WHEN c.duration_minutes > 0 THEN
                CAST(vl.watch_duration_seconds AS FLOAT64) / (c.duration_minutes * 60.0)
            ELSE 0.0
        END AS completion_rate,
        
        -- Completed view indicator (>= 90%)
        CASE 
            WHEN c.duration_minutes > 0 AND 
                 (CAST(vl.watch_duration_seconds AS FLOAT64) / (c.duration_minutes * 60.0)) >= 0.9 
            THEN TRUE
            ELSE FALSE
        END AS is_completed_view,
        
        -- Timestamps
        vl.start_timestamp,
        vl.end_timestamp,
        DATE(vl.start_timestamp) AS viewing_date,
        
        -- Device information
        vl.device_type,
        vl.os,
        
        -- User attributes (for dimension join)
        u.country AS user_country,
        u.age AS user_age,
        u.registration_date,
        
        -- Content attributes (for dimension join)
        c.title,
        c.series_name,
        c.genre,
        c.target_age_group,
        c.production_type,
        c.release_date,
        c.duration_minutes
        
    FROM viewing_logs vl
    INNER JOIN users u
        ON vl.user_id = u.user_id
    INNER JOIN contents c
        ON vl.content_id = c.content_id
)

SELECT * FROM enriched


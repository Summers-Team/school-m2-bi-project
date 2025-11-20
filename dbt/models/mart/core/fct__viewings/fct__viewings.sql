{{ config(
    materialized='table',
    schema='marts'
) }}

WITH enriched_viewings AS (
    SELECT * FROM {{ ref('int__viewing_enriched') }}
),

dim_users AS (
    SELECT * FROM {{ ref('dim__users') }}
),

dim_content AS (
    SELECT * FROM {{ ref('dim__content') }}
),

dim_devices AS (
    SELECT * FROM {{ ref('dim__devices') }}
),

dim_date AS (
    SELECT * FROM {{ ref('dim__date') }}
),

fct_viewings AS (
    SELECT
        -- Surrogate key for fact table
        {{ dbt_utils.generate_surrogate_key(['ev.session_id']) }} AS viewing_sk,
        
        -- Foreign keys to dimensions
        du.user_sk AS user_fk,
        dc.content_sk AS content_fk,
        dd.date_sk AS date_fk,
        ddev.device_sk AS device_fk,
        
        -- Metrics
        ev.view_duration_minutes,
        ev.completion_rate,
        ev.is_completed_view
        
    FROM enriched_viewings ev
    INNER JOIN dim_users du
        ON ev.user_id = du.user_id
    INNER JOIN dim_content dc
        ON ev.content_id = dc.content_id
    INNER JOIN dim_devices ddev
        ON ev.device_type = ddev.device_type
        AND ev.os = ddev.os
    INNER JOIN dim_date dd
        ON ev.viewing_date = dd.full_date
)

SELECT * FROM fct_viewings


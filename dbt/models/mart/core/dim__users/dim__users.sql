{{ config(
    materialized='table',
    schema='marts'
) }}

WITH base_users AS (
    SELECT * FROM {{ ref('base__users') }}
),

dim_users AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['user_id']) }} AS user_sk,
        user_id,
        country,
        age,
        DATE_DIFF(CURRENT_DATE(), registration_date, DAY) AS days_since_registration
    FROM base_users
)

SELECT * FROM dim_users


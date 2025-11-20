{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT 
    user_id,
    registration_date,
    country,
    age,
    subscription_type
FROM {{ source('raw_gcs', 'raw_users') }}


{{ config(
    materialized='view',
    schema='staging'
) }}

SELECT 
    user_id,
    registration_date,
    country,
    age,
    subscription_type,
    CAST(ingestion_date AS DATE) as ingestion_date
FROM {{ source('raw_gcs', 'raw_users') }}


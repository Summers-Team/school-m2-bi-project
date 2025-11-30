{{ config(
    materialized='view',
    schema='base'
) }}

WITH source AS (
    SELECT * FROM {{ ref('stg__users') }}
),

cleaned AS (
    SELECT
        -- Primary key
        TRIM(user_id) AS user_id,
        
        -- User attributes
        registration_date,
        UPPER(TRIM(country)) AS country,  -- Normalize to uppercase (FR, BE, CH)
        CAST(age AS INT64) AS age,
        TRIM(subscription_type) AS subscription_type,
        
        -- Technical metadata
        ingestion_date,
        CURRENT_TIMESTAMP() AS _loaded_at
        
    FROM source
    WHERE 
        -- Validation: filter invalid users
        user_id IS NOT NULL
        AND registration_date IS NOT NULL
        AND age IS NOT NULL
),

-- Deduplication: keep only one occurrence per user_id
-- Strategy: Latest ingestion wins (ingestion_date DESC)
deduplicated AS (
    SELECT *
    FROM cleaned
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY user_id 
        ORDER BY ingestion_date DESC, registration_date ASC
    ) = 1
)

SELECT * FROM deduplicated

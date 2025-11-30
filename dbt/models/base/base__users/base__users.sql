{{ config(
    materialized='view',
    schema='base'
) }}

WITH source AS (
    SELECT * FROM {{ ref('stg__users') }}
),

-- SNAPSHOT STRATEGY
latest_source AS (
    SELECT *
    FROM source
    WHERE ingestion_date = (SELECT MAX(ingestion_date) FROM source)
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
        
    FROM latest_source
    WHERE 
        -- Validation: filter invalid users
        user_id IS NOT NULL
        AND registration_date IS NOT NULL
        AND age IS NOT NULL
),

-- Deduplication interne
deduplicated AS (
    SELECT *
    FROM cleaned
    QUALIFY ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY registration_date ASC) = 1
)

SELECT * FROM deduplicated

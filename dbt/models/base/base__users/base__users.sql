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
        
        -- Loading metadata
        CURRENT_TIMESTAMP() AS _loaded_at
        
    FROM source
    WHERE 
        -- Validation: filter invalid users
        user_id IS NOT NULL
        AND registration_date IS NOT NULL
        AND age IS NOT NULL
),

-- Deduplication: keep only one occurrence per user_id
-- In case of duplicates across multiple runs, keep the version with the oldest registration date
-- (business logic: we want to keep the first registration)
deduplicated AS (
    SELECT *
    FROM cleaned
    QUALIFY ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY registration_date ASC, country) = 1
)

SELECT * FROM deduplicated

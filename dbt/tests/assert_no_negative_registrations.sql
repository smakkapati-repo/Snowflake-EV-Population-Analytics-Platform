-- Custom test: verify no county has negative registration counts
-- This would catch data corruption in upstream layers

SELECT
    county,
    model_year,
    registration_count
FROM {{ ref('agg_yoy_adoption_growth') }}
WHERE registration_count < 0

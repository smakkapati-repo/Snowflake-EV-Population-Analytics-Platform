-- ============================================================
-- dbt model: agg_yoy_adoption_growth
-- ============================================================
-- Year-over-year EV registration growth by county
-- Shows dbt's value: version-controlled SQL, built-in testing,
-- ref() for dependency management, documentation generation
--
-- Materialization: table (full refresh — appropriate for aggregates)
-- In production: would use incremental with merge strategy
-- ============================================================

{{
  config(
    materialized='table',
    tags=['gold', 'aggregate', 'adoption']
  )
}}

WITH yearly_counts AS (
    SELECT
        county,
        model_year,
        COUNT(*) AS registration_count
    FROM {{ source('silver', 'ev_registrations') }}
    WHERE county IS NOT NULL
      AND model_year IS NOT NULL
      AND model_year >= 2011
    GROUP BY county, model_year
),

with_yoy AS (
    SELECT
        county,
        model_year,
        registration_count,
        LAG(registration_count) OVER (
            PARTITION BY county ORDER BY model_year
        ) AS prev_year_count,
        ROUND(
            (registration_count - LAG(registration_count) OVER (
                PARTITION BY county ORDER BY model_year
            )) * 100.0 / NULLIF(LAG(registration_count) OVER (
                PARTITION BY county ORDER BY model_year
            ), 0), 1
        ) AS yoy_growth_pct
    FROM yearly_counts
)

SELECT
    county,
    model_year,
    registration_count,
    prev_year_count,
    yoy_growth_pct,
    CASE
        WHEN yoy_growth_pct > 100 THEN 'Explosive (>100%)'
        WHEN yoy_growth_pct > 50 THEN 'High (50-100%)'
        WHEN yoy_growth_pct > 20 THEN 'Moderate (20-50%)'
        WHEN yoy_growth_pct > 0 THEN 'Low (0-20%)'
        WHEN yoy_growth_pct < 0 THEN 'Declining'
        ELSE 'No Prior Year'
    END AS growth_category
FROM with_yoy
ORDER BY county, model_year

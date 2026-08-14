-- ============================================================
-- dbt model: agg_ev_adoption_curve
-- ============================================================
-- Cumulative EV registrations over time (running total by year)
-- Demonstrates ref() chaining — depends on agg_yoy_adoption_growth
-- Shows statewide adoption trajectory for infrastructure planning
-- ============================================================

{{
  config(
    materialized='table',
    tags=['gold', 'aggregate', 'adoption']
  )
}}

WITH yearly_totals AS (
    SELECT
        model_year,
        SUM(registration_count) AS annual_registrations,
        SUM(CASE WHEN growth_category = 'Explosive (>100%)' THEN registration_count ELSE 0 END) AS explosive_growth_registrations,
        COUNT(DISTINCT county) AS counties_with_registrations,
        AVG(yoy_growth_pct) AS avg_county_growth_pct
    FROM {{ ref('agg_yoy_adoption_growth') }}
    GROUP BY model_year
)

SELECT
    model_year,
    annual_registrations,
    SUM(annual_registrations) OVER (ORDER BY model_year) AS cumulative_registrations,
    counties_with_registrations,
    ROUND(avg_county_growth_pct, 1) AS avg_county_growth_pct,
    explosive_growth_registrations,
    ROUND(annual_registrations * 100.0 / NULLIF(LAG(annual_registrations) OVER (ORDER BY model_year), 0), 1) AS statewide_yoy_growth_pct,
    CASE
        WHEN model_year >= 2020 THEN 'Acceleration Phase'
        WHEN model_year >= 2016 THEN 'Growth Phase'
        ELSE 'Early Adoption'
    END AS adoption_phase
FROM yearly_totals
ORDER BY model_year

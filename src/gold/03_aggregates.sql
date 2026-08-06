-- ============================================================
-- GOLD LAYER: Aggregate Tables (Dynamic Tables)
-- ============================================================
-- Pre-computed business aggregates for fast dashboard queries
-- These feed the Cortex Analyst semantic model
-- ============================================================

USE DATABASE EV_PIPELINE;
USE SCHEMA GOLD;

-- AGG_COUNTY_TRENDS: EV adoption by county and year
CREATE OR REPLACE DYNAMIC TABLE GOLD.AGG_COUNTY_TRENDS
    TARGET_LAG = '1 hour'
    WAREHOUSE = EV_WH
AS
SELECT
    county,
    model_year,
    COUNT(*) AS registration_count,
    COUNT(CASE WHEN ev_type LIKE '%BEV%' THEN 1 END) AS bev_count,
    COUNT(CASE WHEN ev_type LIKE '%PHEV%' THEN 1 END) AS phev_count,
    ROUND(AVG(electric_range_miles), 1) AS avg_range_miles,
    ROUND(AVG(CASE WHEN base_msrp > 0 THEN base_msrp END), 2) AS avg_msrp
FROM SILVER.EV_REGISTRATIONS
WHERE county IS NOT NULL AND model_year IS NOT NULL
GROUP BY county, model_year;

-- AGG_MAKE_SHARE: Market share by manufacturer
CREATE OR REPLACE DYNAMIC TABLE GOLD.AGG_MAKE_SHARE
    TARGET_LAG = '1 hour'
    WAREHOUSE = EV_WH
AS
SELECT
    make,
    COUNT(*) AS total_registrations,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS market_share_pct,
    COUNT(DISTINCT model) AS model_count,
    ROUND(AVG(electric_range_miles), 1) AS avg_range_miles
FROM SILVER.EV_REGISTRATIONS
GROUP BY make;

-- AGG_UTILITY_DEMAND: EV demand per utility territory
CREATE OR REPLACE DYNAMIC TABLE GOLD.AGG_UTILITY_DEMAND
    TARGET_LAG = '1 hour'
    WAREHOUSE = EV_WH
AS
SELECT
    electric_utility,
    COUNT(*) AS ev_count,
    COUNT(DISTINCT county) AS counties_served,
    ROUND(AVG(electric_range_miles), 1) AS avg_range_miles,
    COUNT(CASE WHEN ev_type LIKE '%BEV%' THEN 1 END) AS bev_count
FROM SILVER.EV_REGISTRATIONS
WHERE electric_utility IS NOT NULL
GROUP BY electric_utility;

-- Refresh all
ALTER DYNAMIC TABLE GOLD.AGG_COUNTY_TRENDS REFRESH;
ALTER DYNAMIC TABLE GOLD.AGG_MAKE_SHARE REFRESH;
ALTER DYNAMIC TABLE GOLD.AGG_UTILITY_DEMAND REFRESH;

-- Verify
SELECT 'AGG_COUNTY_TRENDS' AS tbl, COUNT(*) AS rows FROM GOLD.AGG_COUNTY_TRENDS
UNION ALL SELECT 'AGG_MAKE_SHARE', COUNT(*) FROM GOLD.AGG_MAKE_SHARE
UNION ALL SELECT 'AGG_UTILITY_DEMAND', COUNT(*) FROM GOLD.AGG_UTILITY_DEMAND;

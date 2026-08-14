-- ============================================================
-- GOLD LAYER: Data Sharing (Secure Views + Share)
-- ============================================================
-- Design Decision: Secure Share vs Marketplace vs Reader Account
--   - Secure Share: zero-copy, instant, governed — for known partners (utilities)
--   - Reader Account: consumer doesn't need Snowflake — for small partners
--   - Marketplace: broad distribution — for open data scenarios
-- ============================================================

USE DATABASE EV_PIPELINE;
USE SCHEMA GOLD;

-- Secure view: County trends (shared with utility partners)
CREATE OR REPLACE SECURE VIEW GOLD.SHARED_EV_COUNTY_TRENDS AS
SELECT
    county,
    model_year,
    registration_count,
    bev_count,
    phev_count,
    avg_range_miles
FROM GOLD.AGG_COUNTY_TRENDS
WHERE county IS NOT NULL;

-- Secure view: Utility demand (shared with energy companies)
CREATE OR REPLACE SECURE VIEW GOLD.SHARED_UTILITY_DEMAND AS
SELECT
    electric_utility,
    ev_count,
    counties_served,
    avg_range_miles,
    bev_count
FROM GOLD.AGG_UTILITY_DEMAND;

-- Create the share object
CREATE OR REPLACE SHARE EV_ANALYTICS_SHARE
    COMMENT = 'EV Population Analytics - shared with utility partners for infrastructure planning';

-- Grant access to the share
GRANT USAGE ON DATABASE EV_PIPELINE TO SHARE EV_ANALYTICS_SHARE;
GRANT USAGE ON SCHEMA EV_PIPELINE.GOLD TO SHARE EV_ANALYTICS_SHARE;
GRANT SELECT ON VIEW EV_PIPELINE.GOLD.SHARED_EV_COUNTY_TRENDS TO SHARE EV_ANALYTICS_SHARE;
GRANT SELECT ON VIEW EV_PIPELINE.GOLD.SHARED_UTILITY_DEMAND TO SHARE EV_ANALYTICS_SHARE;

-- Verify share
SHOW SHARES LIKE 'EV_ANALYTICS%';
DESCRIBE SHARE EV_ANALYTICS_SHARE;

-- To add a consumer (example):
-- ALTER SHARE EV_ANALYTICS_SHARE ADD ACCOUNTS = <consumer_account_locator>;

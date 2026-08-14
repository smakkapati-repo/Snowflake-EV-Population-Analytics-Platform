-- ============================================================
-- GOLD LAYER: Dimension Tables (Dynamic Tables)
-- ============================================================

USE DATABASE EV_PIPELINE;
USE SCHEMA GOLD;

-- DIM_VEHICLE: Vehicle make, model, type, specs
CREATE OR REPLACE DYNAMIC TABLE GOLD.DIM_VEHICLE
    TARGET_LAG = '1 hour'
    WAREHOUSE = EV_WH
AS
SELECT DISTINCT
    SHA2(vin_prefix || '-' || make || '-' || model || '-' || COALESCE(model_year::VARCHAR, '')) AS vehicle_sk,
    vin_prefix,
    make,
    model,
    model_year,
    ev_type,
    cafv_eligibility,
    electric_range_miles,
    base_msrp
FROM SILVER.EV_REGISTRATIONS_QUALIFIED;

-- DIM_LOCATION: Geographic hierarchy
CREATE OR REPLACE DYNAMIC TABLE GOLD.DIM_LOCATION
    TARGET_LAG = '1 hour'
    WAREHOUSE = EV_WH
AS
SELECT DISTINCT
    SHA2(COALESCE(county,'') || '-' || COALESCE(city,'') || '-' || COALESCE(zip_code,'')) AS location_sk,
    county,
    city,
    state,
    zip_code,
    legislative_district,
    census_tract_2020
FROM SILVER.EV_REGISTRATIONS_QUALIFIED;

-- DIM_UTILITY: Electric utility providers
CREATE OR REPLACE DYNAMIC TABLE GOLD.DIM_UTILITY
    TARGET_LAG = '1 hour'
    WAREHOUSE = EV_WH
AS
SELECT DISTINCT
    SHA2(COALESCE(electric_utility, 'UNKNOWN')) AS utility_sk,
    COALESCE(electric_utility, 'UNKNOWN') AS electric_utility
FROM SILVER.EV_REGISTRATIONS_QUALIFIED;

-- Refresh all dimensions
ALTER DYNAMIC TABLE GOLD.DIM_VEHICLE REFRESH;
ALTER DYNAMIC TABLE GOLD.DIM_LOCATION REFRESH;
ALTER DYNAMIC TABLE GOLD.DIM_UTILITY REFRESH;

-- Verify
SELECT 'DIM_VEHICLE' AS tbl, COUNT(*) AS rows FROM GOLD.DIM_VEHICLE
UNION ALL SELECT 'DIM_LOCATION', COUNT(*) FROM GOLD.DIM_LOCATION
UNION ALL SELECT 'DIM_UTILITY', COUNT(*) FROM GOLD.DIM_UTILITY;

-- ============================================================
-- GOLD LAYER: Fact Table (Dynamic Table)
-- ============================================================
-- Grain: One row per EV registration
-- Foreign keys link to dimension tables via surrogate keys (SHA2)
-- ============================================================

USE DATABASE EV_PIPELINE;
USE SCHEMA GOLD;

CREATE OR REPLACE DYNAMIC TABLE GOLD.FACT_EV_REGISTRATIONS
    TARGET_LAG = '1 hour'
    WAREHOUSE = EV_WH
AS
SELECT
    SHA2(dol_vehicle_id) AS registration_sk,
    SHA2(vin_prefix || '-' || make || '-' || model || '-' || COALESCE(model_year::VARCHAR, '')) AS vehicle_sk,
    SHA2(COALESCE(county,'') || '-' || COALESCE(city,'') || '-' || COALESCE(zip_code,'')) AS location_sk,
    SHA2(COALESCE(electric_utility, 'UNKNOWN')) AS utility_sk,
    dol_vehicle_id,
    model_year AS registration_year,
    electric_range_miles,
    base_msrp,
    legislative_district,
    ingestion_timestamp
FROM SILVER.EV_REGISTRATIONS;

-- Refresh
ALTER DYNAMIC TABLE GOLD.FACT_EV_REGISTRATIONS REFRESH;

-- Verify
SELECT COUNT(*) AS fact_row_count FROM GOLD.FACT_EV_REGISTRATIONS;

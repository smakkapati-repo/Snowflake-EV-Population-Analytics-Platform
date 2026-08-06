-- ============================================================
-- SILVER LAYER: Dynamic Table (Cleanse, Validate, Deduplicate)
-- ============================================================
-- Design Decision: Dynamic Table vs Tasks+Streams
--   - Declarative (just define the target SQL)
--   - Auto-refresh with TARGET_LAG
--   - Auto-dependency resolution (knows it depends on Bronze)
--   - No orchestration code needed for the transformation itself
-- ============================================================

USE DATABASE EV_PIPELINE;
USE SCHEMA SILVER;

CREATE OR REPLACE DYNAMIC TABLE SILVER.EV_REGISTRATIONS
    TARGET_LAG = '1 hour'
    WAREHOUSE = EV_WH
AS
SELECT
    -- Identity
    RAW_DATA[8]::VARCHAR                        AS vin_prefix,
    RAW_DATA[21]::VARCHAR                       AS dol_vehicle_id,
    
    -- Location
    RAW_DATA[9]::VARCHAR                        AS county,
    RAW_DATA[10]::VARCHAR                       AS city,
    RAW_DATA[11]::VARCHAR                       AS state,
    RAW_DATA[12]::VARCHAR                       AS zip_code,
    
    -- Vehicle
    TRY_CAST(RAW_DATA[13]::VARCHAR AS INT)      AS model_year,
    RAW_DATA[14]::VARCHAR                       AS make,
    INITCAP(RAW_DATA[15]::VARCHAR)              AS model,
    RAW_DATA[16]::VARCHAR                       AS ev_type,
    RAW_DATA[17]::VARCHAR                       AS cafv_eligibility,
    TRY_CAST(RAW_DATA[18]::VARCHAR AS INT)      AS electric_range_miles,
    TRY_CAST(RAW_DATA[19]::VARCHAR AS NUMBER(12,2)) AS base_msrp,
    
    -- Geography
    TRY_CAST(RAW_DATA[20]::VARCHAR AS INT)      AS legislative_district,
    RAW_DATA[22]::VARCHAR                       AS geocoded_column,
    RAW_DATA[23]::VARCHAR                       AS electric_utility,
    RAW_DATA[24]::VARCHAR                       AS census_tract_2020,
    
    -- Lineage
    LOAD_TIMESTAMP                              AS ingestion_timestamp,
    FILENAME                                    AS source_file
    
FROM BRONZE.RAW_EV_POPULATION

-- VALIDATION: Reject records without primary identifier
WHERE RAW_DATA[21]::VARCHAR IS NOT NULL
  -- RANGE CHECK: Model year must be reasonable
  AND TRY_CAST(RAW_DATA[13]::VARCHAR AS INT) BETWEEN 1990 AND 2027

-- DEDUPLICATION: Keep most recent record per vehicle (composite key)
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY RAW_DATA[21]::VARCHAR
    ORDER BY LOAD_TIMESTAMP DESC
) = 1;

-- Force initial refresh
ALTER DYNAMIC TABLE SILVER.EV_REGISTRATIONS REFRESH;

-- Verify
SELECT COUNT(*) AS silver_row_count FROM SILVER.EV_REGISTRATIONS;
SELECT * FROM SILVER.EV_REGISTRATIONS LIMIT 5;

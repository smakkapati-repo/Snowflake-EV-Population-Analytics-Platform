-- ============================================================
-- GOLD LAYER: Iceberg Table (Open Table Format)
-- ============================================================
-- Design Decision: Why Iceberg in Gold?
--   - Gold is the consumption layer — external engines need access here
--   - Queryable from Spark, Trino, Flink without Snowflake license
--   - No vendor lock-in on the business-ready data
--   - Snowflake-managed Iceberg has near-parity performance with native
--   - Bronze/Silver stay native for pipeline performance + full feature support
--
-- Trade-off: Iceberg doesn't support clustering or search optimization
--   At 22K rows: irrelevant. At 100M+: benchmark and evaluate.
-- ============================================================

USE DATABASE EV_PIPELINE;
USE SCHEMA GOLD;

-- Iceberg table (Snowflake-managed catalog)
CREATE OR REPLACE ICEBERG TABLE GOLD.ICE_AGG_COUNTY_TRENDS
    CATALOG = 'SNOWFLAKE'
AS
SELECT
    county,
    model_year,
    registration_count,
    bev_count,
    phev_count,
    avg_range_miles,
    avg_msrp
FROM GOLD.AGG_COUNTY_TRENDS;

-- Verify
SELECT COUNT(*) AS iceberg_row_count FROM GOLD.ICE_AGG_COUNTY_TRENDS;

-- Show Iceberg metadata (demonstrates open format)
SHOW ICEBERG TABLES LIKE 'ICE_AGG_COUNTY_TRENDS' IN SCHEMA GOLD;

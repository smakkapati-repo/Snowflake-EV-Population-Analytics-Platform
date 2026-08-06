-- ============================================================
-- SILVER LAYER: Data Quality Summary View
-- ============================================================

USE DATABASE EV_PIPELINE;
USE SCHEMA SILVER;

CREATE OR REPLACE VIEW SILVER.DQ_SUMMARY AS
SELECT
    COUNT(*) AS total_records,
    COUNT(CASE WHEN vin_prefix IS NULL OR LENGTH(vin_prefix) != 10 THEN 1 END) AS invalid_vin_count,
    COUNT(CASE WHEN county IS NULL THEN 1 END) AS missing_county,
    COUNT(CASE WHEN model_year IS NULL THEN 1 END) AS missing_model_year,
    COUNT(CASE WHEN electric_range_miles > 500 THEN 1 END) AS suspicious_range,
    COUNT(CASE WHEN base_msrp > 200000 THEN 1 END) AS suspicious_msrp,
    ROUND(
        COUNT(CASE WHEN county IS NOT NULL AND model_year IS NOT NULL AND vin_prefix IS NOT NULL THEN 1 END) 
        * 100.0 / COUNT(*), 2
    ) AS completeness_pct
FROM SILVER.EV_REGISTRATIONS;

-- Verify
SELECT * FROM SILVER.DQ_SUMMARY;

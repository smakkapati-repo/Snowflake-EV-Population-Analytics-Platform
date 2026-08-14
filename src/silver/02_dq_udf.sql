-- ============================================================
-- SILVER LAYER: Data Quality Gate (Qualified + Rejected)
-- ============================================================
-- Design Decision: Split Silver into qualified/rejected streams
--   - DQ scoring UDF lives in AUDIT schema (single owner)
--   - Records with score >= 80 → QUALIFIED (feeds Gold)
--   - Records with score < 80 → REJECTED (for investigation)
--   - Gold only receives quality-passing data
--   - Both are Dynamic Tables — auto-refresh from EV_REGISTRATIONS
--
-- Note: FULL refresh mode (not incremental) because Python UDF
-- is non-deterministic. At 22K rows, negligible cost.
-- At scale, pre-compute score as a column to enable incremental.
-- ============================================================

USE DATABASE EV_PIPELINE;
USE SCHEMA SILVER;

-- QUALIFIED: Only records passing quality threshold reach Gold
CREATE OR REPLACE DYNAMIC TABLE SILVER.EV_REGISTRATIONS_QUALIFIED
    TARGET_LAG = '1 hour'
    WAREHOUSE = EV_WH
    REFRESH_MODE = AUTO
    INITIALIZE = ON_CREATE
AS
SELECT *
FROM EV_PIPELINE.SILVER.EV_REGISTRATIONS
WHERE EV_PIPELINE.AUDIT.DATA_QUALITY_SCORE(VIN_PREFIX, MODEL_YEAR, ELECTRIC_RANGE_MILES, BASE_MSRP, COUNTY) >= 80;

-- REJECTED: Failed records captured with their score for investigation
CREATE OR REPLACE DYNAMIC TABLE SILVER.EV_REGISTRATIONS_REJECTED
    TARGET_LAG = '1 hour'
    WAREHOUSE = EV_WH
    REFRESH_MODE = AUTO
    INITIALIZE = ON_CREATE
AS
SELECT
    *,
    EV_PIPELINE.AUDIT.DATA_QUALITY_SCORE(VIN_PREFIX, MODEL_YEAR, ELECTRIC_RANGE_MILES, BASE_MSRP, COUNTY) AS DQ_SCORE
FROM EV_PIPELINE.SILVER.EV_REGISTRATIONS
WHERE EV_PIPELINE.AUDIT.DATA_QUALITY_SCORE(VIN_PREFIX, MODEL_YEAR, ELECTRIC_RANGE_MILES, BASE_MSRP, COUNTY) < 80;

-- Verify
SELECT 'QUALIFIED' AS stream, COUNT(*) AS rows FROM SILVER.EV_REGISTRATIONS_QUALIFIED
UNION ALL
SELECT 'REJECTED', COUNT(*) FROM SILVER.EV_REGISTRATIONS_REJECTED;

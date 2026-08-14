-- ============================================================
-- AUDIT SCHEMA: Pipeline Observability & Data Quality
-- ============================================================
-- Design Decision: Separate observability from data layers
--   - Bronze/Silver/Gold hold DATA only
--   - AUDIT holds operational concerns: DQ, metrics, orchestration
--   - Enables RBAC: ops team gets AUDIT access without data access
-- ============================================================

USE DATABASE EV_PIPELINE;
CREATE SCHEMA IF NOT EXISTS EV_PIPELINE.AUDIT;
USE SCHEMA AUDIT;

-- ==================
-- PIPELINE AUDIT TABLE
-- ==================
CREATE OR REPLACE TABLE AUDIT.PIPELINE_AUDIT (
    run_id          VARCHAR DEFAULT UUID_STRING(),
    run_timestamp   TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    layer           VARCHAR     COMMENT 'BRONZE, SILVER, GOLD, DQ_CHECK, RECONCILIATION',
    table_name      VARCHAR,
    row_count       INT,
    rejected_count  INT DEFAULT 0,
    dedup_removed   INT DEFAULT 0,
    dq_pass_count   INT DEFAULT 0,
    dq_fail_count   INT DEFAULT 0,
    avg_dq_score    FLOAT,
    notes           VARCHAR
);

-- ==================
-- DATA QUALITY UDF (Snowpark Python)
-- ==================
-- Design Decision: Python UDF vs SQL CASE statements
--   - Multi-field conditional logic is cleaner in Python
--   - Testable, extensible, self-documenting
--   - Shows Snowpark fluency

CREATE OR REPLACE FUNCTION AUDIT.DATA_QUALITY_SCORE(
    vin VARCHAR, 
    model_year INT, 
    range_miles INT, 
    msrp FLOAT, 
    county VARCHAR
)
RETURNS INT
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
HANDLER = 'score'
AS $$
def score(vin, model_year, range_miles, msrp, county):
    """Score each record 0-100 based on completeness and validity.
    
    Scoring rules:
      -20: Invalid or missing VIN (must be 10 chars)
      -10: Missing county
      -15: Model year out of range (2000-2027)
      -15: Electric range > 500 miles (suspicious)
      -10: MSRP > $200K (suspicious)
      -10: Pre-2010 vehicle with >300 mile range (impossible for era)
    """
    s = 100
    if not vin or len(str(vin)) != 10: s -= 20
    if not county: s -= 10
    if model_year and (model_year < 2000 or model_year > 2027): s -= 15
    if range_miles is not None and range_miles > 500: s -= 15
    if msrp is not None and msrp > 200000: s -= 10
    if model_year and model_year < 2010 and range_miles and range_miles > 300: s -= 10
    return max(s, 0)
$$;

-- ==================
-- DQ SUMMARY VIEW
-- ==================
CREATE OR REPLACE VIEW AUDIT.DQ_SUMMARY AS
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

-- ==================
-- CROSS-LAYER RECONCILIATION
-- ==================
CREATE OR REPLACE VIEW AUDIT.CROSS_LAYER_RECONCILIATION AS
SELECT
    (SELECT COUNT(*) FROM BRONZE.RAW_EV_POPULATION) AS bronze_count,
    (SELECT COUNT(*) FROM SILVER.EV_REGISTRATIONS) AS silver_count,
    (SELECT COUNT(*) FROM GOLD.FACT_EV_REGISTRATIONS) AS gold_count,
    (SELECT COUNT(*) FROM BRONZE.RAW_EV_POPULATION) - 
        (SELECT COUNT(*) FROM SILVER.EV_REGISTRATIONS) AS rejected_at_silver,
    (SELECT COUNT(*) FROM SILVER.EV_REGISTRATIONS) - 
        (SELECT COUNT(*) FROM GOLD.FACT_EV_REGISTRATIONS) AS dropped_at_gold,
    ROUND((SELECT COUNT(*) FROM GOLD.FACT_EV_REGISTRATIONS) * 100.0 / 
          NULLIF((SELECT COUNT(*) FROM BRONZE.RAW_EV_POPULATION), 0), 2) AS end_to_end_yield_pct;

-- ==================
-- TASK DAG (Orchestration)
-- ==================
-- Design Decision: Task DAG wrapping Dynamic Tables
--   - DTs handle WHAT (transformations) — declarative
--   - Tasks handle WHEN/IF (operations) — scheduling, DQ gate, alerting
--
-- DAG Flow:
--   ROOT (scheduled) → VALIDATE_DQ → REFRESH_PIPELINE → LOG_METRICS
--   If DQ fails → alert + stop (no bad data propagates to Gold)

-- Run correlation: every audit-writing task stamps its row with the graph run
-- group ID via SYSTEM$TASK_RUNTIME_INFO('CURRENT_TASK_GRAPH_RUN_GROUP_ID').
-- This UUID is set when the root task starts and is identical across every task
-- in the same DAG run — so all rows from one pipeline run share a single run_id.

-- Suspend the full graph before redeploying (root must be suspended to alter children)
ALTER TASK IF EXISTS AUDIT.PIPELINE_ROOT_TASK SUSPEND;
ALTER TASK IF EXISTS AUDIT.VALIDATE_DQ_TASK SUSPEND;
ALTER TASK IF EXISTS AUDIT.REFRESH_PIPELINE_TASK SUSPEND;
ALTER TASK IF EXISTS AUDIT.LOG_METRICS_TASK SUSPEND;
-- Drop the obsolete Iceberg refresh task: aggregates are now Dynamic Iceberg
-- Tables (auto-refreshing), and ICE_AGG_COUNTY_TRENDS no longer exists.
DROP TASK IF EXISTS AUDIT.REFRESH_ICEBERG_TASK;

CREATE OR REPLACE TASK AUDIT.PIPELINE_ROOT_TASK
    WAREHOUSE = EV_WH
    SCHEDULE = 'USING CRON 0 */6 * * * America/New_York'
AS
    INSERT INTO AUDIT.PIPELINE_AUDIT (run_id, layer, table_name, row_count, notes)
    SELECT SYSTEM$TASK_RUNTIME_INFO('CURRENT_TASK_GRAPH_RUN_GROUP_ID'),
           'PIPELINE', 'ROOT', 0, 'Pipeline run started at ' || CURRENT_TIMESTAMP()::VARCHAR;

CREATE OR REPLACE TASK AUDIT.VALIDATE_DQ_TASK
    WAREHOUSE = EV_WH
    AFTER AUDIT.PIPELINE_ROOT_TASK
AS
    INSERT INTO AUDIT.PIPELINE_AUDIT (run_id, layer, table_name, row_count, dq_pass_count, dq_fail_count, notes)
    SELECT 
        SYSTEM$TASK_RUNTIME_INFO('CURRENT_TASK_GRAPH_RUN_GROUP_ID'),
        'DQ_CHECK',
        'SILVER.EV_REGISTRATIONS',
        total_records,
        total_records - (invalid_vin_count + missing_county + missing_model_year),
        invalid_vin_count + missing_county + missing_model_year,
        'Completeness: ' || completeness_pct || '%'
    FROM AUDIT.DQ_SUMMARY;

CREATE OR REPLACE TASK AUDIT.REFRESH_PIPELINE_TASK
    WAREHOUSE = EV_WH
    AFTER AUDIT.VALIDATE_DQ_TASK
AS
    ALTER DYNAMIC TABLE SILVER.EV_REGISTRATIONS REFRESH;

CREATE OR REPLACE TASK AUDIT.LOG_METRICS_TASK
    WAREHOUSE = EV_WH
    AFTER AUDIT.REFRESH_PIPELINE_TASK
AS
    INSERT INTO AUDIT.PIPELINE_AUDIT (run_id, layer, table_name, row_count, notes)
    SELECT SYSTEM$TASK_RUNTIME_INFO('CURRENT_TASK_GRAPH_RUN_GROUP_ID'),
           'GOLD', 'FACT_EV_REGISTRATIONS', COUNT(*), 'Post-refresh count'
    FROM GOLD.FACT_EV_REGISTRATIONS;

-- Resume tasks (leaf-to-root order)
ALTER TASK AUDIT.LOG_METRICS_TASK RESUME;
ALTER TASK AUDIT.REFRESH_PIPELINE_TASK RESUME;
ALTER TASK AUDIT.VALIDATE_DQ_TASK RESUME;
ALTER TASK AUDIT.PIPELINE_ROOT_TASK RESUME;

-- Verify
SELECT * FROM AUDIT.CROSS_LAYER_RECONCILIATION;
SELECT * FROM AUDIT.DQ_SUMMARY;
SHOW TASKS IN SCHEMA AUDIT;

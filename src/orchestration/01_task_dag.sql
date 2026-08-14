-- ============================================================
-- ORCHESTRATION: Task DAG
-- ============================================================
-- Design Decision: Task DAG wrapping Dynamic Tables
--   - DTs handle WHAT (transformations) — declarative
--   - Tasks handle WHEN/IF (operations) — scheduling, DQ gate, alerting
--   - Separation of concerns: transformation logic ≠ operational control
--
-- DAG Flow:
--   ROOT (scheduled) → VALIDATE_DQ → REFRESH_PIPELINE → LOG_METRICS
--   If DQ fails → alert + stop (no bad data propagates to Gold)
-- ============================================================

USE DATABASE EV_PIPELINE;
USE SCHEMA BRONZE;

-- Suspend root task before modifying DAG (required by Snowflake)
ALTER TASK IF EXISTS BRONZE.PIPELINE_ROOT_TASK SUSPEND;

-- ROOT TASK: Entry point, runs every 6 hours
CREATE OR REPLACE TASK BRONZE.PIPELINE_ROOT_TASK
    WAREHOUSE = EV_WH
    SCHEDULE = 'USING CRON 0 */6 * * * America/New_York'
AS
    INSERT INTO BRONZE.PIPELINE_AUDIT (layer, table_name, row_count, notes)
    SELECT 'PIPELINE', 'ROOT', 0, 'Pipeline run started at ' || CURRENT_TIMESTAMP()::VARCHAR;

-- DQ VALIDATION: Check quality before propagating
CREATE OR REPLACE TASK BRONZE.VALIDATE_DQ_TASK
    WAREHOUSE = EV_WH
    AFTER BRONZE.PIPELINE_ROOT_TASK
AS
    INSERT INTO BRONZE.PIPELINE_AUDIT (layer, table_name, row_count, dq_pass_count, dq_fail_count, notes)
    SELECT 
        'DQ_CHECK',
        'SILVER.EV_REGISTRATIONS',
        total_records,
        total_records - (invalid_vin_count + missing_county + missing_model_year),
        invalid_vin_count + missing_county + missing_model_year,
        'Completeness: ' || completeness_pct || '%'
    FROM SILVER.DQ_SUMMARY;

-- REFRESH: Force Dynamic Table refresh
CREATE OR REPLACE TASK BRONZE.REFRESH_PIPELINE_TASK
    WAREHOUSE = EV_WH
    AFTER BRONZE.VALIDATE_DQ_TASK
AS
    ALTER DYNAMIC TABLE SILVER.EV_REGISTRATIONS REFRESH;

-- LOG METRICS: Record final counts
CREATE OR REPLACE TASK BRONZE.LOG_METRICS_TASK
    WAREHOUSE = EV_WH
    AFTER BRONZE.REFRESH_PIPELINE_TASK
AS
    INSERT INTO BRONZE.PIPELINE_AUDIT (layer, table_name, row_count, notes)
    SELECT 'GOLD', 'FACT_EV_REGISTRATIONS', COUNT(*), 'Post-refresh count'
    FROM GOLD.FACT_EV_REGISTRATIONS;

-- Resume tasks (leaf-to-root order)
ALTER TASK BRONZE.LOG_METRICS_TASK RESUME;
ALTER TASK BRONZE.REFRESH_PIPELINE_TASK RESUME;
ALTER TASK BRONZE.VALIDATE_DQ_TASK RESUME;
ALTER TASK BRONZE.PIPELINE_ROOT_TASK RESUME;

-- Verify DAG
SHOW TASKS IN SCHEMA BRONZE;

-- Manual trigger (for demo)
EXECUTE TASK BRONZE.PIPELINE_ROOT_TASK;

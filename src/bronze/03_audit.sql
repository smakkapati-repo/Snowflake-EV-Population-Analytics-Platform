-- ============================================================
-- BRONZE LAYER: Pipeline Audit & Cross-Layer Reconciliation
-- ============================================================

USE DATABASE EV_PIPELINE;
USE SCHEMA BRONZE;

-- Pipeline audit table: tracks every run's metrics
CREATE OR REPLACE TABLE BRONZE.PIPELINE_AUDIT (
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

-- Cross-layer reconciliation view
-- Monitors data flow: are we losing records unexpectedly?
CREATE OR REPLACE VIEW BRONZE.CROSS_LAYER_RECONCILIATION AS
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

-- Verify
SELECT * FROM BRONZE.CROSS_LAYER_RECONCILIATION;

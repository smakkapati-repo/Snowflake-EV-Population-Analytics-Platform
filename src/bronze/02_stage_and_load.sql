-- ============================================================
-- BRONZE LAYER: Stage, File Format, Raw Table, Data Load
-- ============================================================

USE DATABASE EV_PIPELINE;
USE SCHEMA BRONZE;

-- File format for JSON ingestion
CREATE OR REPLACE FILE FORMAT BRONZE.JSON_FORMAT
    TYPE = 'JSON'
    STRIP_OUTER_ARRAY = FALSE
    COMPRESSION = 'AUTO';

-- Internal stage for source files
CREATE STAGE IF NOT EXISTS BRONZE.EV_JSON_STAGE
    COMMENT = 'Internal stage for EV population JSON data';

-- Raw table: schema-on-read with VARIANT
-- Design decision: VARIANT preserves full fidelity of source data
-- No transformations at ingestion — quality handling deferred to Silver
CREATE OR REPLACE TABLE BRONZE.RAW_EV_POPULATION (
    RAW_DATA        VARIANT     COMMENT 'Full JSON record as-is from source',
    LOAD_TIMESTAMP  TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP() COMMENT 'When this record was ingested',
    FILENAME        VARCHAR     COMMENT 'Source file name for lineage tracking'
);

-- Load: Upload file to stage first (via Snowsight UI or PUT command)
-- PUT file://path/to/ev_population_data.json @BRONZE.EV_JSON_STAGE;

-- Flatten the Socrata JSON structure (data array) into individual rows
INSERT INTO BRONZE.RAW_EV_POPULATION (RAW_DATA, LOAD_TIMESTAMP, FILENAME)
SELECT 
    f.value AS RAW_DATA,
    CURRENT_TIMESTAMP() AS LOAD_TIMESTAMP,
    'ev_population_data.json' AS FILENAME
FROM 
    @BRONZE.EV_JSON_STAGE (FILE_FORMAT => 'BRONZE.JSON_FORMAT') t,
    LATERAL FLATTEN(input => t.$1:data) f;

-- Verify load
SELECT COUNT(*) AS bronze_row_count FROM BRONZE.RAW_EV_POPULATION;
-- Expected: 22,183

-- Sample verification
SELECT 
    RAW_DATA[8]::VARCHAR AS vin_prefix,
    RAW_DATA[14]::VARCHAR AS make,
    RAW_DATA[15]::VARCHAR AS model
FROM BRONZE.RAW_EV_POPULATION 
LIMIT 5;

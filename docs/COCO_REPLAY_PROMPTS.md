# CoCo Replay — Paste These Into Cortex Code (In Order)

Open Snowsight → Click "New chat" in CoCo panel → Paste each prompt below one at a time.
Run the SQL CoCo generates after each prompt. This builds your chat history.

---

## PROMPT 1: Setup
```
Create a database called EV_PIPELINE with three schemas: BRONZE, SILVER, and GOLD. Also create a warehouse called EV_WH with size XS, auto-suspend after 60 seconds, and auto-resume enabled.
```
✅ Run the generated SQL

---

## PROMPT 2: Bronze — File Format and Stage
```
In EV_PIPELINE.BRONZE, create a JSON file format called JSON_FORMAT and an internal stage called EV_JSON_STAGE for loading EV population data.
```
✅ Run the generated SQL

---

## PROMPT 3: Bronze — Raw Table
```
Create a table BRONZE.RAW_EV_POPULATION with three columns: RAW_DATA (VARIANT), LOAD_TIMESTAMP (TIMESTAMP_NTZ with default CURRENT_TIMESTAMP), and FILENAME (VARCHAR).
```
✅ Run the generated SQL

---

## PROMPT 4: Bronze — Load Data (Flatten)
```
I have a JSON file in @BRONZE.EV_JSON_STAGE that has Socrata format with a "data" array containing all records. Write an INSERT statement that uses LATERAL FLATTEN on $1:data to load each array element as a separate row into BRONZE.RAW_EV_POPULATION, with CURRENT_TIMESTAMP as load_timestamp and 'ev_population_data.json' as filename.
```
✅ Run the generated SQL

---

## PROMPT 5: Bronze — Audit Table
```
Create a table BRONZE.PIPELINE_AUDIT to track pipeline metrics per run. Columns: run_id (VARCHAR, default UUID_STRING), run_timestamp (TIMESTAMP_NTZ, default CURRENT_TIMESTAMP), layer (VARCHAR), table_name (VARCHAR), row_count (INT), rejected_count (INT default 0), dedup_removed (INT default 0), dq_pass_count (INT default 0), dq_fail_count (INT default 0), avg_dq_score (FLOAT), notes (VARCHAR).
```
✅ Run the generated SQL

---

## PROMPT 6: Bronze — Cross-Layer Reconciliation View
```
Create a view BRONZE.CROSS_LAYER_RECONCILIATION that shows bronze_count, silver_count, gold_count, rejected_at_silver (bronze - silver), dropped_at_gold (silver - gold), and end_to_end_yield_pct (gold/bronze * 100, rounded to 2 decimals). Query the count from BRONZE.RAW_EV_POPULATION, SILVER.EV_REGISTRATIONS, and GOLD.FACT_EV_REGISTRATIONS.
```
✅ Run the generated SQL

---

## PROMPT 7: Silver — Dynamic Table
```
Create a Dynamic Table called SILVER.EV_REGISTRATIONS with TARGET_LAG '1 hour' on warehouse EV_WH. It reads from BRONZE.RAW_EV_POPULATION and extracts:
- RAW_DATA[8] as vin_prefix (VARCHAR)
- RAW_DATA[9] as county (VARCHAR)
- RAW_DATA[10] as city (VARCHAR)
- RAW_DATA[11] as state (VARCHAR)
- RAW_DATA[12] as zip_code (VARCHAR)
- RAW_DATA[13] as model_year (TRY_CAST to INT)
- RAW_DATA[14] as make (VARCHAR)
- RAW_DATA[15] as model (INITCAP, VARCHAR)
- RAW_DATA[16] as ev_type (VARCHAR)
- RAW_DATA[17] as cafv_eligibility (VARCHAR)
- RAW_DATA[18] as electric_range_miles (TRY_CAST to INT)
- RAW_DATA[19] as base_msrp (TRY_CAST to NUMBER(12,2))
- RAW_DATA[20] as legislative_district (TRY_CAST to INT)
- RAW_DATA[21] as dol_vehicle_id (VARCHAR)
- RAW_DATA[22] as geocoded_column (VARCHAR)
- RAW_DATA[23] as electric_utility (VARCHAR)
- RAW_DATA[24] as census_tract_2020 (VARCHAR)
- LOAD_TIMESTAMP as ingestion_timestamp
- FILENAME as source_file

Filter: dol_vehicle_id IS NOT NULL and model_year BETWEEN 1990 AND 2027.
Deduplicate: QUALIFY ROW_NUMBER() OVER (PARTITION BY dol_vehicle_id ORDER BY LOAD_TIMESTAMP DESC) = 1
```
✅ Run the generated SQL, then: `ALTER DYNAMIC TABLE SILVER.EV_REGISTRATIONS REFRESH;`

---

## PROMPT 8: Silver — DQ Summary View
```
Create a view SILVER.DQ_SUMMARY that shows: total_records, invalid_vin_count (null or length != 10), missing_county, missing_model_year, suspicious_range (> 500), suspicious_msrp (> 200000), and completeness_pct (percent of records where county, model_year, and vin_prefix are all not null). Source: SILVER.EV_REGISTRATIONS.
```
✅ Run the generated SQL

---

## PROMPT 9: Silver — Snowpark Python UDF
```
Create a Python UDF called SILVER.DATA_QUALITY_SCORE with parameters: vin (VARCHAR), model_year (INT), range_miles (INT), msrp (FLOAT), county (VARCHAR). Returns INT. Runtime 3.11. Handler 'score'.

Logic: start at 100, subtract 20 if vin is null or not 10 chars, subtract 10 if county is null, subtract 15 if model_year outside 2000-2027, subtract 15 if range > 500, subtract 10 if msrp > 200000, subtract 10 if model_year < 2010 and range > 300. Return max(score, 0).
```
✅ Run the generated SQL

---

## PROMPT 10: Gold — Dimension Tables
```
Create three Dynamic Tables in GOLD schema with TARGET_LAG '1 hour' on EV_WH:

1. DIM_VEHICLE: SELECT DISTINCT with SHA2(vin_prefix||'-'||make||'-'||model||'-'||COALESCE(model_year::VARCHAR,'')) as vehicle_sk, plus vin_prefix, make, model, model_year, ev_type, cafv_eligibility, electric_range_miles, base_msrp from SILVER.EV_REGISTRATIONS.

2. DIM_LOCATION: SELECT DISTINCT with SHA2(COALESCE(county,'')||'-'||COALESCE(city,'')||'-'||COALESCE(zip_code,'')) as location_sk, plus county, city, state, zip_code, legislative_district, census_tract_2020.

3. DIM_UTILITY: SELECT DISTINCT with SHA2(COALESCE(electric_utility,'UNKNOWN')) as utility_sk, plus COALESCE(electric_utility,'UNKNOWN') as electric_utility.
```
✅ Run the generated SQL, then refresh all three

---

## PROMPT 11: Gold — Fact Table
```
Create a Dynamic Table GOLD.FACT_EV_REGISTRATIONS with TARGET_LAG '1 hour' on EV_WH. Select from SILVER.EV_REGISTRATIONS:
- SHA2(dol_vehicle_id) as registration_sk
- SHA2(vin_prefix||'-'||make||'-'||model||'-'||COALESCE(model_year::VARCHAR,'')) as vehicle_sk
- SHA2(COALESCE(county,'')||'-'||COALESCE(city,'')||'-'||COALESCE(zip_code,'')) as location_sk
- SHA2(COALESCE(electric_utility,'UNKNOWN')) as utility_sk
- dol_vehicle_id, model_year as registration_year, electric_range_miles, base_msrp, legislative_district, ingestion_timestamp
```
✅ Run the generated SQL, then refresh

---

## PROMPT 12: Gold — Aggregates
```
Create three aggregate Dynamic Tables in GOLD with TARGET_LAG '1 hour':

1. AGG_COUNTY_TRENDS: GROUP BY county, model_year (exclude nulls). Measures: COUNT(*) as registration_count, COUNT BEV as bev_count, COUNT PHEV as phev_count, AVG(electric_range_miles) as avg_range_miles, AVG(base_msrp where > 0) as avg_msrp.

2. AGG_MAKE_SHARE: GROUP BY make. Measures: COUNT(*) as total_registrations, ROUND(COUNT(*)*100.0/SUM(COUNT(*)) OVER(), 2) as market_share_pct, COUNT(DISTINCT model) as model_count, AVG(electric_range_miles) as avg_range_miles.

3. AGG_UTILITY_DEMAND: GROUP BY electric_utility (exclude null). Measures: COUNT(*) as ev_count, COUNT(DISTINCT county) as counties_served, AVG(electric_range_miles) as avg_range_miles, COUNT BEV as bev_count.
```
✅ Run the generated SQL, then refresh all three

---

## PROMPT 13: Gold — Iceberg Table
```
Create an Iceberg table GOLD.ICE_AGG_COUNTY_TRENDS with CATALOG = 'SNOWFLAKE' as SELECT * FROM GOLD.AGG_COUNTY_TRENDS.
```
✅ Run the generated SQL

---

## PROMPT 14: Gold — Secure Views and Data Share
```
Create two secure views in GOLD:
1. SHARED_EV_COUNTY_TRENDS: select county, model_year, registration_count, bev_count, phev_count, avg_range_miles from AGG_COUNTY_TRENDS where county IS NOT NULL
2. SHARED_UTILITY_DEMAND: select electric_utility, ev_count, counties_served, avg_range_miles, bev_count from AGG_UTILITY_DEMAND

Then create a SHARE called EV_ANALYTICS_SHARE and grant USAGE on database and GOLD schema, and SELECT on both secure views to the share.
```
✅ Run the generated SQL

---

## PROMPT 15: Orchestration — Task DAG
```
Create a Task DAG in BRONZE schema:
1. PIPELINE_ROOT_TASK: WAREHOUSE=EV_WH, SCHEDULE='USING CRON 0 */6 * * * America/New_York'. Body: INSERT INTO PIPELINE_AUDIT (layer, table_name, row_count, notes) VALUES ('PIPELINE', 'ROOT', 0, 'Pipeline run started').
2. VALIDATE_DQ_TASK: AFTER PIPELINE_ROOT_TASK. Body: INSERT INTO PIPELINE_AUDIT selecting from SILVER.DQ_SUMMARY.
3. REFRESH_PIPELINE_TASK: AFTER VALIDATE_DQ_TASK. Body: ALTER DYNAMIC TABLE SILVER.EV_REGISTRATIONS REFRESH.
4. LOG_METRICS_TASK: AFTER REFRESH_PIPELINE_TASK. Body: INSERT INTO PIPELINE_AUDIT with count from GOLD.FACT_EV_REGISTRATIONS.

Resume all tasks leaf-to-root.
```
✅ Run the generated SQL

---

## PROMPT 16: Governance — Roles
```
Create three roles: DOL_ANALYST, UTILITY_READER, DATA_ENGINEER.
- DOL_ANALYST: USAGE on database + GOLD schema, SELECT on all tables/dynamic tables/views in GOLD
- UTILITY_READER: USAGE on database + GOLD schema, SELECT only on SHARED_UTILITY_DEMAND and SHARED_EV_COUNTY_TRENDS views
- DATA_ENGINEER: USAGE on database + all schemas, SELECT on all tables in BRONZE, SILVER, GOLD
```
✅ Run the generated SQL

---

## PROMPT 17: Governance — Masking Policy
```
Create a masking policy GOLD.ZIP_MASK on VARCHAR that returns the full value for ACCOUNTADMIN, DOL_ANALYST, and DATA_ENGINEER roles, but returns LEFT(val, 3) || '**' for everyone else. Apply it to the zip_code column on SILVER.EV_REGISTRATIONS.
```
✅ Run the generated SQL

---

## PROMPT 18: Governance — Tags
```
Create three tags in GOLD schema: PII (comment: Personally Identifiable Information), GEOGRAPHIC (comment: Geographic/Location data), FINANCIAL (comment: Financial/Pricing data). Apply PII tag to Silver zip_code, GEOGRAPHIC tag to Silver county, FINANCIAL tag to Silver base_msrp.
```
✅ Run the generated SQL

---

## PROMPT 19: dbt Model (Discussion)
```
Show me how to create a dbt model that calculates year-over-year EV registration growth by county. Use a CTE for yearly counts, then LAG window function for previous year, and classify growth as Explosive (>100%), High (50-100%), Moderate (20-50%), Low (0-20%), or Declining (<0%). Source from SILVER.EV_REGISTRATIONS.
```
✅ Review the output (don't need to run — already created via native dbt)

---

## PROMPT 20: Semantic Model
```
Create a Cortex Analyst semantic model YAML for these Gold tables: AGG_COUNTY_TRENDS, AGG_MAKE_SHARE, AGG_UTILITY_DEMAND, DIM_VEHICLE. Include dimensions, measures with default_aggregation, synonyms, and verified_queries for common questions like "How many total EV registrations?" and "What is Tesla's market share?"
```
✅ Review the output (already staged)

---

## DONE! 🎉

After replaying these 20 prompts, your CoCo chat history shows the FULL build journey.
During the demo, scroll through this history and say:

"I used Cortex Code as my primary development tool — 20 prompts that built the entire pipeline
from raw JSON to conversational analytics. CoCo accelerates iteration; I own the architecture."

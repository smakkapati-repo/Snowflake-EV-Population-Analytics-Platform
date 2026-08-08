# Cortex Code (CoCo) — Build Prompts Guide

## How to Present This in the Demo

During the presentation, you show that you used CoCo to build the pipeline. You can:
1. Show the CoCo chat history in Snowsight (right panel)
2. Live-prompt one small thing (e.g., "add a column" or "create a view") to show the workflow
3. Explain: "I used CoCo to iterate — prompt, review, refine. Here are the prompts I used."

---

## Prompt Sequence (In Order of Build)

### 1. Setup — Database, Schemas, Warehouse

```
Create a database called EV_PIPELINE with three schemas: BRONZE, SILVER, and GOLD.
Also create a warehouse called EV_WH with size XS, auto-suspend after 60 seconds,
and auto-resume enabled.
```

---

### 2. Bronze Layer — Stage and Raw Table

```
Create a stage in the BRONZE schema to load a JSON file. Then create a table called
RAW_EV_POPULATION that stores the raw JSON data as a VARIANT column along with a
load timestamp and filename.
```

**Follow-up prompt (loading data):**
```
The JSON file has a Socrata format with a "data" array containing all records.
Load the file from the stage, flatten the data array using LATERAL FLATTEN,
and insert each element as a separate row into RAW_EV_POPULATION.
```

---

### 3. Silver Layer — Dynamic Table

```
Create a Dynamic Table called SILVER.EV_REGISTRATIONS with TARGET_LAG of 1 hour
on warehouse EV_WH. It should read from BRONZE.RAW_EV_POPULATION and:
- Extract fields from the VARIANT column (vin is index 8, county is 9, city is 10,
  state is 11, zip is 12, model_year is 13, make is 14, model is 15, ev_type is 16,
  cafv is 17, range is 18, msrp is 19, legislative_district is 20, dol_vehicle_id is 21,
  geocoded_column is 22, electric_utility is 23, census_tract is 24)
- Use TRY_CAST for numeric fields
- INITCAP on model name
- Deduplicate by dol_vehicle_id (keep latest)
- Filter out records where dol_vehicle_id is null or model_year not between 1990-2027
```

---

### 4. Data Quality UDF (Snowpark Python)

```
Create a Python UDF called SILVER.DATA_QUALITY_SCORE that takes vin (varchar),
model_year (int), range_miles (int), msrp (float), and county (varchar) and
returns an integer score from 0-100.

Scoring rules:
- Start at 100
- Missing/invalid VIN (not 10 chars): -20
- Missing county: -10
- Model year outside 2000-2027: -15
- Range > 500 miles: -15
- MSRP > 200000: -10
- Pre-2010 with range > 300: -10
- Minimum 0
```

---

### 5. Gold Layer — Dimensions

```
Create three Dynamic Tables in GOLD schema with TARGET_LAG 1 hour:

1. DIM_VEHICLE: distinct combinations of vin_prefix, make, model, model_year,
   ev_type, cafv_eligibility, electric_range_miles, base_msrp.
   Surrogate key: SHA2 of vin_prefix + make + model + model_year

2. DIM_LOCATION: distinct county, city, state, zip_code, legislative_district,
   census_tract. Surrogate key: SHA2 of county + city + zip_code

3. DIM_UTILITY: distinct electric_utility values.
   Surrogate key: SHA2 of electric_utility
```

---

### 6. Gold Layer — Fact Table

```
Create a Dynamic Table GOLD.FACT_EV_REGISTRATIONS with TARGET_LAG 1 hour.
It should reference SILVER.EV_REGISTRATIONS and include:
- registration_sk (SHA2 of dol_vehicle_id)
- vehicle_sk, location_sk, utility_sk (matching dimension surrogate keys)
- dol_vehicle_id, registration_year (model_year), electric_range_miles,
  base_msrp, legislative_district, ingestion_timestamp
```

---

### 7. Gold Layer — Aggregates

```
Create three aggregate Dynamic Tables in GOLD:

1. AGG_COUNTY_TRENDS: group by county and model_year. Include registration_count,
   bev_count, phev_count, avg_range_miles, avg_msrp. Exclude null county/year.

2. AGG_MAKE_SHARE: group by make. Include total_registrations,
   market_share_pct (using window function), model_count, avg_range_miles.

3. AGG_UTILITY_DEMAND: group by electric_utility. Include ev_count,
   counties_served, avg_range_miles, bev_count. Exclude null utility.
```

---

### 8. Iceberg Table

```
Create an Iceberg table GOLD.ICE_AGG_COUNTY_TRENDS with CATALOG = 'SNOWFLAKE'
as a copy of GOLD.AGG_COUNTY_TRENDS. This enables multi-engine access
(Spark, Trino, Flink) without Snowflake lock-in.
```

---

### 9. Data Sharing

```
Create two secure views in GOLD:
1. SHARED_EV_COUNTY_TRENDS — county, model_year, registration_count, bev/phev counts, avg_range
2. SHARED_UTILITY_DEMAND — electric_utility, ev_count, counties_served, avg_range, bev_count

Then create a SHARE called EV_ANALYTICS_SHARE and grant SELECT on both
secure views to the share.
```

---

### 10. Orchestration — Task DAG

```
Create a Task DAG in BRONZE schema:

1. PIPELINE_ROOT_TASK: scheduled every 6 hours, logs start to PIPELINE_AUDIT table
2. VALIDATE_DQ_TASK: runs after root, inserts DQ metrics from SILVER.DQ_SUMMARY
3. REFRESH_PIPELINE_TASK: runs after DQ validation, refreshes Silver Dynamic Table
4. LOG_METRICS_TASK: runs after refresh, logs Gold fact count

Resume all tasks leaf-to-root order.
```

---

### 11. Governance

```
Create three roles: DOL_ANALYST, UTILITY_READER, DATA_ENGINEER.

- DOL_ANALYST gets full read on GOLD schema
- UTILITY_READER gets only the two shared views
- DATA_ENGINEER gets all schemas

Create a masking policy ZIP_MASK that shows full zip for ACCOUNTADMIN/DOL_ANALYST/DATA_ENGINEER
but only first 3 digits + '**' for everyone else. Apply to Silver zip_code column.

Create tags PII, GEOGRAPHIC, FINANCIAL and apply to appropriate columns.
```

---

### 12. Semantic Model

```
Create a Cortex Analyst semantic model YAML for the Gold layer tables.
Include AGG_COUNTY_TRENDS, AGG_MAKE_SHARE, AGG_UTILITY_DEMAND, and DIM_VEHICLE.
Define dimensions, measures with default_aggregation, synonyms for common terms,
and verified_queries for questions like "How many total EV registrations?"
and "What is Tesla's market share?"
```

---

### 13. Streamlit App

```
Create a Streamlit app with 4 tabs:
1. Cortex Analyst chat — uses _snowflake.send_snow_api_request to call
   /api/v2/cortex/analyst/message with the semantic model
2. Dashboard — KPI metrics (total registrations, manufacturers, counties, avg range)
   plus bar charts for market leaders and BEV vs PHEV
3. Regional — county-level bar chart (stacked BEV/PHEV)
4. Trends — line charts for YoY growth and range improvement

Use Arial font, Snowflake blue theme (#29B5E8), clean layout.
```

---

## Tips for Demo Day

1. **Don't replay ALL prompts live** — that takes 30+ minutes. Instead:
   - Show CoCo chat history (scroll through it)
   - Live-demo ONE prompt (something small like "Add a view that shows top 5 makes by registration count")
   - Say: "This is how I iterated on each layer"

2. **Show iteration** — if CoCo generates something slightly wrong, correct it. That shows judgment.

3. **Key talking point:**
   > "CoCo accelerates the build cycle — I focus on architecture decisions,
   > CoCo handles the DDL syntax. But I review every output because the
   > architect owns the design, not the tool."

4. **If asked "Did you build this entirely with CoCo?":**
   > "I used CoCo as my primary development tool — prompting, iterating,
   > refining. Some things I wrote manually where I had a specific pattern
   > in mind (like the DQ scoring UDF). The value of CoCo is speed of
   > iteration, not replacement of architectural thinking."

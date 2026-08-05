# EV Population Analytics Platform — Architecture Document

## Snowflake Principal Data Cloud Architect — SI Partners Interview

**Author:** Shashidhar Makkapati  
**Date:** August 2026  
**Version:** 1.0

---

## 1. Executive Summary

Washington State's Department of Licensing (DOL) maintains a registry of 22,000+ Electric Vehicle registrations. This project demonstrates an end-to-end data platform on Snowflake that transforms raw registration data into governed, shareable, conversational analytics — enabling DOL, electric utilities, and legislators to answer critical questions about EV adoption without writing SQL.

**Key capabilities delivered:**
- Automated medallion pipeline (Bronze → Silver → Gold) with data quality enforcement
- Open table format (Iceberg) for multi-engine interoperability
- Zero-copy data sharing with external stakeholders
- Natural language analytics via Cortex Analyst + Streamlit

---

## 2. Business Context & Stakeholders

| Stakeholder | Need | How We Solve It |
|-------------|------|-----------------|
| **DOL Analysts** | Track registration trends, identify data quality issues | Gold-layer dashboards, DQ monitoring |
| **Electric Utilities** | Plan charging infrastructure by service territory | Data Sharing — zero-copy, governed |
| **State Legislators** | EV adoption by district for policy decisions | Aggregates by legislative district, Streamlit visualizations |
| **Data Scientists** | Feature engineering for EV demand forecasting | Iceberg tables accessible from Spark/Python |
| **External Researchers** | Open data access without compromising governance | Snowflake Marketplace listing or Reader account |

---

## 3. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          SNOWFLAKE DATA CLOUD                                │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                        INGESTION                                     │    │
│  │                                                                      │    │
│  │   JSON File ──▶ Internal Stage ──▶ COPY INTO (Bronze Raw Table)     │    │
│  │                                                                      │    │
│  │   [Bonus: PostgreSQL ──▶ OpenFlow/CDC ──▶ Bronze Stream]            │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                              │                                               │
│                              ▼                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    MEDALLION PIPELINE                                │    │
│  │                                                                      │    │
│  │  ┌──────────┐        ┌──────────────┐        ┌─────────────────┐   │    │
│  │  │  BRONZE  │        │    SILVER    │        │      GOLD       │   │    │
│  │  │          │        │              │        │                  │   │    │
│  │  │ VARIANT  │──DT──▶│ Typed cols   │──DT──▶│ fact_registrations│  │    │
│  │  │ Raw JSON │        │ Validated    │        │ dim_vehicle      │   │    │
│  │  │ Immutable│        │ Deduped      │        │ dim_location     │   │    │
│  │  │          │        │ Standardized │        │ dim_utility      │   │    │
│  │  └──────────┘        └──────────────┘        │ agg_* tables     │   │    │
│  │                                               │                  │   │    │
│  │                                               │ ┌─────────────┐ │   │    │
│  │                                               │ │ ICEBERG TBL │ │   │    │
│  │                                               │ └─────────────┘ │   │    │
│  │                                               └─────────────────┘   │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                              │                                               │
│              ┌───────────────┼───────────────┐                              │
│              ▼               ▼               ▼                              │
│  ┌───────────────┐  ┌──────────────┐  ┌──────────────────┐                │
│  │ CORTEX ANALYST│  │ DATA SHARING │  │  ORCHESTRATION   │                │
│  │               │  │              │  │                   │                │
│  │ Semantic YAML │  │ Secure Share │  │ Task DAG          │                │
│  │ NL → SQL      │  │ Listing      │  │ Schedule + Alert  │                │
│  │      │        │  │ Reader Acct  │  │ Error handling    │                │
│  │      ▼        │  └──────────────┘  └──────────────────┘                │
│  │ ┌──────────┐ │                                                          │
│  │ │Streamlit │ │                                                          │
│  │ │Chat + Viz│ │                                                          │
│  │ └──────────┘ │                                                          │
│  └───────────────┘                                                          │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                      GOVERNANCE LAYER                                │    │
│  │  RBAC │ Dynamic Masking │ Row Access Policy │ Audit │ Lineage       │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘
```

**DT = Dynamic Table** (declarative, auto-refreshing transformation)

---

## 4. Design Decisions & Trade-offs

### Decision 1: Medallion Architecture vs. Alternatives

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| **Medallion (Bronze/Silver/Gold)** ✅ | Auditable lineage, reprocessable, incremental, industry standard | More objects to manage, slight storage overhead | **Selected** |
| Direct to Star Schema | Fewer layers, simpler | No raw audit trail, painful to reprocess, mixes quality concerns | Rejected |
| Data Vault 2.0 | Excellent for complex integrations, full historization | Over-engineered for single-source dataset, steep learning curve | Rejected |
| Lambda Architecture | Handles real-time + batch | Dual code paths, operational complexity | Rejected (overkill for this use case) |

**Rationale:** Medallion is the right fit because:
1. DOL needs audit trail — "show me exactly what came in" (Bronze preserves raw)
2. Data quality is a separate concern from business logic (Silver isolates it)
3. Different consumers need different granularities (Gold serves multiple patterns)
4. Incremental processing is natural — new registrations flow through without full reload

---

### Decision 2: Dynamic Tables vs. Tasks + Streams

| Option | Pros | Cons | When to Use |
|--------|------|------|-------------|
| **Dynamic Tables** ✅ | Declarative (just write target SQL), auto-refresh, auto-dependency resolution, no orchestration code | Less control over execution order, limited error handling, can't do complex procedural logic | Transformations that are pure SQL, predictable refresh patterns |
| Tasks + Streams | Full control, procedural logic, conditional branching, rich error handling | Imperative (must manage order manually), more code to maintain, stream offset management | Complex ETL with branching logic, external API calls, multi-step procedures |
| dbt + Tasks | Version-controlled SQL, testing framework, documentation | External tool dependency, adds complexity, overkill for small pipeline | Large teams, many models, need for CI/CD on transformations |

**Rationale:** Dynamic Tables for the core pipeline because:
1. All transformations are pure SQL/Snowpark — no procedural logic needed
2. Dependency resolution is automatic (Gold DT knows it depends on Silver DT)
3. Target lag gives us "near real-time" without managing Streams explicitly
4. Fewer moving parts = fewer things to break in a demo

**Hybrid approach:** I use a Task DAG for the *orchestration wrapper* (scheduling, alerting, monitoring) while the *transformations themselves* are Dynamic Tables. Best of both worlds.

---

### Decision 3: Iceberg Tables vs. Native Snowflake Tables

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| Native Snowflake Tables | Best performance, full feature support, simpler | Vendor lock-in, only queryable via Snowflake | Used for Bronze + Silver |
| **Iceberg Tables** ✅ (Gold aggregates) | Open format, multi-engine (Spark, Trino, Flink), no lock-in, portable | Slightly higher latency, some Snowflake features not supported (clustering, search optimization) | **Selected for Gold** |
| External Tables (on S3 Iceberg) | Read existing Iceberg data without import | Read-only, query performance depends on file layout | Not applicable here |

**Rationale:** Iceberg for Gold layer because:
1. Demonstrates interoperability — Gold data is queryable from Spark without Snowflake
2. Addresses the #1 concern of evaluators: "Am I locked in?"
3. Data scientists can access Gold tables from notebooks without Snowflake credits
4. Metadata is open (Iceberg catalog) — fits multi-cloud and open-data strategies
5. Bronze/Silver stay native because performance matters for pipeline speed

**Trade-off acknowledged:** Iceberg tables don't support Snowflake Search Optimization, Materialized Views, or automatic clustering. For this dataset size (22K rows), that's irrelevant. At scale, you'd evaluate whether the openness benefit outweighs the performance optimization loss.

---

### Decision 4: Data Sharing Method

| Option | Pros | Cons | Best For |
|--------|------|------|----------|
| **Secure Data Share** ✅ | Zero-copy, instant, governed by provider | Requires Snowflake account on consumer side | Known partners (utilities) |
| Snowflake Marketplace Listing | Discoverable, self-service, monetizable | Less control over who accesses, public or private listings | Broad distribution |
| Reader Account | Consumer doesn't need their own Snowflake account | Provider pays for compute, limited to read-only | Small consumers without Snowflake |
| Traditional ETL export | Works with any system | Data duplication, stale copies, no governance after export | Legacy systems only |

**Rationale:** Implement Secure Share as primary (utilities are known partners), with a Reader Account demo to show how non-Snowflake consumers can access. This demonstrates range.

---

### Decision 5: Semantic Model + Chat vs. Traditional BI

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| **Cortex Analyst + Streamlit** ✅ | Natural language access, no SQL knowledge needed, self-service | Newer feature (less battle-tested), depends on semantic model quality | **Selected** |
| Tableau/PowerBI dashboards | Mature, well-understood, rich visualizations | Requires licenses, predefined views, users can't ask ad-hoc questions | Complementary (not primary) |
| SQL Worksheets | Full flexibility | Requires SQL skills, not accessible to legislators/executives | For power users only |

**Rationale:** Cortex Analyst is the differentiator because:
1. Legislators and utility planners shouldn't need SQL — "How many BEVs in King County?" should just work
2. Demonstrates Snowflake's AI investment (directly relevant to this role's focus)
3. Combined with Streamlit, creates a complete self-service analytics app inside Snowflake
4. Shows partner enablement value — SIs can replicate this pattern for any customer dataset

---

### Decision 6: Data Quality Strategy

| Approach | Implementation | When It Catches Issues |
|----------|---------------|----------------------|
| **Schema validation** | Bronze → Silver: type casting with TRY_CAST, reject nulls on required fields | Load time |
| **Deduplication** | Composite key (VIN_1_10 + DOL_VEHICLE_ID), QUALIFY ROW_NUMBER() | Silver transformation |
| **Range validation** | Electric range 0-500, model year 1990-2027, MSRP 0-200000 | Silver transformation |
| **Referential integrity** | Make + Model combinations validated against known list | Silver transformation |
| **Completeness** | Track % null per column, alert if > threshold | Monitoring (post-load) |
| **Freshness** | Track last load timestamp, alert if > 24h stale | Orchestration layer |

**Why not a separate DQ tool (Great Expectations, Soda)?**
For this scope, Snowflake-native checks (SQL assertions + alerting) are sufficient and avoid external dependencies. At enterprise scale with 100+ tables, I'd recommend integrating Soda or Monte Carlo for centralized observability.

---

### Decision 7: Orchestration Design

```
                    ┌─────────────────────┐
                    │   ROOT TASK         │
                    │   (Scheduled: 1hr)  │
                    └──────────┬──────────┘
                               │
                    ┌──────────▼──────────┐
                    │  REFRESH BRONZE     │
                    │  (COPY INTO from    │
                    │   stage if new files)│
                    └──────────┬──────────┘
                               │
                    ┌──────────▼──────────┐
                    │  VALIDATE DQ        │
                    │  (Check thresholds, │
                    │   log results)      │
                    └──────────┬──────────┘
                               │
                 ┌─────────────┼─────────────┐
                 ▼                            ▼
    ┌────────────────────┐      ┌────────────────────┐
    │  DQ PASSED         │      │  DQ FAILED         │
    │  (Continue flow)   │      │  (Alert + stop)    │
    └─────────┬──────────┘      └────────────────────┘
              │
    ┌─────────▼──────────┐
    │  REFRESH DTs       │
    │  (ALTER DT REFRESH) │
    └─────────┬──────────┘
              │
    ┌─────────▼──────────┐
    │  UPDATE METRICS    │
    │  (Row counts, lag, │
    │   freshness)       │
    └────────────────────┘
```

**Why a Task DAG wrapping Dynamic Tables?**
- DTs handle the transformation logic (WHAT to compute)
- Tasks handle the operational concerns (WHEN to run, WHAT IF it fails, WHO to alert)
- This separation of concerns is cleaner than embedding everything in Tasks OR relying solely on DT auto-refresh

---

## 5. Language Selection: SQL vs. Snowpark Python

### Positioning

Snowpark is not an alternative to Dynamic Tables or dbt — it's the **execution language**. The real decision is: SQL vs. Snowpark Python for each transformation.

```
┌─────────────────────────────────────────────────────┐
│       HOW DO YOU WRITE TRANSFORMATIONS?               │
│                                                       │
│   SQL (native)    │   Snowpark Python (DataFrames)   │
└────────┬──────────┴──────────────┬───────────────────┘
         │                          │
         ▼                          ▼
┌─────────────────────────────────────────────────────┐
│       WHERE DO THEY RUN / HOW ARE THEY MANAGED?      │
│                                                       │
│  Dynamic Tables  │  dbt Models  │  Tasks + Procs     │
│  (declarative)   │  (compiled)  │  (imperative)      │
└─────────────────────────────────────────────────────┘
```

### Decision Framework

| Use Case | SQL | Snowpark Python | Why |
|----------|-----|----------------|-----|
| Standard transforms (filter, join, aggregate) | ✅ Better | Overkill | SQL is more readable, everyone knows it |
| Complex string parsing / regex | Either | ✅ Slightly better | Python regex is richer |
| ML feature engineering | Possible | ✅ Better | Pandas-like API, sklearn integration |
| External libraries (geospatial, NLP) | ❌ Can't | ✅ Required | Python UDFs bring any library |
| Row-level procedural logic (if/else per record) | Clunky (nested CASE) | ✅ Better | Python is natural for imperative logic |
| Data quality scoring with custom logic | Possible | ✅ Better | Complex scoring cleaner in Python |
| Readability for SQL-heavy teams | ✅ Better | Steeper curve | Most DE teams are SQL-first |

### Our Approach: Right Tool for the Complexity

| Layer | Language | Rationale |
|-------|----------|-----------|
| Bronze (ingestion) | **SQL** | COPY INTO is SQL-native, no benefit from Python here |
| Silver (cleanse/validate) | **SQL Dynamic Table** + **Snowpark Python UDF** for DQ scoring | Core transforms are set-based (SQL excels), DQ scoring has multi-field conditional logic (Python excels) |
| Gold (aggregates) | **SQL Dynamic Tables** + **one Snowpark DataFrame** aggregate | Show fluency in both — pick YoY growth calculation as Snowpark showcase |
| Streamlit app | **Python** | Streamlit is Python-native |
| Data Quality | **Snowpark Python UDF** | Weighted scoring with conditional branches is naturally Python |

### Snowpark Python UDF — Data Quality Scoring

```python
from snowflake.snowpark.functions import udf
from snowflake.snowpark.types import IntegerType

@udf(name="SILVER.data_quality_score", replace=True, 
     is_permanent=True, stage_location="@EV_PIPELINE.BRONZE.EV_JSON_STAGE")
def data_quality_score(vin: str, model_year: int, range_miles: int, 
                       msrp: float, county: str) -> int:
    """Score each record 0-100 based on completeness and validity."""
    score = 100
    # Completeness checks
    if not vin or len(str(vin)) != 10: score -= 20
    if not county: score -= 10
    # Validity checks
    if model_year and (model_year < 2000 or model_year > 2027): score -= 15
    if range_miles is not None and range_miles > 500: score -= 15
    if msrp is not None and msrp > 200000: score -= 10
    # Logical checks
    if model_year and model_year < 2010 and range_miles and range_miles > 300: score -= 10
    return max(score, 0)
```

**Why not pure SQL?** This would be 6+ nested CASE statements — hard to read, hard to maintain, impossible to unit test. The Python UDF is testable, extensible, and self-documenting.

### Snowpark DataFrame — Gold Layer YoY Growth

```python
from snowflake.snowpark.functions import col, count, lag, round as sf_round
from snowflake.snowpark.window import Window

session = Session.builder.configs(connection_params).create()
silver_df = session.table("EV_PIPELINE.SILVER.EV_REGISTRATIONS")

# YoY adoption growth by county
yoy_window = Window.partition_by("county").order_by("model_year")

adoption_trend = (
    silver_df
    .filter(col("model_year").isNotNull())
    .group_by("model_year", "county")
    .agg(count("*").alias("registration_count"))
    .with_column("prev_year_count", 
        lag("registration_count", 1).over(yoy_window))
    .with_column("yoy_growth_pct",
        sf_round(
            (col("registration_count") - col("prev_year_count")) 
            / col("prev_year_count") * 100, 2
        ))
    .sort(col("county"), col("model_year"))
)

# Write to Gold layer
adoption_trend.write.mode("overwrite").save_as_table(
    "EV_PIPELINE.GOLD.AGG_COUNTY_YOY_GROWTH"
)
```

**Why Snowpark here?** Demonstrates DataFrame API fluency + window functions. Could absolutely be SQL — but showing both proves versatility.

---

## 6. Cross-Layer Audit & Reconciliation

### Pipeline Metrics Table

```sql
CREATE TABLE EV_PIPELINE.BRONZE.PIPELINE_AUDIT (
    run_id          VARCHAR DEFAULT UUID_STRING(),
    run_timestamp   TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    layer           VARCHAR,        -- 'BRONZE', 'SILVER', 'GOLD'
    table_name      VARCHAR,
    row_count       INT,
    rejected_count  INT DEFAULT 0,
    dedup_removed   INT DEFAULT 0,
    dq_pass_count   INT DEFAULT 0,
    dq_fail_count   INT DEFAULT 0,
    avg_dq_score    FLOAT,
    notes           VARCHAR
);
```

### Reconciliation Query (Run After Each Pipeline Cycle)

```sql
-- Cross-layer row count check
WITH counts AS (
    SELECT 
        (SELECT COUNT(*) FROM BRONZE.RAW_EV_POPULATION) AS bronze_count,
        (SELECT COUNT(*) FROM SILVER.EV_REGISTRATIONS) AS silver_count,
        (SELECT COUNT(*) FROM GOLD.FACT_EV_REGISTRATIONS) AS gold_count
)
SELECT 
    bronze_count,
    silver_count,
    gold_count,
    bronze_count - silver_count AS rejected_at_silver,
    silver_count - gold_count AS dropped_at_gold,
    ROUND(gold_count / NULLIF(bronze_count, 0) * 100, 2) AS end_to_end_yield_pct
FROM counts;
```

### Alerting on Reconciliation Failure

```sql
-- Alert if yield drops below 90% (unexpected data loss)
CREATE OR REPLACE ALERT EV_PIPELINE.BRONZE.PIPELINE_YIELD_ALERT
    WAREHOUSE = EV_WH
    SCHEDULE = 'USING CRON 0 * * * * America/New_York'  -- Hourly
    IF (EXISTS (
        SELECT 1 FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
        WHERE end_to_end_yield_pct < 90
    ))
    THEN
        CALL SYSTEM$SEND_EMAIL(
            'ev_pipeline_alerts',
            'shamakka@amazon.com',
            'EV Pipeline: Yield Below 90%',
            'Cross-layer reconciliation detected data loss. Check PIPELINE_AUDIT table.'
        );
```

---

## 7. Snowflake vs. Traditional Spark/Lakehouse

### The "10-Minute Overview" Comparison Slide

| Dimension | Snowflake (Our Approach) | Traditional Spark + Delta Lake + Airflow |
|-----------|-------------------------|------------------------------------------|
| **Infrastructure** | Zero — fully managed, auto-scale | EMR/Databricks clusters, sizing decisions, spot interruptions |
| **Pipeline code** | Dynamic Tables (5 lines of SQL per layer) | Spark jobs (100+ lines PySpark), DAG definitions, cluster configs |
| **Orchestration** | Native Tasks (built-in) | Airflow/MWAA (separate service, separate infra, DAG maintenance) |
| **Near-real-time** | Dynamic Tables with TARGET_LAG | Structured Streaming (complex state management, checkpointing) |
| **Open format** | Iceberg Tables (native) | Delta Lake (native) or Iceberg (requires separate catalog) |
| **Data sharing** | Zero-copy, instant, governed | Copy data to S3, manage IAM, hope they use same format |
| **AI/NL Analytics** | Cortex Analyst + Streamlit (built-in) | Separate LLM infra, custom RAG pipeline, separate UI framework |
| **Governance** | Single pane: RBAC + masking + tags + audit | Lake Formation + IAM + Ranger + custom audit (fragmented) |
| **Cost model** | Per-second credits, auto-suspend (pay for use) | Instance-hours (pay for idle), separate storage costs |
| **Time to production** | Days | Weeks to months |
| **Team skill requirement** | SQL analysts can build pipelines | Need Spark/Python engineers ($$$) |

### When I'd Still Recommend Spark/Lakehouse

- Petabyte-scale streaming with sub-second latency (Kafka → Spark Structured Streaming)
- Heavy custom ML training requiring distributed GPU clusters
- Customer already has massive Spark investment and skilled team
- Multi-cloud data lake where 80% of processing is non-Snowflake

### Key Talking Point for Panel

> "For this EV dataset, a Spark/Airflow approach would require: an EMR cluster, an Airflow instance, a Delta Lake catalog, a separate BI tool, and a custom NL interface. That's 5 services to manage. On Snowflake, it's one platform — and the total code is maybe 200 lines of SQL + Python vs. 1000+ lines of PySpark + YAML + Terraform."

---

## 8. Agent Integration Discussion Points (Part 2 Extension)

### Cortex Agents — Beyond Simple Chat

The semantic model enables Cortex Analyst (NL → SQL). But the panel will ask: "How would you extend this to Cortex Agents?"

**Architecture evolution:**

```
Current:   User → Streamlit Chat → Cortex Analyst → SQL → Result
Future:    User → Cortex Agent → [Tool Selection] → Multiple Actions
                                      │
                              ┌───────┼───────┐
                              ▼       ▼       ▼
                         SQL Query  API Call  Alert
                         (Analyst)  (CRM)    (Notification)
```

### Discussion Points to Prepare

**1. Tool-Calling Capabilities:**
- Agent could call Cortex Analyst for data questions AND call external APIs for action
- Example: "Show me counties with >50% YoY EV growth AND create a CRM task for the utility rep to schedule infrastructure planning meetings"
- The semantic model becomes ONE tool in the agent's toolkit, not the whole system

**2. External System Integration (CRM/ERP):**
- Snowflake External Functions or Cortex Agent's tool-use can call Salesforce APIs
- Example flow: Query Gold layer → identify high-growth regions → push leads to CRM
- Data stays in Snowflake (governed), actions happen externally via API

**3. Multi-Turn Conversational Analytics:**
- Current Cortex Analyst is mostly single-turn (question → answer)
- Agents add memory: "Show me King County... now compare that to Pierce County... now what's driving the difference?"
- Agent maintains context window, refines queries iteratively

**4. Guardrails for Production:**
- Row-level security flows through to agent queries (user only sees their authorized data)
- Agent audit trail: every tool call logged
- Rate limiting to prevent runaway credit consumption
- Human-in-the-loop for write operations (agent can SUGGEST an action, human confirms)

---

## 9. Schema Design

### Bronze Layer
```sql
-- Raw ingestion, schema-on-read
CREATE TABLE bronze.raw_ev_registrations (
    ingestion_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    source_file         VARCHAR,
    raw_data            VARIANT    -- Full JSON record
);
```

### Silver Layer (Dynamic Table)
```sql
-- Typed, validated, deduplicated
CREATE DYNAMIC TABLE silver.ev_registrations
    TARGET_LAG = '1 hour'
    WAREHOUSE = transform_wh
AS
SELECT
    raw_data:vin_1_10::VARCHAR              AS vin_prefix,
    raw_data:county::VARCHAR                AS county,
    raw_data:city::VARCHAR                  AS city,
    raw_data:state::VARCHAR                 AS state,
    raw_data:zip_code::VARCHAR              AS zip_code,
    TRY_CAST(raw_data:model_year AS INT)    AS model_year,
    raw_data:make::VARCHAR                  AS make,
    INITCAP(raw_data:model::VARCHAR)        AS model,
    raw_data:ev_type::VARCHAR               AS ev_type,
    raw_data:cafv_type::VARCHAR             AS cafv_eligibility,
    TRY_CAST(raw_data:electric_range AS INT) AS electric_range_miles,
    TRY_CAST(raw_data:base_msrp AS NUMBER)  AS base_msrp,
    TRY_CAST(raw_data:legislative_district AS INT) AS legislative_district,
    raw_data:dol_vehicle_id::VARCHAR        AS dol_vehicle_id,
    raw_data:electric_utility::VARCHAR      AS electric_utility,
    raw_data:_2020_census_tract::VARCHAR    AS census_tract_2020,
    -- Geocoding (parsed from point)
    TRY_CAST(raw_data:geocoded_column:coordinates[0] AS FLOAT) AS longitude,
    TRY_CAST(raw_data:geocoded_column:coordinates[1] AS FLOAT) AS latitude,
    ingestion_timestamp,
    source_file
FROM bronze.raw_ev_registrations
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY raw_data:dol_vehicle_id::VARCHAR
    ORDER BY ingestion_timestamp DESC
) = 1  -- Deduplicate: keep most recent record per vehicle
WHERE raw_data:dol_vehicle_id IS NOT NULL  -- Reject records without primary identifier
  AND TRY_CAST(raw_data:model_year AS INT) BETWEEN 1990 AND 2027;  -- Range validation
```

### Gold Layer (Star Schema)
```
┌─────────────────────────────────┐
│     fact_ev_registrations       │
├─────────────────────────────────┤
│ registration_sk (SURROGATE KEY) │
│ vehicle_sk (FK)                 │
│ location_sk (FK)                │
│ utility_sk (FK)                 │
│ registration_date_key (FK)      │
│ electric_range_miles            │
│ base_msrp                       │
│ legislative_district            │
└─────────────────────────────────┘
         │         │         │
         ▼         ▼         ▼
┌──────────┐ ┌──────────┐ ┌──────────┐
│dim_vehicle│ │dim_location│ │dim_utility│
├──────────┤ ├──────────┤ ├──────────┤
│vehicle_sk│ │location_sk│ │utility_sk │
│vin_prefix│ │county     │ │utility_name│
│make      │ │city       │ │service_territory│
│model     │ │state      │ └──────────┘
│model_year│ │zip_code   │
│ev_type   │ │latitude   │
│cafv_elig │ │longitude  │
└──────────┘ │census_tract│
             └──────────┘
```

---

## 10. Governance Design

| Control | Implementation | Purpose |
|---------|---------------|---------|
| **RBAC** | Roles: `DOL_ANALYST`, `UTILITY_READER`, `DATA_ENGINEER` | Principle of least privilege |
| **Dynamic Masking** | Mask `zip_code` to first 3 digits for `UTILITY_READER` role | Privacy — utilities see region, not exact location |
| **Row Access Policy** | Utility users see only their service territory | Data isolation without separate tables |
| **Object Tagging** | Tags: `PII`, `GEOGRAPHIC`, `FINANCIAL` on sensitive columns | Classification for compliance |
| **Access History** | Built-in — every query logged with user, role, timestamp | Audit trail |

---

## 11. Cost Considerations

| Component | Sizing | Rationale |
|-----------|--------|-----------|
| Ingestion Warehouse | X-SMALL, auto-suspend 60s | Small dataset, infrequent loads |
| Transform Warehouse | SMALL, auto-suspend 120s | Dynamic Table refreshes — lightweight SQL |
| Analytics Warehouse | SMALL, auto-suspend 60s | Ad-hoc queries + Streamlit app |
| Cortex AI | Consumption-based (per query) | No idle cost — only when chat is used |
| Storage | Minimal (~50MB compressed) | 22K rows, Iceberg metadata overhead negligible |

**Estimated monthly cost:** < $50/month (trial tier would cover this entirely)

**Cost optimization patterns demonstrated:**
- Auto-suspend eliminates idle compute
- Warehouse separation prevents resource contention
- Dynamic Tables vs. scheduled Tasks = compute only when data changes
- Iceberg cold storage for historical aggregates

---

## 12. Extensibility & Production Considerations

If this were a production system at scale:

| Concern | What I'd Add |
|---------|-------------|
| **Real-time ingestion** | Snowpipe (auto-ingest from S3/GCS/Azure) or OpenFlow for CDC |
| **Scale to millions** | Clustering keys on Gold tables, Search Optimization, larger warehouses |
| **Multi-region** | Replication for DR, cross-cloud data sharing |
| **CI/CD** | GitHub Actions → SchemaChange / Terraform for DDL deployment |
| **Monitoring** | Snowflake Resource Monitors, warehouse credit alerts, DQ dashboards |
| **Testing** | dbt tests or custom SQL assertions in CI pipeline |
| **ML Extension** | Feature Store on Gold layer → churn/demand prediction models |

---

## 13. Technology Choices Summary

| Layer | Technology | Why This Over Alternatives |
|-------|-----------|---------------------------|
| Storage | Snowflake Native (Bronze/Silver) + Iceberg (Gold) | Performance where needed, openness where valued |
| Transformation | Dynamic Tables (SQL) | Declarative, auto-refresh, zero orchestration code |
| Orchestration | Task DAG | Native, no external tools, alerting built-in |
| Data Quality | SQL assertions + alerting | Right-sized — no need for Great Expectations at this scale |
| Sharing | Secure Share + Reader Account | Zero-copy, governed, demonstrates range |
| Analytics | Cortex Analyst + Streamlit | NL access, self-service, no external BI tool needed |
| Governance | RBAC + Masking + Tags | Native, unified with data platform |

---

## 14. CI/CD Considerations

### Approach: Git-Driven Deployments

```
Developer → GitHub PR → CI Checks → Merge → Deploy to Snowflake
```

| Component | Tool | Purpose |
|-----------|------|---------|
| Version control | GitHub | All SQL, Python, YAML in repo |
| CI checks | GitHub Actions | Lint SQL, validate semantic model YAML, dry-run dbt |
| Deployment | SchemaChange (or snowflake-cli) | Apply DDL changes to Snowflake environments |
| Environments | DEV / STAGING / PROD databases | Promote via PR merge (dev → main = deploy to prod) |

### GitHub Actions Workflow (Simplified)

```yaml
name: Snowflake CI/CD
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Lint SQL
        run: sqlfluff lint src/ --dialect snowflake
      - name: Validate semantic model
        run: python scripts/validate_semantic_model.py

  deploy:
    needs: validate
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Deploy to Snowflake
        env:
          SNOWFLAKE_ACCOUNT: ${{ secrets.SF_ACCOUNT }}
          SNOWFLAKE_USER: ${{ secrets.SF_USER }}
          SNOWFLAKE_PASSWORD: ${{ secrets.SF_PASSWORD }}
        run: |
          pip install snowflake-connector-python
          python scripts/deploy.py
```

### Why Not Full CI/CD for This Demo?

For a demo with one developer and one environment, full CI/CD is over-engineering. But I include it because:
1. It shows production thinking (the panel evaluates "operationalization")
2. It demonstrates I know HOW to productionize, even if I don't for a 22K-row demo
3. The GitHub repo structure IS the CI/CD foundation — scripts in `src/`, config separated, README documentation

---

## 15. What This Demonstrates to the Panel

| Capability | Evidence |
|-----------|----------|
| **Architecture thinking** | Medallion design with clear separation of concerns |
| **Trade-off analysis** | Every decision has alternatives evaluated with rationale |
| **Snowflake depth** | Dynamic Tables, Iceberg, Cortex, Sharing, Governance — all native |
| **Partner enablement mindset** | This entire pipeline is a reusable accelerator an SI could deploy in 2 weeks |
| **Production readiness** | Not just a demo — cost optimization, monitoring, extensibility considered |
| **Business value** | Every technical choice maps to a stakeholder need |

---

*"The best architecture isn't the most complex one — it's the one that solves the business problem with the fewest moving parts while remaining extensible for what's next."*

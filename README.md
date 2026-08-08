# EV Population Analytics Platform — Snowflake

## Overview
End-to-end data engineering solution on Snowflake using the Electric Vehicle Population Dataset (22,183 registrations from Washington State). Demonstrates medallion architecture, orchestration, open table formats, data sharing, and conversational analytics powered by Cortex Analyst.

## Project Structure

```
├── src/
│   ├── bronze/              # Raw data ingestion (Stage, COPY INTO, VARIANT)
│   ├── silver/              # Cleanse, validate, deduplicate (Dynamic Table + Snowpark UDF)
│   ├── gold/                # Facts, dimensions, aggregates, Iceberg, sharing
│   ├── orchestration/       # Task DAG (scheduling, DQ gate, alerting)
│   └── governance/          # RBAC, masking policies, object tags
├── dbt/                     # dbt model (YoY adoption growth) + tests
├── streamlit/               # Streamlit app + Cortex Analyst semantic model
├── docs/                    # Architecture document + diagram
└── data/                    # Source EV population JSON dataset
```

## Architecture

![Architecture Diagram](docs/architecture-diagram.png)

| Layer | Purpose | Snowflake Features |
|-------|---------|-------------------|
| **Bronze** | Raw ingestion, schema-on-read | Internal Stage, COPY INTO, VARIANT |
| **Silver** | Cleanse, validate, deduplicate | Dynamic Table, Snowpark Python UDF |
| **Gold** | Business aggregates, facts, dimensions | Dynamic Tables, Iceberg Table, Secure Views |
| **Analytics** | Conversational natural language queries | Cortex Analyst + Streamlit |
| **Sharing** | Zero-copy governed data sharing | Secure Share + Reader Account |
| **Governance** | Access control + classification | RBAC, Dynamic Masking, Object Tags |

## Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Architecture pattern | Medallion (Bronze/Silver/Gold) | Auditability, reprocessability, separation of concerns |
| Transformation engine | Dynamic Tables + dbt (hybrid) | DTs for declarative auto-refresh; dbt for testable, version-controlled models |
| Open table format | Iceberg in Gold layer | Multi-engine interop (Spark/Trino/Flink), no lock-in |
| Data quality | Snowpark Python UDF + SQL assertions | Right-sized for scope; at scale would add Soda/Monte Carlo |
| Orchestration | Task DAG wrapping Dynamic Tables | DTs = WHAT (transform), Tasks = WHEN/IF (operations) |
| NL Analytics | Cortex Analyst REST API | Semantic model → SQL generation → governed query execution |
| Sharing | Secure Share + Secure Views | Zero-copy, instant, governed by provider |

## Dataset

**Source:** Washington State Department of Licensing  
**Records:** 22,183 EV registrations  
**Fields:** VIN, County, City, State, Zip, Model Year, Make, Model, EV Type (BEV/PHEV), CAFV Eligibility, Electric Range, Base MSRP, Legislative District, State Agency Vehicle ID, Lat/Long, Electric Utility, Census Tract

## Running the Pipeline

**Initial setup (from scratch):** Execute SQL scripts in order:
```
src/bronze/01_setup.sql → 02_stage_and_load.sql → 03_audit.sql
src/silver/01_dynamic_table.sql → 02_dq_udf.sql → 03_dq_views.sql
src/gold/01_dimensions.sql → 02_fact.sql → 03_aggregates.sql → 04_iceberg.sql → 05_sharing.sql
src/orchestration/01_task_dag.sql
src/governance/01_rbac_masking.sql
```

**Ongoing operation:** Fully automated — no manual intervention needed:
- Task DAG runs every 6 hours (DQ validation → refresh → metrics logging)
- Dynamic Tables auto-refresh within 1-hour TARGET_LAG
- GitHub Actions auto-deploys code changes on merge to main

## Streamlit App

The Streamlit app provides:
- **Cortex Analyst chat** — natural language → SQL → results
- **Executive dashboard** — KPIs, market share, BEV/PHEV split
- **Regional analysis** — county-level adoption breakdown
- **Adoption trends** — YoY growth, range improvement, new manufacturers

## Documentation

- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — Full architecture document with trade-off analysis
- [`dbt/README.md`](dbt/README.md) — dbt vs Dynamic Tables design decision
- [`.github/workflows/deploy.yml`](.github/workflows/deploy.yml) — CI/CD pipeline (auto-deploys SQL, dbt, Streamlit on merge)

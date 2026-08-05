# Snowflake SI PSE Interview - EV Population Data Pipeline

## 🎯 Objective
Build a comprehensive data engineering solution on Snowflake using the Electric Vehicle Population Dataset, demonstrating medallion architecture, orchestration, open table formats, data sharing, and conversational analytics.

## 📅 Timeline
- **Received:** Aug 4, 2026
- **Estimated effort:** 3-5 business days
- **Deliverables due:** 1 day before panel interview (TBD - awaiting Kaylynn's scheduling email)

## 📁 Project Structure

```
snowflake-interview/
├── data/                    # Raw EV population JSON dataset
├── src/
│   ├── bronze/              # Raw data ingestion (Snowpark/SQL)
│   ├── silver/              # Cleanse, parse, validate, dedup
│   └── gold/                # Business aggregates, facts, dimensions
├── dbt/                     # dbt transformations (alternative approach)
├── streamlit/               # Streamlit apps (insights + chat interface)
├── tests/                   # Data quality checks
├── docs/                    # Architecture docs, diagrams, presentation
│   └── interview_instructions.pdf
├── .github/workflows/       # CI/CD pipeline
└── README.md
```

## 🏗️ Architecture Overview

### Part 1: Data Engineering Pipeline

| Layer | Purpose | Snowflake Features |
|-------|---------|-------------------|
| **Bronze** | Raw ingestion, schema-on-read | Stages, COPY INTO, Variant type, (Bonus: OpenFlow/CDC) |
| **Silver** | Cleanse, validate, deduplicate | Snowpark Python, Dynamic Tables, Streams |
| **Gold** | Business aggregates, dimensions, facts | Dynamic Tables, Iceberg Tables, Secure Views |

### Part 2: Semantic Model + Chat Interface
- Cortex Analyst semantic model on Gold layer
- Streamlit chat app for natural language queries
- Agent integration discussion (Cortex Agents, tool-calling)

## ✅ Deliverables Checklist

### Part 1 - Data Engineering Pipeline
- [ ] Analyze dataset fields and document schema
- [ ] Bronze layer: Ingest raw JSON → Snowflake stage → raw table
- [ ] Silver layer: Parse, cleanse, validate, deduplicate
- [ ] Gold layer: Fact tables, dimension tables, aggregates
- [ ] Dynamic Tables for automated refresh
- [ ] Iceberg Tables for open table format interoperability
- [ ] Data quality checks (schema, completeness, uniqueness, referential integrity, business rules, freshness)
- [ ] Orchestration (Tasks with DAG dependencies, scheduling, error handling)
- [ ] Data sharing configuration (Secure Share, Listings, Reader accounts)
- [ ] Bonus: OpenFlow ingestion with Postgres CDC

### Part 2 - Semantic Model & Analytics
- [ ] Build semantic model YAML on Gold layer
- [ ] Streamlit chat interface (Cortex Analyst)
- [ ] 2-4 insight visualizations (Streamlit or Notebooks)
- [ ] Discussion prep: Cortex Agents, multi-turn, external integrations

### Presentation & Docs
- [ ] Architecture diagram (data flow)
- [ ] Slide deck (10 min overview section)
- [ ] Demo script (20 min pipeline + 15 min semantic model)
- [ ] Trade-offs document (alternatives considered)
- [ ] GitHub repo (clean, documented, CI/CD)

## 📊 Dataset Summary

**Source:** Washington State Department of Licensing
**Format:** JSON (Socrata open data format)
**Records:** ~22,600 EV registrations
**Fields to extract:**
- VIN, County, City, State, Postal Code
- Model Year, Make, Model
- Electric Vehicle Type (BEV/PHEV)
- CAFV Eligibility (Clean Alternative Fuel Vehicle)
- Electric Range, Base MSRP
- Legislative District
- DOL Vehicle ID
- Vehicle Location (lat/long)
- Electric Utility
- 2020 Census Tract

## 🔑 Key Design Decisions to Document

1. **Why Medallion?** vs. star schema directly, vs. data vault
2. **Dynamic Tables vs. Tasks+Streams** — when to use each
3. **Iceberg vs. native tables** — interoperability vs. performance tradeoffs
4. **dbt vs. Snowpark** — declarative vs. programmatic transformations
5. **Cost implications** — warehouse sizing, auto-suspend, storage formats
6. **Data sharing method** — Direct Share vs. Listings vs. Data Exchange

## 🛠️ Tools & Accounts Needed

- [ ] Snowflake Trial Account (signup: https://trial.snowflake.com/)
- [ ] Cortex Code access (signup: https://signup.snowflake.com/cortex-code)
- [ ] GitHub repository (public, for sharing with panel)
- [ ] Optional: Postgres instance (for OpenFlow bonus)

## 📺 Presentation Format (60 min)

| Time | Section |
|------|---------|
| 10 min | Overview slides: architecture, trade-offs, business value |
| 20 min | Demo Part 1: Pipeline, orchestration, Iceberg, sharing |
| 15 min | Demo Part 2: Semantic model + Streamlit chat |
| 15 min | Q&A from panel |

**Audience:** Technical (Dev, DE, SA, ML Eng) + Business (Director/VP level)

# Demo Script — 60-Minute Panel Presentation

## Setup Before You Start
- [ ] Snowsight open, logged in, EV_WH running
- [ ] Slide deck open (PowerPoint or PDF backup)
- [ ] GitHub repo open in a separate tab (public)
- [ ] Water nearby
- [ ] Timer visible (phone or corner of screen)
- [ ] Close all notifications, Slack, email

---

## PART 1: SLIDES (10 min)

### Slide 1 — Title (15 sec)
**Say:** "Thank you everyone. I'm Shashi — today I'll walk you through an end-to-end data engineering platform I built on Snowflake using the EV Population Dataset."

→ Next slide

### Slide 2 — Use Case (1.5 min)
**Say:** "The dataset is 22,000+ electric vehicle registrations from Washington State. I framed it around a realistic scenario: a state transportation agency that needs to share EV adoption insights with utility partners for infrastructure planning — without requiring SQL skills from consumers."

**Point to table:** "Four personas — analysts want dashboards, utilities need governed shared data, policy planners want district-level insights, and data scientists need open format access from Spark."

→ Next slide

### Slide 3 — Architecture (2 min)
**Say:** "Here's the architecture. Standard medallion — Bronze holds raw JSON as VARIANT, Silver cleanses and deduplicates via Dynamic Table, Gold serves a star schema plus aggregates."

**Point to each section:**
- "Below Gold: Cortex Analyst for natural language analytics, Data Sharing for zero-copy governed access, and a Task DAG for orchestration."
- "Bottom: Governance wraps everything — RBAC, dynamic masking, object tags, full audit trail."
- "Note the Iceberg table in Gold and the dbt model — I'll explain why in a moment."

→ Next slide

### Slide 4 — Design Decisions (2 min)
**Say:** "Every choice has a trade-off. Let me highlight three:"

1. **Dynamic Tables over Tasks+Streams:** "Declarative — I define WHAT the target looks like, Snowflake handles WHEN and HOW to refresh. Zero orchestration code for transformations."

2. **Iceberg in Gold only:** "Bronze and Silver are native for pipeline performance. Gold is where external consumers live — Spark, Trino — so that's where openness matters. Snowflake-managed Iceberg now has near-parity performance, so there's minimal tradeoff."

3. **dbt for one model:** "Dynamic Tables handle the core pipeline. dbt adds value for its testing framework and CI/CD. I built one model to show the pattern — in production with 100+ models, I'd lean into dbt more heavily."

→ Next slide

### Slide 5 — Snowflake vs Spark/Lakehouse (2 min)
**Say:** "This is the business value slide. Same solution in Spark would require 5+ services, 1000+ lines of code, and weeks to production. On Snowflake: one platform, 200 lines, days. SQL analysts can build and maintain it — you don't need a team of Spark engineers."

**Point to key rows:** "Zero-copy sharing vs S3 copies. Built-in NL analytics vs custom RAG. Per-second billing vs idle clusters."

→ Next slide

### Slide 6 — Tool Selection (1.5 min)
**Say:** "I used multiple transformation approaches deliberately — Dynamic Tables as primary, dbt for the YoY model, Snowpark Python where complex logic adds value, Tasks for operational control. Right tool for each job."

**Point to Iceberg table:** "Open format at the boundary, native performance at the core."

→ Next slide

### Slide 7 — Cost & Governance (1 min)
**Say:** "Everything auto-suspends. Dynamic Tables only compute when data changes. Estimated cost: under $50/month for this entire pipeline. On governance — the key principle is that it inherits to AI. When Cortex Analyst generates SQL, it respects the same RBAC as any manual query."

→ Next slide

### Slide 8 — Demo Preview (15 sec)
**Say:** "Let me show you all of this running live."

→ Switch to Snowsight

---

## PART 2: LIVE DEMO — Pipeline (20 min)

### 2.1 CoCo History (2 min)
**Where:** Snowsight → CoCo panel (right side)

**Say:** "First — I built this entire pipeline using Cortex Code. 20 prompts, from empty database to conversational analytics. Let me scroll through..."

**Action:** Scroll through CoCo chat showing a few highlights (setup, Silver DT, DQ UDF, aggregates)

**Say:** "I directed the architecture, CoCo handled the syntax. Every SQL was reviewed before I ran it."

---

### 2.2 Bronze Layer (3 min)
**Where:** Snowsight → Databases → EV_PIPELINE → BRONZE

**Show:**
1. Click RAW_EV_POPULATION → Preview data
   - **Say:** "22,183 raw records. VARIANT column preserves the original JSON. No transformations at ingestion — quality is Silver's job."
   
2. Click on stage (EV_JSON_STAGE)
   - **Say:** "Source file loaded here. In production, this would be Snowpipe with auto-ingest from S3."

3. Show PIPELINE_AUDIT table
   - **Say:** "Every pipeline run is tracked — row counts, DQ metrics, timestamps."

---

### 2.3 Silver Layer (4 min)
**Where:** Transformation → Dynamic Tables → EV_REGISTRATIONS

**Show:**
1. Click the Dynamic Table → show the definition
   - **Say:** "Pure SQL — TRY_CAST for validation, INITCAP for standardization, QUALIFY for dedup. TARGET_LAG of 1 hour means this auto-refreshes without any Task or schedule."

2. Run a quick query in worksheet:
```sql
SELECT * FROM SILVER.EV_REGISTRATIONS LIMIT 5;
```
   - **Say:** "Typed columns, clean data, ready for Gold."

3. Show DQ UDF:
```sql
SELECT vin_prefix, make, model,
       SILVER.DATA_QUALITY_SCORE(vin_prefix, model_year, electric_range_miles, base_msrp, county) AS dq_score
FROM SILVER.EV_REGISTRATIONS
ORDER BY dq_score ASC LIMIT 5;
```
   - **Say:** "Snowpark Python UDF — scores each record 0-100. Complex conditional logic that would be unreadable in nested CASE statements."

4. Show DQ_SUMMARY:
```sql
SELECT * FROM SILVER.DQ_SUMMARY;
```
   - **Say:** "One-row view showing completeness, validity issues. This feeds the orchestration DQ gate."

---

### 2.4 Gold Layer (4 min)
**Where:** Transformation → Dynamic Tables (show the list)

**Show:**
1. Point to all 7 Dynamic Tables (dims, fact, aggs)
   - **Say:** "Star schema — fact table plus three dimensions. All Dynamic Tables with automatic dependency resolution. Gold knows it depends on Silver, Silver on Bronze."

2. Query an aggregate:
```sql
SELECT * FROM GOLD.AGG_MAKE_SHARE ORDER BY market_share_pct DESC LIMIT 5;
```
   - **Say:** "Tesla at 45%+ market share. These pre-computed aggregates feed both the Streamlit app and Cortex Analyst."

3. Show Iceberg:
```sql
SHOW ICEBERG TABLES IN SCHEMA GOLD;
SELECT COUNT(*) FROM GOLD.ICE_AGG_COUNTY_TRENDS;
```
   - **Say:** "Same data, open format. A Spark job can read this without Snowflake — no lock-in on the business layer."

---

### 2.5 dbt Model (2 min)
**Where:** Transformation → dbt Projects → EV_DBT_PROJECT

**Show:**
1. Click into the project — show the model file
   - **Say:** "One dbt model — YoY adoption growth with CTEs and window functions. Shows the pattern: source references, testing, documentation."

2. Show the output:
```sql
SELECT * FROM GOLD.AGG_YOY_ADOPTION_GROWTH WHERE growth_category = 'Explosive (>100%)' LIMIT 5;
```
   - **Say:** "Rural counties showing 400-700% growth — small base, but the infrastructure signal is clear."

---

### 2.6 Orchestration (2 min)
**Where:** Transformation → Tasks

**Show:**
1. Click PIPELINE_ROOT_TASK → show the DAG visualization
   - **Say:** "Four tasks: root triggers every 6 hours, DQ validation gates the pipeline, refresh only fires if quality passes, metrics get logged. Separation of concerns — DTs handle WHAT, Tasks handle WHEN and IF."

2. (Optional) Trigger manually:
```sql
EXECUTE TASK BRONZE.PIPELINE_ROOT_TASK;
```
   - **Say:** "Watch it cascade through the DAG."

---

### 2.7 Data Sharing (2 min)
**Where:** Data Sharing (left nav)

**Show:**
1. Click EV_ANALYTICS_SHARE
   - **Say:** "Zero-copy secure share. Two views exposed — county trends and utility demand. The consumer sees live data without any ETL or file copies."

2. Run:
```sql
DESCRIBE SHARE EV_ANALYTICS_SHARE;
```
   - **Say:** "Governed by us. One ALTER command adds a consumer. They see only what we expose through secure views."

---

### 2.8 Governance (1 min)
**Where:** Run in worksheet

**Show:**
```sql
-- Show masking in action
USE ROLE UTILITY_READER;
SELECT zip_code FROM SILVER.EV_REGISTRATIONS LIMIT 3;
-- Shows: 980**, 981**, etc.

USE ROLE ACCOUNTADMIN;
SELECT zip_code FROM SILVER.EV_REGISTRATIONS LIMIT 3;
-- Shows: 98101, 98052, etc.
```
   - **Say:** "Same table, different role, different visibility. The masking policy applies automatically — including to Cortex Analyst queries. Governance inherits to AI."

---

## PART 3: LIVE DEMO — Semantic Model & Chat (15 min)

### 3.1 Semantic Model (3 min)
**Where:** Open the YAML (from GitHub or worksheet)

**Show:** The semantic model structure
- **Say:** "Four tables mapped with dimensions, measures, default aggregations, and synonyms. Verified queries anchor common questions to known-good SQL. Cortex Analyst uses this as its 'understanding' of the data."

---

### 3.2 Streamlit App (7 min)
**Where:** Apps → EV Population Analytics

**Show:**
1. **Chat tab** — type: "What is Tesla's market share?"
   - Wait for result
   - **Say:** "Natural language → SQL → result. Business users don't write SQL. The semantic model guides Cortex Analyst to the right tables and aggregations."

2. Type another: "Which counties have the most EVs?"
   - **Say:** "King County dominates. This is the kind of question a utility planner asks when deciding where to build charging stations."

3. **Dashboard tab** — show KPIs and charts
   - **Say:** "Pre-built visualizations alongside the chat interface. Both powered by the same Gold layer."

4. **Trends tab** — show the growth line chart
   - **Say:** "BEV growing exponentially, PHEV flat. Average range tripling. These are the insights that informed the aggregate table design."

---

### 3.3 Notebook (3 min)
**Where:** Projects → Notebooks → EV_Exploration

**Show:** Scroll through the executed cells
- **Say:** "I used a Snowflake Notebook for exploratory analysis — Snowpark DataFrames, DQ scoring, discovering patterns. Once validated, I codified them into Dynamic Tables. Notebook for exploration, pipeline for production."

---

### 3.4 Cortex Agent (2 min)
**Where:** AI & ML → Agents → EV_ANALYTICS_AGENT

**Show:** Click into the agent — show the specification
- **Say:** "I also defined a Cortex Agent with Cortex Analyst as a tool and Data-to-Chart for visualizations. The agent adds orchestration intelligence — it decides which tool to use based on the question. On a trial account it can't execute, but the architecture is production-ready. Upgrading from Analyst to Agent is a one-endpoint API change."

---

## PART 4: Q&A (15 min)

### Key Answers to Have Ready:

**"Why Dynamic Tables over dbt for everything?"**
> "DTs are simpler for pure SQL transforms with predictable refresh. dbt wins at 100+ models with cross-team ownership where testing and CI/CD matter. I showed both to demonstrate range."

**"Why Iceberg in Gold, not Bronze?"**
> "Gold is where external consumers live. Bronze/Silver are internal plumbing — no one outside the team queries them. Also, Dynamic Tables on Iceberg are still newer — native gives full feature support for pipeline layers."

**"How does this scale to 100M rows?"**
> "Add clustering keys on Gold tables, enable Search Optimization, size up warehouses, use Snowpipe for continuous ingestion. Architecture stays the same — it's a sizing exercise, not a redesign."

**"What about OpenFlow?"**
> "OpenFlow requires a non-trial account — Snowflake's own docs confirm this. I demonstrated the equivalent CDC pattern with Streams and event-driven Tasks. Same mechanism, OpenFlow just wraps it in a managed UI with visual connectors."

**"What would you change in production?"**
> "Add Snowpipe for real-time ingestion, connect dbt Cloud for CI/CD, implement resource monitors for cost alerting, add Monte Carlo or Soda for observability at scale, and replicate cross-region for DR."

**"How did CoCo help?"**
> "20 prompts built the entire pipeline. I directed architecture, CoCo handled syntax. Where I had strong opinions (DQ scoring logic, surrogate key design), I was specific. Where I needed exploration, I kept prompts natural. The value is iteration speed, not replacement of judgment."

**"Can Cortex Analyst handle complex joins?"**
> "Yes — the semantic model defines relationships between tables. Analyst can join fact to dimensions automatically. For queries that span multiple tables, it composes CTEs. The verified queries help anchor common patterns."

**"Why not use Cortex Agents instead of Analyst?"**
> "Agents add multi-tool orchestration — Analyst for SQL, Search for unstructured, custom tools for APIs. For a structured-data-only use case, Analyst is sufficient. I defined the Agent object to show the upgrade path."

---

## Timing Guide

| Section | Target | Cumulative |
|---------|--------|-----------|
| Slides (8 slides) | 10 min | 10 min |
| CoCo + Bronze + Silver | 9 min | 19 min |
| Gold + dbt + Orchestration | 8 min | 27 min |
| Sharing + Governance | 3 min | 30 min |
| Semantic Model + Streamlit | 10 min | 40 min |
| Notebook + Agent | 5 min | 45 min |
| Q&A | 15 min | 60 min |

**If running long:** Skip notebook (just mention it), shorten CoCo scroll, compress governance to one query.

**If running short:** Add more live queries, show the reconciliation view, trigger the Task DAG live.

---

## Emergency Fallbacks

| If This Breaks | Do This |
|----------------|---------|
| Streamlit won't load | Show screenshots + explain the architecture |
| Cortex Analyst returns error | Use a pre-tested query from the list. "Let me try one I've validated." |
| Dynamic Table shows 0 rows | `ALTER DYNAMIC TABLE ... REFRESH` — "Let me force a refresh." |
| Warehouse is suspended | `ALTER WAREHOUSE EV_WH RESUME` — takes 2 seconds |
| Internet drops | You have local PowerPoint + screenshots. "Let me share my screen from the deck while we reconnect." |

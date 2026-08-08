# 🎯 Snowflake Interview Demo — Execution Plan

## The Goal
Deliver a **60-minute panel presentation** that makes the audience say: "This guy builds, not just talks."

**Audience:** Technical (DE, SA, ML Eng) + Business (Director/VP)  
**Deadline:** TBD (awaiting Kaylynn's scheduling email) — assume ~3-5 days from now  
**Approach:** Build for real, demo live, have fallback screenshots for everything

---

## 🗓️ Day-by-Day Build Plan

### Day 1 (Tonight + Tomorrow AM): Foundation & Bronze Layer
**Time: ~4-5 hours**

| # | Task | What You'll Show |
|---|------|-----------------|
| 1 | Sign up for Snowflake Trial (if not done) | Enterprise trial, AWS region |
| 2 | Set up database/schema structure | `EV_DEMO.BRONZE`, `EV_DEMO.SILVER`, `EV_DEMO.GOLD` |
| 3 | Upload JSON to internal stage | `PUT` command or Snowsight upload |
| 4 | Create raw table with VARIANT column | Schema-on-read, preserves all data |
| 5 | COPY INTO bronze table | Show ingestion speed, file format options |
| 6 | Create a flattened bronze view | Parse VARIANT into typed columns |

**Demo talking point:** "Raw data lands as-is. No transformations at ingestion — we preserve fidelity and deal with quality downstream."

---

### Day 2: Silver Layer + Data Quality
**Time: ~4-5 hours**

| # | Task | What You'll Show |
|---|------|-----------------|
| 1 | Dynamic Table: silver_ev_registrations | Auto-refreshing cleansed layer |
| 2 | Data quality rules | NULL handling, dedup (VIN+DOL_ID), type casting, range validation |
| 3 | Stream on bronze table | CDC detection for incremental processing |
| 4 | Snowpark Python UDF for geocoding parsing | Parse lat/long from point type |
| 5 | Data quality summary view | Show pass/fail counts, completeness % |

**Key design decisions to articulate:**
- Dynamic Tables vs. Tasks+Streams (chose Dynamic Tables for declarative simplicity — mention when you'd use the other)
- Dedup strategy: VIN + DOL Vehicle ID as composite key

---

### Day 3: Gold Layer + Iceberg + Orchestration
**Time: ~5-6 hours**

| # | Task | What You'll Show |
|---|------|-----------------|
| 1 | Fact table: `fact_ev_registrations` | Core grain = one row per vehicle registration |
| 2 | Dimension tables | `dim_vehicle`, `dim_location`, `dim_utility`, `dim_time` |
| 3 | Aggregate tables | EVs by county, by make, by year, adoption trends |
| 4 | Iceberg Table version of gold aggregate | Open table format interop |
| 5 | Task DAG for orchestration | Bronze→Silver→Gold pipeline with error handling |
| 6 | Data Sharing setup | Secure view + share to reader account (or listing) |

**Demo talking points:**
- "Iceberg means this data is queryable from Spark, Trino, Flink — not locked into Snowflake"
- "Tasks give us scheduling + dependency management + alerting — all native"
- "Data sharing: zero-copy, governed, no ETL between orgs"

---

### Day 4: Semantic Model + Streamlit Chat + Visuals
**Time: ~5-6 hours**

| # | Task | What You'll Show |
|---|------|-----------------|
| 1 | Cortex Analyst semantic model YAML | Dimensions, measures, time intelligence |
| 2 | Streamlit chat app (Cortex Analyst) | "How many Teslas registered in King County?" → SQL → result |
| 3 | 3-4 Streamlit visualizations | Adoption by year, make market share, geographic heatmap, range vs price |
| 4 | Test 10+ natural language queries | Prove it handles varied questions |

**This is your WOW moment.** Panel asks a question → you type it into chat → instant SQL + chart.

---

### Day 5: Polish, Slides, Rehearsal
**Time: ~4-5 hours**

| # | Task | Priority |
|---|------|----------|
| 1 | Architecture diagram (draw.io) | Must-have |
| 2 | Slide deck (10 min overview) | Must-have |
| 3 | Demo script with exact SQL to run | Must-have |
| 4 | Screenshot fallbacks for every demo step | Must-have |
| 5 | Trade-offs document | Nice-to-have (verbal is fine) |
| 6 | GitHub repo cleanup + README | Must-have |
| 7 | Full dress rehearsal (time yourself) | CRITICAL |

---

## 🏗️ Architecture Diagram (What You'll Present)

```
┌─────────────────────────────────────────────────────────────────────┐
│                        SNOWFLAKE PLATFORM                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────┐     ┌──────────────┐     ┌──────────────────────┐    │
│  │  BRONZE  │     │    SILVER    │     │         GOLD          │    │
│  │          │     │              │     │                        │    │
│  │ Raw JSON │────▶│ Dynamic Table│────▶│ Fact + Dimensions      │    │
│  │ VARIANT  │     │ Cleansed     │     │ Iceberg Table          │    │
│  │          │     │ Validated    │     │ Aggregates             │    │
│  └──────────┘     └──────────────┘     └───────────┬────────────┘    │
│       ▲                                             │                │
│       │                                             ▼                │
│  ┌─────────┐                              ┌─────────────────┐       │
│  │ Stage   │                              │ Cortex Analyst  │       │
│  │ (JSON)  │                              │ Semantic Model  │       │
│  └─────────┘                              └────────┬────────┘       │
│                                                     │                │
│  ┌──────────────────────┐                          ▼                │
│  │ Orchestration        │               ┌─────────────────┐        │
│  │ Task DAG (scheduled) │               │ Streamlit App   │        │
│  │ Error → Alert        │               │ Chat + Visuals  │        │
│  └──────────────────────┘               └─────────────────┘        │
│                                                                      │
│  ┌──────────────────────┐    ┌──────────────────────────┐          │
│  │ Data Sharing         │    │ Governance               │          │
│  │ Secure Share/Listing │    │ RBAC + Masking + Audit   │          │
│  └──────────────────────┘    └──────────────────────────┘          │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 💡 "Wow Factor" Moments to Engineer

These differentiate you from other candidates who just build a pipeline:

1. **Live NL Query** — Panel asks a question about EVs, you type it into Streamlit, instant answer
2. **Iceberg interop** — "This same table is readable from Spark without Snowflake" (show metadata)
3. **Data Sharing in 30 seconds** — Create a share, show a reader account querying it live
4. **Dynamic Table lag demo** — Insert a row into bronze, show it appear in gold within target lag
5. **Governance overlay** — Show RBAC, masking policy on PII (zip codes), audit trail

---

## 📊 Dataset Quick Facts (For Your Narrative)

- **22,183 EV registrations** across Washington State
- **Fields:** VIN, County, City, State, Zip, Model Year, Make, Model, EV Type (BEV/PHEV), CAFV eligibility, Electric Range, Base MSRP, Legislative District, DOL Vehicle ID, Lat/Long, Electric Utility, Census Tract
- **Narrative angle:** "A state DOL wants to understand EV adoption trends, plan infrastructure (charging stations), and share insights with utilities and legislators"

---

## 🎤 Presentation Narrative Arc

**Opening (1 min):** "Washington State DOL wants to answer: Where are EVs growing fastest? Which utilities need charging infrastructure? What does the legislative district breakdown look like? Let me show you how I'd solve this on Snowflake — from raw data to conversational analytics in one platform."

**Architecture (3 min):** Walk through diagram. Call out design decisions at each layer.

**Trade-offs (3 min):**
- Why Medallion vs. straight to star schema? (Auditability, reprocessing, incremental)
- Why Dynamic Tables vs. Tasks+Streams? (Declarative > imperative for this use case)
- Why Iceberg for Gold? (Open format, future-proofing, multi-engine access)
- Cost: warehouse sizing, auto-suspend, storage format implications

**Business Value (3 min):**
- DOL gets real-time adoption dashboards
- Utilities get shared data for infrastructure planning (via Snowflake sharing)
- Legislators get district-level analytics
- All governed, auditable, no data duplication

**Demo Part 1 (20 min):** Pipeline end-to-end, Iceberg, sharing  
**Demo Part 2 (15 min):** Semantic model + Streamlit chat  
**Q&A (15 min):** Handle with depth

---

## ⚠️ Risk Mitigation

| Risk | Mitigation |
|------|-----------|
| Live demo fails | Screenshots of every step saved locally. "Let me show you the result from my last run." |
| Cortex Analyst gives wrong SQL | Have 5 pre-tested queries ready. If one fails, pivot to another. |
| Internet drops | Record a 3-min video backup of the key demo flows |
| Runs over time | Practice until 10-min overview is EXACTLY 10 min. Have "skip" points marked. |
| Panel asks about feature you don't know | "That's a great question — let me share what I know and flag what I'd need to verify." Never bluff. |

---

## 🛠️ Tools Needed

- [ ] Snowflake Trial Account (Enterprise, AWS us-west-2 or us-east-1)
- [ ] Cortex Analyst access (should be included in Enterprise trial)
- [ ] Streamlit in Snowflake (SiS) — built into Snowsight
- [ ] GitHub repo (public) — for sharing with panel
- [ ] draw.io (for architecture diagram)
- [ ] Slide deck (Google Slides or Keynote — keep it minimal)

---

## 🎯 Success Criteria (What "Rocking It" Looks Like)

1. ✅ Working end-to-end pipeline (not slides about a pipeline)
2. ✅ Live queries returning results in real time
3. ✅ Chat interface answering natural language questions
4. ✅ Clear articulation of WHY at every design decision
5. ✅ Graceful handling of anything that breaks
6. ✅ Panel walks away thinking: "He ships. He'd make our partners successful."

---

## Next Steps (Right Now)

1. **Do you have a Snowflake trial account?** If not, sign up immediately (takes 5 min)
2. **I'll start building the Bronze layer code** — SQL scripts for stage, file format, raw table, COPY INTO
3. **Parallelize:** While you set up the account, I'll write Silver + Gold layer code

Let's go. 🚀

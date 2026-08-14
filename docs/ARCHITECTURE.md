# EV Population Analytics Platform — Architecture Document

**Author:** Shashidhar Makkapati | **Date:** August 2026 | **Version:** 1.0

---

## 1. Overview

End-to-end data platform on Snowflake transforming 22,000+ EV registration records into governed, shareable, conversational analytics. Stakeholders (analysts, utilities, policy planners, researchers) can query EV adoption trends without writing SQL.

**Capabilities:** Medallion pipeline (Bronze→Silver→Gold) • Dynamic Iceberg Tables for open interop • Zero-copy data sharing • Cortex Analyst + Streamlit for natural language analytics

---

## 2. Architecture

![EV Population Analytics Platform — Architecture Diagram](architecture-diagram.png)

**DT** = Dynamic Table (declarative, auto-refreshing)

---

## 3. Design Decisions & Trade-offs

### 3.1 Why Medallion?

| Option | Verdict | Rationale |
|--------|---------|-----------|
| **Medallion** ✅ | Selected | Audit trail (Bronze), quality isolation (Silver), multi-consumer patterns (Gold), incremental-friendly |
| Direct Star Schema | Rejected | No raw audit, painful reprocessing, mixes concerns |
| Data Vault 2.0 | Rejected | Over-engineered for single-source, steep learning curve |

### 3.2 Why Dynamic Tables?

| Option | Verdict | Rationale |
|--------|---------|-----------|
| **Dynamic Tables** ✅ | Selected (transforms) | Declarative, auto-dependency, zero orchestration code, target lag = near-real-time |
| Tasks + Streams | Selected (operations) | Used as orchestration WRAPPER — scheduling, DQ gate, alerting |
| dbt | Discussed | Better for large teams (100+ models, CI/CD lineage). Overkill for this scope. |

**Hybrid:** DTs handle WHAT (transformations). Tasks handle WHEN/IF (operations). Separation of concerns.

### 3.3 Why Dynamic Iceberg Tables in Gold?

| Layer | Format | Rationale |
|-------|--------|-----------|
| Bronze/Silver | Native Snowflake | Pipeline performance, full feature support |
| **Gold** | **Dynamic Iceberg** ✅ | Auto-refresh + open interop (Spark/Trino/Flink), no lock-in, no separate sync |

**Trade-off:** Dynamic Iceberg Tables combine auto-refresh with open format — no separate sync step. They don't support clustering or search optimization, but that's irrelevant at 22K rows; at scale, evaluate per table.

### 3.4 Data Sharing

| Method | Use Case |
|--------|----------|
| **Secure Share** ✅ | Known partners (utilities) — zero-copy, governed |
| Reader Account | Consumers without Snowflake — provider pays compute |
| Marketplace Listing | Broad public/private distribution |

### 3.5 Cortex Analyst + Streamlit

Selected over traditional BI because:
- No SQL required — policy planners ask "How many BEVs in King County?" and get answers
- Built-in to Snowflake — no external tool licensing
- SI-replicable — partners can deploy this pattern for any customer dataset

### 3.6 Data Quality Strategy

| Check | Implementation | Layer |
|-------|---------------|-------|
| Schema validation | TRY_CAST, reject nulls on required fields | Bronze→Silver |
| Deduplication | QUALIFY ROW_NUMBER() on VIN + State Agency_VEHICLE_ID | Silver |
| Range validation | Electric range 0-500, year 1990-2027, MSRP 0-200K | Silver |
| Completeness | % null per column, alert if > threshold | Monitoring |
| Cross-layer reconciliation | Row count: Bronze vs. Silver vs. Gold | Post-pipeline |
| Freshness | Alert if last load > 24h stale | Orchestration |

Native Snowflake checks (SQL + alerts) — no external DQ tool needed at this scale. At 100+ tables, add Soda or Monte Carlo.

---

## 4. SQL vs. Snowpark Python

Snowpark is the **language**, not an alternative to DTs/dbt. Decision = when to use each:

| Layer | Language | Why |
|-------|----------|-----|
| Bronze | **SQL** | COPY INTO is SQL-native |
| Silver transforms | **SQL** (Dynamic Table) | Set-based operations — readable, everyone knows SQL |
| DQ scoring | **Snowpark Python UDF** | Multi-field conditional logic is ugly in nested CASE statements — Python is testable and extensible |
| Gold aggregates | **SQL** + **one Snowpark DataFrame** (YoY growth) | Show fluency in both |
| Streamlit | **Python** | Streamlit is Python-native |

**Principle:** SQL for set-based operations. Python for procedural logic and external libraries.

---

## 5. Orchestration

```
ROOT TASK (hourly) → REFRESH BRONZE → VALIDATE DQ ──┬── PASS → REFRESH DTs → LOG METRICS
                                                      └── FAIL → ALERT + STOP
```

Task DAG wraps Dynamic Tables: DTs are the computation, Tasks are the operational control (when, what-if, who-to-alert).

---

## 6. Cross-Layer Reconciliation

```sql
SELECT 
    (SELECT COUNT(*) FROM BRONZE.RAW_EV_POPULATION) AS bronze_count,
    (SELECT COUNT(*) FROM SILVER.EV_REGISTRATIONS) AS silver_count,
    (SELECT COUNT(*) FROM GOLD.FACT_EV_REGISTRATIONS) AS gold_count,
    ROUND(gold_count / NULLIF(bronze_count, 0) * 100, 2) AS end_to_end_yield_pct;
```

Alert fires if yield < 90% (unexpected data loss between layers).

---

## 7. Snowflake vs. Spark/Lakehouse

| Dimension | Snowflake | Spark + Delta + Airflow |
|-----------|-----------|------------------------|
| Infrastructure | Zero (managed) | Clusters, sizing, spot interruptions |
| Pipeline code | ~5 lines SQL per layer (DTs) | 100+ lines PySpark + DAG YAML |
| Orchestration | Native Tasks | Separate Airflow/MWAA service |
| Open format | Iceberg (native) | Delta (native) or Iceberg (extra catalog) |
| Data sharing | Zero-copy, instant | Copy to S3 + IAM management |
| NL Analytics | Cortex Analyst (built-in) | Custom LLM + RAG + UI |
| Governance | Single pane (RBAC + masking + audit) | Lake Formation + IAM + Ranger (fragmented) |
| Cost model | Per-second, auto-suspend | Instance-hours (pay for idle) |
| Time to prod | Days | Weeks-months |

**When Spark wins:** Petabyte streaming, distributed GPU training, massive existing Spark investment.

---

## 8. Agent Integration

```
Today:   User → Cortex Analyst → SQL → Result
Future:  User → Cortex Agent → [Tool Selection] → SQL Query | API Call | Alert
```

**Key points:**
- Semantic model becomes ONE tool in agent's toolkit (not the whole system)
- Multi-turn: "Show King County... now compare to Pierce... what's driving the difference?"
- External integration: Query Gold → identify high-growth regions → push to CRM via External Functions
- Guardrails: RBAC flows through, every tool call audited, rate-limited, human-in-the-loop for writes

---

## 9. Governance

| Control | Implementation |
|---------|---------------|
| RBAC | Roles: State Agency_ANALYST, UTILITY_READER, DATA_ENGINEER |
| Dynamic Masking | zip_code → first 3 digits for UTILITY_READER |
| Row Access Policy | Utility users see only their service territory |
| Object Tags | PII, GEOGRAPHIC, FINANCIAL on sensitive columns |
| Audit | Every query logged (user, role, timestamp) |

---

## 10. Cost

| Component | Size | Rationale |
|-----------|------|-----------|
| Ingestion WH | XS, suspend 60s | Small dataset, infrequent |
| Transform WH | S, suspend 120s | DT refreshes |
| Analytics WH | S, suspend 60s | Queries + Streamlit |
| Cortex AI | Per-query | No idle cost |

**Total estimated:** < $50/month. Auto-suspend + warehouse separation + DTs (compute only on change) = minimal waste.

---

## 11. CI/CD

```
GitHub PR → Lint SQL (sqlfluff) → Validate semantic YAML → Merge → SchemaChange deploy
```

Environments: DEV → STAGING → PROD (promote via PR merge). Not built for this demo — but the repo structure IS the foundation.

---

## 12. Extensibility (Production Scale)

| Concern | Addition |
|---------|----------|
| Real-time | Snowpipe or OpenFlow CDC |
| Scale | Clustering keys, Search Optimization, larger WHs |
| DR | Cross-region replication |
| Monitoring | Resource Monitors, credit alerts, DQ dashboards |
| ML | Feature Store on Gold → demand prediction models |

---

*"The best architecture solves the business problem with the fewest moving parts while remaining extensible for what's next."*

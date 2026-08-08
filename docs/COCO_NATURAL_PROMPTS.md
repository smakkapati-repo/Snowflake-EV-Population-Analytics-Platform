# CoCo Natural Prompts — How a Real User Would Build This

These are conversational, intent-driven prompts (not dictating SQL).
Paste these into CoCo and see if it generates the same (or similar) output.

---

## PROMPT 1: Setup
```
I'm building an EV analytics pipeline. Set up a database called EV_PIPELINE with three layers — bronze for raw data, silver for cleaned data, and gold for business analytics. I also need a small warehouse for development.
```

---

## PROMPT 2: Bronze — Stage and Table
```
I need to ingest a JSON file into the bronze layer. Set up a stage and a raw table that preserves the original JSON as-is, with a timestamp of when it was loaded and which file it came from.
```

---

## PROMPT 3: Bronze — Load Data
```
My JSON file is in the stage. It's a Socrata open data format where all the records are inside a "data" array. I need to flatten that array so each record becomes its own row in the raw table.
```

---

## PROMPT 4: Bronze — Audit
```
I want to track pipeline health over time. Create an audit table that logs each run — how many rows, how many passed/failed quality checks, which layer, and any notes.
```

---

## PROMPT 5: Bronze — Reconciliation
```
Create a view that compares row counts across bronze, silver, and gold so I can quickly see if data is being lost between layers. Show me the yield percentage.
```

---

## PROMPT 6: Silver — Dynamic Table
```
Build a silver layer that automatically refreshes from bronze. It should parse the JSON array into proper typed columns — things like VIN, county, city, state, zip, model year, make, model, EV type, electric range, MSRP, utility, etc. Remove duplicates (keep the latest record per vehicle) and filter out records missing a vehicle ID or with unreasonable model years.
```

---

## PROMPT 7: Silver — DQ View
```
Create a data quality dashboard view on the silver table. I want to see how many records have invalid VINs, missing counties, missing model years, suspicious range values, and an overall completeness percentage.
```

---

## PROMPT 8: Silver — DQ Scoring UDF
```
I need a Python function that scores each record's quality from 0 to 100. Penalize for missing VIN, missing county, model year out of range, unrealistic electric range, high MSRP, and logical inconsistencies like an old car having a very high range.
```

---

## PROMPT 9: Gold — Dimensions
```
Build dimension tables for a star schema in gold. I need a vehicle dimension (make, model, year, type, range, price), a location dimension (county, city, state, zip, district), and a utility dimension. Use hash-based surrogate keys.
```

---

## PROMPT 10: Gold — Fact Table
```
Create the central fact table that ties the dimensions together. One row per EV registration, linking to vehicle, location, and utility dimensions via surrogate keys. Include the key metrics like range, MSRP, and legislative district.
```

---

## PROMPT 11: Gold — Aggregates
```
I need three pre-built aggregate tables for fast analytics:
1. EV adoption trends by county and year (include BEV vs PHEV split)
2. Market share by manufacturer (percent of total)
3. EV demand by electric utility territory
```

---

## PROMPT 12: Iceberg
```
Make one of the gold tables available in open Iceberg format so it can be queried from Spark or Trino without needing Snowflake. Use the county trends aggregate.
```

---

## PROMPT 13: Data Sharing
```
I want to share EV data with utility partners without copying it. Create secure views on the county trends and utility demand tables, then set up a share that external accounts can access.
```

---

## PROMPT 14: Orchestration
```
Set up a scheduled pipeline that runs every 6 hours. It should: log the start, check data quality, refresh the pipeline if quality passes, and log the final row counts. If quality fails, it should stop and alert.
```

---

## PROMPT 15: Governance — Roles
```
Create access roles for three personas: an analyst who can read gold data, a utility partner who can only see the shared views, and a data engineer who can access all layers.
```

---

## PROMPT 16: Governance — Masking
```
Zip codes are sensitive. Create a masking policy that shows the full zip to internal roles but masks it to just the first 3 digits for external users. Apply it to the silver table.
```

---

## PROMPT 17: Governance — Tags
```
Tag sensitive columns for data classification. Zip code is PII, county is geographic data, and MSRP is financial data.
```

---

## PROMPT 18: dbt Model
```
Show me a dbt model that calculates year-over-year registration growth by county. Classify each county-year as explosive, high, moderate, low, or declining growth.
```

---

## PROMPT 19: Semantic Model
```
Build a Cortex Analyst semantic model on my gold tables so business users can ask questions in plain English like "What's Tesla's market share?" or "Which counties have the most EVs?" Include synonyms for common terms.
```

---

## PROMPT 20: Streamlit App
```
Create a Streamlit app with a chat interface powered by Cortex Analyst, a dashboard showing key metrics and charts, a geographic view by county, and a trends tab showing adoption over time.
```

---

## Key Differences from Technical Prompts

| Aspect | Technical Prompts | Natural Prompts |
|--------|------------------|-----------------|
| Tone | "Create X with parameters Y, Z" | "I need to do X because Y" |
| Specificity | Dictates exact SQL | Describes intent, lets CoCo decide implementation |
| Column names | Spelled out explicitly | Described conceptually ("things like VIN, county...") |
| Architecture | Prescribed ("SHA2 surrogate keys") | Implied ("use hash-based surrogate keys") |
| Shows | You know the answer already | You're collaborating with CoCo |

## What to Expect

CoCo should generate similar (maybe not identical) SQL. Differences you might see:
- Different column ordering
- Different naming conventions (CoCo might use CREATED_AT vs LOAD_TIMESTAMP)
- Might suggest additional columns or features you didn't ask for
- Might ask clarifying questions

**That's fine.** The point is showing the WORKFLOW — prompt, review, refine. If CoCo generates something slightly different, you adjust. That's what architects do.

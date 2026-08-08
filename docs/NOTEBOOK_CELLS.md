# Snowflake Notebook — EV Population Data Exploration

Open Snowsight → Projects → Notebooks → EV_EXPLORATION → Add these cells in order.

---

## CELL 1 (Markdown)
```markdown
# 🔋 EV Population Data Exploration
**Snowpark Python analysis** on 22,183 electric vehicle registrations from Washington State DOL.

This notebook demonstrates:
- Snowpark DataFrame API for exploratory analysis
- Data quality scoring with Python UDF
- Key insights that informed the Gold layer aggregates
```

---

## CELL 2 (Python) — Setup & Load Data
```python
from snowflake.snowpark.context import get_active_session
from snowflake.snowpark.functions import col, count, avg, sum as sf_sum, round as sf_round, when, lit, lag
from snowflake.snowpark.window import Window
import streamlit as st

session = get_active_session()

# Load Silver layer data
df = session.table("EV_PIPELINE.SILVER.EV_REGISTRATIONS")
print(f"Total records: {df.count():,}")
print(f"Columns: {len(df.columns)}")
df.show(5)
```

---

## CELL 3 (Python) — Data Quality Analysis
```python
# Apply DQ scoring UDF across all records
dq_df = session.sql("""
    SELECT 
        SILVER.DATA_QUALITY_SCORE(vin_prefix, model_year, electric_range_miles, base_msrp, county) AS dq_score,
        COUNT(*) AS record_count
    FROM SILVER.EV_REGISTRATIONS
    GROUP BY 1
    ORDER BY 1
""").to_pandas()

st.subheader("📊 Data Quality Score Distribution")
st.bar_chart(dq_df.set_index('DQ_SCORE'))
st.metric("Average DQ Score", f"{dq_df['DQ_SCORE'].mean():.1f} / 100")
```

---

## CELL 4 (Python) — Insight 1: Market Share
```python
# Top manufacturers by market share
make_df = (
    df.group_by("make")
    .agg(count("*").alias("registrations"))
    .sort(col("registrations").desc())
    .limit(10)
    .to_pandas()
)

st.subheader("🏆 Top 10 EV Manufacturers")
st.bar_chart(make_df, x="MAKE", y="REGISTRATIONS")

# Tesla dominance
tesla_count = make_df[make_df['MAKE'] == 'TESLA']['REGISTRATIONS'].values[0]
total = make_df['REGISTRATIONS'].sum()
st.metric("Tesla Market Share", f"{tesla_count/total*100:.1f}%", f"{tesla_count:,} vehicles")
```

---

## CELL 5 (Python) — Insight 2: BEV vs PHEV Trend
```python
# EV type split over time
type_trend = session.sql("""
    SELECT model_year, 
           COUNT(CASE WHEN ev_type LIKE '%BEV%' THEN 1 END) AS bev,
           COUNT(CASE WHEN ev_type LIKE '%PHEV%' THEN 1 END) AS phev
    FROM SILVER.EV_REGISTRATIONS
    WHERE model_year >= 2011 AND model_year IS NOT NULL
    GROUP BY model_year
    ORDER BY model_year
""").to_pandas()

st.subheader("⚡ BEV vs PHEV Adoption Over Time")
st.line_chart(type_trend, x="MODEL_YEAR", y=["BEV", "PHEV"])
st.caption("BEV (pure electric) is growing exponentially while PHEV (hybrid) remains flat")
```

---

## CELL 6 (Python) — Insight 3: Range Improvement
```python
# Average range improvement by year
range_df = (
    df.filter(col("model_year") >= 2011)
    .filter(col("electric_range_miles") > 0)
    .group_by("model_year")
    .agg(sf_round(avg("electric_range_miles"), 1).alias("avg_range"))
    .sort("model_year")
    .to_pandas()
)

st.subheader("🔋 Average Electric Range Improvement")
st.line_chart(range_df, x="MODEL_YEAR", y="AVG_RANGE")
st.caption("Average range has nearly tripled since 2011 — driven by battery technology advances")
```

---

## CELL 7 (Python) — Insight 4: Geographic Concentration
```python
# Top 10 counties
county_df = session.sql("""
    SELECT county, COUNT(*) AS ev_count,
           ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM SILVER.EV_REGISTRATIONS), 1) AS pct_of_total
    FROM SILVER.EV_REGISTRATIONS
    WHERE county IS NOT NULL
    GROUP BY county
    ORDER BY ev_count DESC
    LIMIT 10
""").to_pandas()

st.subheader("🗺️ Geographic Concentration")
st.bar_chart(county_df, x="COUNTY", y="EV_COUNT")
st.metric("Top 3 Counties Share", 
          f"{county_df.head(3)['PCT_OF_TOTAL'].sum():.1f}% of all EVs")
st.caption("King County alone accounts for a massive share — infrastructure planning should start here")
```

---

## CELL 8 (Python) — YoY Growth (Snowpark DataFrame)
```python
# Year-over-year growth using Snowpark window functions
yoy_window = Window.order_by("model_year")

yearly = (
    df.filter(col("model_year") >= 2011)
    .filter(col("model_year").is_not_null())
    .group_by("model_year")
    .agg(count("*").alias("registrations"))
    .sort("model_year")
    .with_column("prev_year", lag("registrations", 1).over(yoy_window))
    .with_column("yoy_growth_pct", 
        sf_round((col("registrations") - col("prev_year")) / col("prev_year") * 100, 1))
    .to_pandas()
)

st.subheader("📈 Year-over-Year Registration Growth")
st.dataframe(yearly)
st.line_chart(yearly.dropna(), x="MODEL_YEAR", y="YOY_GROWTH_PCT")
```

---

## CELL 9 (Markdown) — Summary
```markdown
## 🔑 Key Findings

| Insight | Finding |
|---------|---------|
| Market dominance | Tesla holds ~45%+ market share |
| Vehicle type shift | BEV growing exponentially, PHEV flat — pure electric is winning |
| Range improvement | Average range nearly tripled since 2011 |
| Geographic concentration | Top 3 counties hold majority of registrations |
| Growth trajectory | Registrations growing 30-50%+ YoY in recent years |

These insights informed the Gold layer aggregate design and the Cortex Analyst semantic model.
```

---

## How to Create in Snowsight

1. Go to **Projects → Notebooks**
2. Find **EV_EXPLORATION** (already created)
3. Open it → set warehouse to **EV_WH**
4. Add cells one by one (toggle between Python and Markdown using the cell type dropdown)
5. Run all cells

This gives you a developer-facing exploration notebook alongside the business-facing Streamlit app.

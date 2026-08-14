import streamlit as st
import pandas as pd
import json
import _snowflake
from snowflake.snowpark.context import get_active_session

st.set_page_config(page_title="EV Analytics", page_icon="⚡", layout="wide")

session = get_active_session()

# --- CSS ---
st.markdown("""
<style>
    * { font-family: Arial, sans-serif !important; }
    .block-container { padding-top: 1.5rem; }
    .hero-title {
        font-size: 4.4rem; font-weight: 700;
        color: #29B5E8;
        margin-bottom: 2px;
    }
    .hero-sub {
        font-size: 0.9rem; color: #476B8A; margin-top: 0; margin-bottom: 20px;
    }
    h4, h3 { font-size: 1rem !important; font-weight: 600 !important; color: #232F3E !important; }
    div[data-testid="stMetricValue"] { font-size: 1.6rem; font-weight: 700; color: #29B5E8; }
    div[data-testid="stMetricLabel"] { font-size: 0.8rem; font-weight: 600; color: #476B8A; text-transform: uppercase; letter-spacing: 0.3px; }
    .stTabs [data-baseweb="tab"] { font-size: 0.85rem; font-weight: 600; }
    .insight-card {
        background: #F0F8FF;
        border-left: 4px solid #29B5E8; border-radius: 0 8px 8px 0;
        padding: 15px 20px; margin: 12px 0; font-size: 0.9rem;
    }
    .insight-card strong { color: #29B5E8; }
    .footer-badge {
        display: inline-block; background: #E8F4FA; border-radius: 16px;
        padding: 4px 10px; font-size: 0.7rem; color: #476B8A; font-weight: 600; margin: 2px;
    }
    p, li, td, th { font-size: 0.9rem !important; }
</style>
""", unsafe_allow_html=True)

# --- HEADER ---
st.markdown('<h1 style="font-size: 2.8rem !important; font-weight: 700 !important; color: #29B5E8 !important; margin-bottom: 0 !important; font-family: Arial, sans-serif !important;">EV Population Analytics</h1>', unsafe_allow_html=True)
st.markdown('<p class="hero-sub">22,183 electric vehicles · 33 manufacturers · Powered by Cortex Analyst</p>', unsafe_allow_html=True)

# --- CORTEX ANALYST ---
SEMANTIC_MODEL = "@EV_PIPELINE.ADMIN.EV_ANALYTICS_REPO/branches/main/streamlit/ev_semantic_model.yaml"

def call_cortex_analyst(question):
    """Call Cortex Analyst REST API."""
    request_body = {
        "messages": [
            {"role": "user", "content": [{"type": "text", "text": question}]}
        ],
        "semantic_model_file": SEMANTIC_MODEL
    }
    
    resp = _snowflake.send_snow_api_request(
        "POST",
        "/api/v2/cortex/analyst/message",
        {},
        {"Content-Type": "application/json"},
        request_body,
        {},
        30000
    )
    
    if resp["status"] == 200:
        data = json.loads(resp["content"])
        message = data.get("message", {})
        sql_statement = None
        text_response = None
        
        for content in message.get("content", []):
            if content.get("type") == "sql":
                sql_statement = content.get("statement", "")
            elif content.get("type") == "text":
                text_response = content.get("text", "")
        
        return {"success": True, "sql": sql_statement, "text": text_response}
    else:
        return {"success": False, "error": resp.get("content", "Unknown error")}

# --- TABS ---
tab1, tab2, tab3, tab4 = st.tabs(["💬 Cortex Analyst", "📊 Dashboard", "🗺️ Regional", "📈 Trends"])

# --- TAB 1 ---
with tab1:
    col_input, col_examples = st.columns([3, 2])
    
    with col_input:
        st.markdown("#### 🧠 Ask Anything (Powered by Cortex Analyst)")
        with st.form("analyst_form", clear_on_submit=False):
            prompt = st.text_input("", placeholder="e.g. What is Tesla's market share?", label_visibility="collapsed")
            submitted = st.form_submit_button("⚡ Ask Cortex Analyst", use_container_width=True)
    
    with col_examples:
        st.markdown("""#### 💡 Try These
- How many total EV registrations are there?
- Which counties have the most EVs?
- What is Tesla's market share?
- What is the BEV vs PHEV split?
- YoY growth in registrations
- Which utilities serve the most EVs?
- What percentage are CAFV eligible?
- How has range improved over time?
""")
    
    if submitted and prompt:
        st.markdown("---")
        with st.spinner("🧠 Cortex Analyst is thinking..."):
            result = call_cortex_analyst(prompt)
            
            if result["success"] and result["sql"]:
                if result["text"]:
                    st.markdown(f"*{result['text']}*")
                
                col_data, col_viz = st.columns([1, 1])
                
                with col_data:
                    try:
                        df = session.sql(result["sql"]).to_pandas()
                        st.table(df)
                    except Exception as e:
                        st.error(f"Query error: {str(e)[:200]}")
                        df = None
                
                with col_viz:
                    if df is not None and len(df.columns) >= 2:
                        numeric_cols = df.select_dtypes(include=['int64', 'float64']).columns.tolist()
                        non_numeric = [c for c in df.columns if c not in numeric_cols]
                        if numeric_cols and non_numeric:
                            try:
                                st.bar_chart(df, x=non_numeric[0], y=numeric_cols[0])
                            except:
                                pass
                
                with st.expander("🔧 Generated SQL"):
                    st.code(result["sql"], language="sql")
            elif result["success"] and result["text"]:
                st.info(result["text"])
            else:
                st.error(f"Error: {str(result.get('error', ''))[:300]}")

# --- TAB 2 ---
with tab2:
    col1, col2, col3, col4 = st.columns(4)
    total = session.sql("SELECT COUNT(*) FROM GOLD.FACT_EV_REGISTRATIONS").collect()[0][0]
    makes = session.sql("SELECT COUNT(DISTINCT make) FROM GOLD.DIM_VEHICLE").collect()[0][0]
    counties = session.sql("SELECT COUNT(DISTINCT county) FROM GOLD.DIM_LOCATION WHERE county IS NOT NULL").collect()[0][0]
    avg_range = session.sql("SELECT ROUND(AVG(electric_range_miles),0) FROM GOLD.DIM_VEHICLE WHERE electric_range_miles > 0").collect()[0][0]
    col1.metric("⚡ REGISTRATIONS", str(total))
    col2.metric("🏭 MANUFACTURERS", str(makes))
    col3.metric("📍 COUNTIES", str(counties))
    col4.metric("🔋 AVG RANGE", str(int(avg_range)) + " mi")
    st.markdown("---")
    col_left, col_right = st.columns(2)
    with col_left:
        st.markdown("#### 🏆 Market Leaders")
        make_data = session.sql("SELECT make AS MAKE, total_registrations AS REGISTRATIONS FROM GOLD.AGG_MAKE_SHARE ORDER BY total_registrations DESC LIMIT 10").to_pandas()
        st.bar_chart(make_data, x="MAKE", y="REGISTRATIONS")
    with col_right:
        st.markdown("#### ⚡ Vehicle Type Split")
        ev_type = session.sql("SELECT CASE WHEN ev_type LIKE '%BEV%' THEN 'Battery (BEV)' ELSE 'Hybrid (PHEV)' END AS TYPE, COUNT(*) AS VEHICLES FROM GOLD.DIM_VEHICLE GROUP BY 1").to_pandas()
        st.bar_chart(ev_type, x="TYPE", y="VEHICLES")
    st.markdown("---")
    tesla_share = session.sql("SELECT market_share_pct FROM GOLD.AGG_MAKE_SHARE WHERE make = 'TESLA'").collect()[0][0]
    top_county = session.sql("SELECT county, SUM(registration_count) AS t FROM GOLD.AGG_COUNTY_TRENDS GROUP BY county ORDER BY t DESC LIMIT 1").collect()[0]
    bev_pct = session.sql("SELECT ROUND(COUNT(CASE WHEN ev_type LIKE '%BEV%' THEN 1 END) * 100.0 / COUNT(*), 1) FROM GOLD.DIM_VEHICLE").collect()[0][0]
    st.markdown(f"""<div class="insight-card">
        <strong>🔑 Key Insights</strong><br><br>
        ⚡ Tesla commands <strong>{tesla_share}%</strong> market share<br>
        📍 <strong>{top_county[0]} County</strong> leads with <strong>{top_county[1]:,}</strong> EVs<br>
        🔋 <strong>{bev_pct}%</strong> are pure battery electric (BEV)
    </div>""", unsafe_allow_html=True)

# --- TAB 3 ---
with tab3:
    st.markdown("#### 🗺️ EV Adoption by County")
    county_data = session.sql("""
        SELECT county AS COUNTY, SUM(registration_count) AS TOTAL,
               SUM(bev_count) AS BEV, SUM(phev_count) AS PHEV
        FROM GOLD.AGG_COUNTY_TRENDS WHERE county IS NOT NULL
        GROUP BY county ORDER BY TOTAL DESC LIMIT 15
    """).to_pandas()
    st.bar_chart(county_data, x="COUNTY", y=["BEV", "PHEV"])
    st.markdown("---")
    st.dataframe(county_data, use_container_width=True)

# --- TAB 4 ---
with tab4:
    st.markdown("#### 📈 EV Registration Growth")
    yearly = session.sql("""
        SELECT model_year AS YEAR, SUM(registration_count) AS TOTAL,
               SUM(bev_count) AS BEV, SUM(phev_count) AS PHEV
        FROM GOLD.AGG_COUNTY_TRENDS WHERE model_year >= 2011
        GROUP BY model_year ORDER BY model_year
    """).to_pandas()
    st.line_chart(yearly, x="YEAR", y=["TOTAL", "BEV", "PHEV"])
    st.markdown("---")
    col_t1, col_t2 = st.columns(2)
    with col_t1:
        st.markdown("#### 🔋 Range Improvement")
        range_trend = session.sql("SELECT model_year AS YEAR, ROUND(AVG(avg_range_miles), 1) AS RANGE_MI FROM GOLD.AGG_COUNTY_TRENDS WHERE model_year >= 2011 AND avg_range_miles > 0 GROUP BY model_year ORDER BY model_year").to_pandas()
        st.line_chart(range_trend, x="YEAR", y="RANGE_MI")
    with col_t2:
        st.markdown("#### 🏭 Brands in Market")
        new_makes = session.sql("SELECT model_year AS YEAR, COUNT(DISTINCT make) AS BRANDS FROM GOLD.DIM_VEHICLE WHERE model_year >= 2011 GROUP BY model_year ORDER BY model_year").to_pandas()
        st.line_chart(new_makes, x="YEAR", y="BRANDS")

# --- FOOTER (fixed bottom) ---
st.markdown("<br><br><br>", unsafe_allow_html=True)
st.markdown("---")
st.markdown("""<div style="text-align: center; padding: 10px; position: relative; bottom: 0; width: 100%;">
    <span class="footer-badge">🧠 Cortex Analyst</span>
    <span class="footer-badge">🏗️ Medallion Architecture</span>
    <span class="footer-badge">⚙️ Dynamic Tables</span>
    <span class="footer-badge">🧊 Apache Iceberg</span>
    <span class="footer-badge">🔒 RBAC + Masking</span>
    <span class="footer-badge">📤 Data Sharing</span>
</div>""", unsafe_allow_html=True)

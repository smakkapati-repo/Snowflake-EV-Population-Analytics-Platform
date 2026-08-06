-- ============================================================
-- SILVER LAYER: Snowpark Python UDF — Data Quality Scoring
-- ============================================================
-- Design Decision: Python UDF vs SQL CASE statements
--   - Multi-field conditional logic is cleaner in Python
--   - Testable, extensible, self-documenting
--   - 6+ nested CASE statements would be unreadable
--   - Shows Snowpark fluency
-- ============================================================

USE DATABASE EV_PIPELINE;
USE SCHEMA SILVER;

CREATE OR REPLACE FUNCTION SILVER.DATA_QUALITY_SCORE(
    vin VARCHAR, 
    model_year INT, 
    range_miles INT, 
    msrp FLOAT, 
    county VARCHAR
)
RETURNS INT
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
HANDLER = 'score'
AS $$
def score(vin, model_year, range_miles, msrp, county):
    """Score each record 0-100 based on completeness and validity.
    
    Scoring rules:
      -20: Invalid or missing VIN (must be 10 chars)
      -10: Missing county
      -15: Model year out of range (2000-2027)
      -15: Electric range > 500 miles (suspicious)
      -10: MSRP > $200K (suspicious)
      -10: Pre-2010 vehicle with >300 mile range (impossible for era)
    """
    s = 100
    # Completeness
    if not vin or len(str(vin)) != 10: s -= 20
    if not county: s -= 10
    # Validity
    if model_year and (model_year < 2000 or model_year > 2027): s -= 15
    if range_miles is not None and range_miles > 500: s -= 15
    if msrp is not None and msrp > 200000: s -= 10
    # Logical consistency
    if model_year and model_year < 2010 and range_miles and range_miles > 300: s -= 10
    return max(s, 0)
$$;

-- Test the UDF
SELECT 
    vin_prefix, make, model, model_year,
    SILVER.DATA_QUALITY_SCORE(vin_prefix, model_year, electric_range_miles, base_msrp, county) AS dq_score
FROM SILVER.EV_REGISTRATIONS
ORDER BY dq_score ASC
LIMIT 10;

-- DQ score distribution
SELECT 
    CASE 
        WHEN SILVER.DATA_QUALITY_SCORE(vin_prefix, model_year, electric_range_miles, base_msrp, county) >= 90 THEN 'Excellent (90-100)'
        WHEN SILVER.DATA_QUALITY_SCORE(vin_prefix, model_year, electric_range_miles, base_msrp, county) >= 70 THEN 'Good (70-89)'
        WHEN SILVER.DATA_QUALITY_SCORE(vin_prefix, model_year, electric_range_miles, base_msrp, county) >= 50 THEN 'Fair (50-69)'
        ELSE 'Poor (<50)'
    END AS quality_band,
    COUNT(*) AS record_count
FROM SILVER.EV_REGISTRATIONS
GROUP BY 1
ORDER BY 1;

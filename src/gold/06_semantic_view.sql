-- ============================================================
-- GOLD LAYER: Semantic View (Cortex Analyst first-class object)
-- ============================================================
-- Design note:
--   The source of truth for the semantic model is streamlit/ev_semantic_model.yaml
--   (consumed by Cortex Analyst). This first-class Semantic View object is the
--   deployed, queryable counterpart, generated from that YAML.
--
--   Limitation: the YAML's Same-Period-Last-Year (SPLY) role-playing table
--   (AGG_COUNTY_TRENDS_LY, joined on a computed key model_year + 1) is NOT
--   included here — Semantic Views require joins on physical columns, not
--   computed expressions. YoY is served instead by the dbt model
--   agg_yoy_adoption_growth (LAG window function, physicalized).
-- ============================================================

USE DATABASE EV_PIPELINE;
USE SCHEMA GOLD;

create or replace semantic view EV_ANALYTICS
	tables (
		EV_PIPELINE.GOLD.AGG_COUNTY_TRENDS unique (COUNTY,MODEL_YEAR) with synonyms=('county trends','registrations by county','county EV data','geographic trends') comment='Pre-aggregated county-level EV adoption trends by model year.',
		EV_PIPELINE.GOLD.AGG_MAKE_SHARE unique (MAKE) with synonyms=('manufacturer share','make market share','brand analysis','OEM share') comment='Market share data by vehicle manufacturer.',
		EV_PIPELINE.GOLD.AGG_UTILITY_DEMAND unique (ELECTRIC_UTILITY) with synonyms=('utility demand','electric utility stats','power company EVs','utility service area') comment='EV demand by electric utility service territory.',
		EV_PIPELINE.GOLD.DIM_VEHICLE unique (VEHICLE_SK) with synonyms=('vehicle catalog','car models','EV models','vehicle specs') comment='Vehicle dimension with make, model, year, and specifications.'
	)
	facts (
		DIM_VEHICLE.IS_BEV as CASE WHEN EV_TYPE LIKE '%BEV%' THEN 1 END comment='Returns 1 when vehicle is a BEV, NULL otherwise.'
	)
	dimensions (
		AGG_COUNTY_TRENDS.COUNTY as COUNTY with synonyms=('region','area','location') comment='County where vehicles are registered.',
		AGG_COUNTY_TRENDS.MODEL_YEAR as MODEL_YEAR with synonyms=('year','registration year','vehicle year') comment='Model year of the vehicles (primary time grain).',
		AGG_COUNTY_TRENDS.ADOPTION_ERA as CASE WHEN MODEL_YEAR >= 2020 THEN 'Post-Mandate' WHEN MODEL_YEAR >= 2015 THEN 'Growth Era' ELSE 'Early Adoption' END with synonyms=('era','adoption phase','fiscal period','time period') comment='EV adoption era classification based on model year.',
		AGG_MAKE_SHARE.MAKE as MAKE with synonyms=('manufacturer','brand','company','OEM','automaker') comment='Vehicle manufacturer (e.g., TESLA, BMW, NISSAN).',
		AGG_UTILITY_DEMAND.ELECTRIC_UTILITY as ELECTRIC_UTILITY with synonyms=('utility','power company','energy provider','electric provider') comment='Electric utility provider name.',
		DIM_VEHICLE.VEHICLE_SK as VEHICLE_SK comment='Surrogate key for the vehicle dimension.',
		DIM_VEHICLE.VIN_PREFIX as VIN_PREFIX with synonyms=('VIN','vehicle identification') comment='First 10 characters of the Vehicle Identification Number.',
		DIM_VEHICLE.MAKE as MAKE with synonyms=('manufacturer','brand') comment='Vehicle manufacturer.',
		DIM_VEHICLE.MODEL as MODEL with synonyms=('vehicle model','car model') comment='Vehicle model name.',
		DIM_VEHICLE.MODEL_YEAR as MODEL_YEAR with synonyms=('year','vehicle year') comment='Model year of the vehicle.',
		DIM_VEHICLE.EV_TYPE as EV_TYPE with synonyms=('vehicle type','electric type','bev or phev','powertrain') comment='Electric vehicle type (BEV or PHEV).',
		DIM_VEHICLE.CAFV_ELIGIBILITY as CAFV_ELIGIBILITY with synonyms=('cafv','incentive eligibility','clean fuel eligible','CAFV status') comment='Clean Alternative Fuel Vehicle eligibility status.',
		DIM_VEHICLE.ELECTRIC_RANGE_MILES as ELECTRIC_RANGE_MILES with synonyms=('range','electric range','miles per charge') comment='Maximum electric-only driving range in miles.',
		DIM_VEHICLE.BASE_MSRP as BASE_MSRP with synonyms=('price','MSRP','sticker price') comment='Base manufacturer suggested retail price.'
	)
	metrics (
		AGG_COUNTY_TRENDS.TOTAL_EV_REGISTRATIONS as SUM(REGISTRATION_COUNT) with synonyms=('total registrations','total EVs') comment='Total EV registrations across all records.',
		AGG_COUNTY_TRENDS.TOTAL_BEV_COUNT as SUM(BEV_COUNT) with synonyms=('BEV registrations','pure electric total') comment='Total Battery Electric Vehicle registrations.',
		AGG_COUNTY_TRENDS.TOTAL_PHEV_COUNT as SUM(PHEV_COUNT) with synonyms=('PHEV registrations','hybrid total') comment='Total Plug-in Hybrid Electric Vehicle registrations.',
		AGG_COUNTY_TRENDS.BEV_SHARE_PCT as SUM(BEV_COUNT) * 100.0 / NULLIF(SUM(REGISTRATION_COUNT), 0) with synonyms=('BEV percentage','battery electric share','BEV ratio') comment='Percentage of registrations that are BEV.',
		DIM_VEHICLE.VEHICLE_COUNT as COUNT(*) comment='Number of distinct vehicle configurations.',
		DIM_VEHICLE.BEV_VEHICLE_COUNT as COUNT(CASE WHEN EV_TYPE LIKE '%BEV%' THEN 1 END) comment='Count of BEV models in the vehicle catalog.',
		DIM_VEHICLE.DISTINCT_BRAND_COUNT as COUNT(DISTINCT MAKE) comment='Number of distinct vehicle manufacturers offering EVs.'
	)
	comment='Semantic model for EV Population Analytics. Enables natural language queries on Washington State electric vehicle registration data including adoption trends, market share, utility demand patterns, and vehicle specifications. Supports BEV vs PHEV analysis, geographic distribution, and time intelligence.
'
	ai_verified_queries (
		TOTAL_EV_REGISTRATIONS AS ( 
QUESTION 'How many total EV registrations are there?' 
VERIFIED_AT 1785964800
VERIFIED_BY 'Shashi Makkapati'
ONBOARDING_QUESTION false
SQL 'SELECT SUM(REGISTRATION_COUNT) AS total_registrations FROM AGG_COUNTY_TRENDS'),
		TOP_COUNTIES AS ( 
QUESTION 'Which counties have the most EV registrations?' 
VERIFIED_AT 1785964800
VERIFIED_BY 'Shashi Makkapati'
ONBOARDING_QUESTION false
SQL 'SELECT COUNTY, SUM(REGISTRATION_COUNT) AS total FROM AGG_COUNTY_TRENDS GROUP BY COUNTY ORDER BY total DESC LIMIT 10'),
		TESLA_MARKET_SHARE AS ( 
QUESTION 'What is Tesla''s market share?' 
VERIFIED_AT 1785964800
VERIFIED_BY 'Shashi Makkapati'
ONBOARDING_QUESTION false
SQL 'SELECT MAKE, MARKET_SHARE_PCT FROM AGG_MAKE_SHARE WHERE MAKE = ''TESLA'''),
		BEV_VS_PHEV AS ( 
QUESTION 'What is the split between BEV and PHEV vehicles?' 
VERIFIED_AT 1785964800
VERIFIED_BY 'Shashi Makkapati'
ONBOARDING_QUESTION false
SQL 'SELECT EV_TYPE, COUNT(*) AS vehicle_count FROM DIM_VEHICLE GROUP BY EV_TYPE ORDER BY vehicle_count DESC'),
		YOY_GROWTH AS ( 
QUESTION 'What is the year-over-year growth in EV registrations?' 
VERIFIED_AT 1785964800
VERIFIED_BY 'Shashi Makkapati'
ONBOARDING_QUESTION false
SQL 'SELECT MODEL_YEAR, SUM(REGISTRATION_COUNT) AS total, SUM(REGISTRATION_COUNT) - LAG(SUM(REGISTRATION_COUNT)) OVER (ORDER BY MODEL_YEAR) AS yoy_change FROM AGG_COUNTY_TRENDS GROUP BY MODEL_YEAR ORDER BY MODEL_YEAR'),
		TOP_UTILITIES AS ( 
QUESTION 'Which electric utilities serve the most EVs?' 
VERIFIED_AT 1785964800
VERIFIED_BY 'Shashi Makkapati'
ONBOARDING_QUESTION false
SQL 'SELECT ELECTRIC_UTILITY, EV_COUNT, COUNTIES_SERVED FROM AGG_UTILITY_DEMAND ORDER BY EV_COUNT DESC LIMIT 10'),
		CAFV_ELIGIBILITY AS ( 
QUESTION 'What percentage of EVs are eligible for CAFV incentives?' 
VERIFIED_AT 1785964800
VERIFIED_BY 'Shashi Makkapati'
ONBOARDING_QUESTION false
SQL 'SELECT CAFV_ELIGIBILITY, COUNT(*) AS count, ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pct FROM DIM_VEHICLE GROUP BY CAFV_ELIGIBILITY ORDER BY count DESC'),
		RANGE_OVER_TIME AS ( 
QUESTION 'How has average electric range improved over the years?' 
VERIFIED_AT 1785964800
VERIFIED_BY 'Shashi Makkapati'
ONBOARDING_QUESTION false
SQL 'SELECT MODEL_YEAR, AVG(AVG_RANGE_MILES) AS avg_range FROM AGG_COUNTY_TRENDS GROUP BY MODEL_YEAR ORDER BY MODEL_YEAR'),
		TOP_MANUFACTURERS AS ( 
QUESTION 'Which manufacturers have the most EV registrations?' 
VERIFIED_AT 1785967316
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT MAKE, TOTAL_REGISTRATIONS, MARKET_SHARE_PCT FROM AGG_MAKE_SHARE ORDER BY TOTAL_REGISTRATIONS DESC LIMIT 5'),
		YOY_GROWTH_KING_COUNTY AS ( 
QUESTION 'How do King County registrations compare to the prior year?' 
VERIFIED_AT 1723300000
VERIFIED_BY 'CoCo'
ONBOARDING_QUESTION false
SQL 'SELECT MODEL_YEAR, REGISTRATION_COUNT AS current_year, LAG(REGISTRATION_COUNT) OVER (ORDER BY MODEL_YEAR) AS prior_year FROM AGG_COUNTY_TRENDS WHERE COUNTY = ''King'' ORDER BY MODEL_YEAR'),
		CUMULATIVE_REGISTRATIONS_BY_COUNTY AS ( 
QUESTION 'What is the cumulative registration trend for the top counties?' 
VERIFIED_AT 1723300000
VERIFIED_BY 'CoCo'
ONBOARDING_QUESTION false
SQL 'SELECT COUNTY, MODEL_YEAR, SUM(REGISTRATION_COUNT) OVER (PARTITION BY COUNTY ORDER BY MODEL_YEAR ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_registrations FROM AGG_COUNTY_TRENDS WHERE COUNTY IN (''King'', ''Snohomish'', ''Pierce'', ''Clark'', ''Thurston'') ORDER BY COUNTY, MODEL_YEAR')
	)
	with extension (CA='{"tables":[{"name":"AGG_COUNTY_TRENDS","dimensions":[{"name":"COUNTY"},{"name":"MODEL_YEAR"},{"name":"ADOPTION_ERA"}],"metrics":[{"name":"total_ev_registrations"},{"name":"total_bev_count"},{"name":"total_phev_count"},{"name":"BEV_SHARE_PCT"}],"filters":[{"name":"top_wa_counties","description":"Top 5 Washington State EV counties (King, Snohomish, Pierce, Clark, Thurston).","expr":"COUNTY IN (''King'', ''Snohomish'', ''Pierce'', ''Clark'', ''Thurston'')"}],"measures":[{"name":"REGISTRATION_COUNT","synonyms":["total registrations","ev count","number of evs","registrations"],"description":"Total number of EV registrations in that county and year.","expr":"REGISTRATION_COUNT","default_aggregation":"sum","data_type":"NUMBER"},{"name":"BEV_COUNT","synonyms":["battery electric vehicles","pure electric","battery electric count","full electric count"],"description":"Number of Battery Electric Vehicle (BEV) registrations.","expr":"BEV_COUNT","default_aggregation":"sum","data_type":"NUMBER"},{"name":"PHEV_COUNT","synonyms":["plug-in hybrid","hybrid electric","plug-in hybrid count"],"description":"Number of Plug-in Hybrid Electric Vehicle (PHEV) registrations.","expr":"PHEV_COUNT","default_aggregation":"sum","data_type":"NUMBER"},{"name":"AVG_RANGE_MILES","synonyms":["average range","electric range","range miles"],"description":"Average electric range in miles.","expr":"AVG_RANGE_MILES","default_aggregation":"avg","data_type":"NUMBER"},{"name":"AVG_MSRP","synonyms":["average price","msrp","mean price"],"description":"Average base MSRP excluding zero values.","expr":"AVG_MSRP","default_aggregation":"avg","data_type":"NUMBER"}]},{"name":"AGG_MAKE_SHARE","dimensions":[{"name":"MAKE"}],"filters":[{"name":"tesla_only","description":"Filters to Tesla only.","expr":"MAKE = ''TESLA''"}],"measures":[{"name":"TOTAL_REGISTRATIONS","synonyms":["registrations","total vehicles","vehicle count"],"description":"Total registrations for this manufacturer.","expr":"TOTAL_REGISTRATIONS","default_aggregation":"sum","data_type":"NUMBER"},{"name":"MARKET_SHARE_PCT","synonyms":["market share","share percentage","percent of market"],"description":"Market share as a percentage of total registrations.","expr":"MARKET_SHARE_PCT","default_aggregation":"avg","data_type":"NUMBER"},{"name":"MODEL_COUNT","synonyms":["number of models","models offered","model diversity"],"description":"Number of distinct vehicle models offered by this manufacturer.","expr":"MODEL_COUNT","default_aggregation":"sum","data_type":"NUMBER"},{"name":"AVG_RANGE_MILES","description":"Average electric range across all models from this manufacturer.","expr":"AVG_RANGE_MILES","default_aggregation":"avg","data_type":"NUMBER"}]},{"name":"AGG_UTILITY_DEMAND","dimensions":[{"name":"ELECTRIC_UTILITY"}],"measures":[{"name":"EV_COUNT","synonyms":["number of evs","vehicles served","total EVs"],"description":"Total EVs in this utility''s service territory.","expr":"EV_COUNT","default_aggregation":"sum","data_type":"NUMBER"},{"name":"COUNTIES_SERVED","synonyms":["service area","coverage","service area counties"],"description":"Number of counties in this utility''s service territory.","expr":"COUNTIES_SERVED","default_aggregation":"sum","data_type":"NUMBER"},{"name":"AVG_RANGE_MILES","description":"Average electric range in service area.","expr":"AVG_RANGE_MILES","default_aggregation":"avg","data_type":"NUMBER"},{"name":"BEV_COUNT","description":"Number of BEVs in this utility''s territory.","expr":"BEV_COUNT","default_aggregation":"sum","data_type":"NUMBER"}]},{"name":"DIM_VEHICLE","dimensions":[{"name":"VEHICLE_SK"},{"name":"VIN_PREFIX"},{"name":"MAKE"},{"name":"MODEL"},{"name":"MODEL_YEAR"},{"name":"EV_TYPE"},{"name":"CAFV_ELIGIBILITY"},{"name":"ELECTRIC_RANGE_MILES"},{"name":"BASE_MSRP"}],"facts":[{"name":"is_bev"}],"metrics":[{"name":"vehicle_count"},{"name":"bev_vehicle_count"},{"name":"distinct_brand_count"}],"filters":[{"name":"bev_vehicles_only","description":"Filters to Battery Electric Vehicles only, excluding PHEVs.","expr":"EV_TYPE LIKE ''%BEV%''"}]}]}');

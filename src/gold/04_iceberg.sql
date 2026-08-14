-- ============================================================
-- GOLD LAYER: Iceberg — CONSOLIDATED
-- ============================================================
-- Previously: This file created a separate static Iceberg table
-- (AGG_COUNTY_TRENDS_ICEBERG) as a manual copy for external engine access.
--
-- Now: Gold aggregates ARE Dynamic Iceberg Tables (see 03_aggregates.sql).
-- They auto-refresh AND expose Iceberg metadata natively.
-- No separate copy needed. External engines (Spark/Trino/Flink) read
-- the same tables via the Horizon Iceberg REST Catalog.
--
-- This file is retained for documentation of the design evolution.
-- ============================================================

-- Verify Iceberg format on Gold aggregates:
SHOW ICEBERG TABLES IN SCHEMA EV_PIPELINE.GOLD;

-- External engines connect via:
-- Catalog endpoint: https://<account>.snowflakecomputing.com/polaris/api/catalog
-- Credentials: Snowflake OAuth or PAT
-- Tables visible as: EV_PIPELINE.GOLD.AGG_COUNTY_TRENDS, AGG_MAKE_SHARE, AGG_UTILITY_DEMAND

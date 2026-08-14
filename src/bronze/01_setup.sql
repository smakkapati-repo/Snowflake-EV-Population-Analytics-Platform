-- ============================================================
-- BRONZE LAYER: Setup (Database, Schemas, Warehouse)
-- ============================================================

-- Database
CREATE DATABASE IF NOT EXISTS EV_PIPELINE;

-- Schemas (Medallion layers + operational)
CREATE SCHEMA IF NOT EXISTS EV_PIPELINE.BRONZE;
CREATE SCHEMA IF NOT EXISTS EV_PIPELINE.SILVER;
CREATE SCHEMA IF NOT EXISTS EV_PIPELINE.GOLD;
CREATE SCHEMA IF NOT EXISTS EV_PIPELINE.AUDIT;
CREATE SCHEMA IF NOT EXISTS EV_PIPELINE.ADMIN;

-- Warehouse (XS, auto-suspend for cost optimization)
CREATE WAREHOUSE IF NOT EXISTS EV_WH
    WAREHOUSE_SIZE = 'X-SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'EV Pipeline warehouse - XS for cost efficiency on 22K row dataset';

USE DATABASE EV_PIPELINE;
USE SCHEMA BRONZE;
USE WAREHOUSE EV_WH;
-- CI/CD trigger: 2026-08-06

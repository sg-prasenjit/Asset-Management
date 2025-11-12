-- =========================================
-- Assetica - Phase 1 Migration Script
-- File: 003_create_hangfire_database.sql
-- Purpose: Create Hangfire database for background jobs
-- Created: 2025-01-12
-- =========================================

\c postgres

-- Drop database if exists (use with caution)
-- DROP DATABASE IF EXISTS assetica_hangfire;

-- Create Hangfire database
CREATE DATABASE assetica_hangfire
    WITH
    OWNER = postgres
    ENCODING = 'UTF8'
    LC_COLLATE = 'en_US.utf8'
    LC_CTYPE = 'en_US.utf8'
    TABLESPACE = pg_default
    CONNECTION LIMIT = -1;

COMMENT ON DATABASE assetica_hangfire IS 'Hangfire database for background job processing';

-- Connect to Hangfire database
\c assetica_hangfire

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Hangfire will automatically create its schema tables when the application starts
-- This script just creates the database

-- Grant permissions
GRANT ALL PRIVILEGES ON DATABASE assetica_hangfire TO postgres;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO postgres;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO postgres;

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'Hangfire database created successfully!';
    RAISE NOTICE 'Database: assetica_hangfire';
    RAISE NOTICE 'Hangfire will auto-create its tables on first run';
END $$;

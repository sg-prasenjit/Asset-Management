-- =========================================
-- Assetica - Phase 1 Migration Script
-- File: 001_create_shared_auth_database.sql
-- Purpose: Create shared authentication database
-- Created: 2025-01-12
-- =========================================

-- This script should be run against PostgreSQL server
-- Creates the shared authentication database for tenant management

\c postgres

-- Drop database if exists (use with caution in production)
-- DROP DATABASE IF EXISTS assetica_auth;

-- Create authentication database
CREATE DATABASE assetica_auth
    WITH
    OWNER = postgres
    ENCODING = 'UTF8'
    LC_COLLATE = 'en_US.utf8'
    LC_CTYPE = 'en_US.utf8'
    TABLESPACE = pg_default
    CONNECTION LIMIT = -1;

COMMENT ON DATABASE assetica_auth IS 'Assetica shared authentication and tenant management database';

-- Connect to the auth database
\c assetica_auth

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create tenants table
CREATE TABLE IF NOT EXISTS tenants (
    tenant_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_name VARCHAR(200) NOT NULL,
    subdomain VARCHAR(100) UNIQUE NOT NULL,
    domain VARCHAR(200),
    logo_url VARCHAR(500),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    settings JSONB DEFAULT '{}'::jsonb,
    CONSTRAINT subdomain_format CHECK (subdomain ~* '^[a-z0-9-]+$')
);

CREATE INDEX idx_tenants_subdomain ON tenants(subdomain);
CREATE INDEX idx_tenants_active ON tenants(is_active);
CREATE INDEX idx_tenants_created ON tenants(created_at DESC);

COMMENT ON TABLE tenants IS 'Multi-tenant organizations using the platform';
COMMENT ON COLUMN tenants.subdomain IS 'Unique subdomain for tenant (e.g., acme in acme.assetica.io)';
COMMENT ON COLUMN tenants.settings IS 'Tenant-specific configuration in JSON format';

-- Create tenant_subscriptions table
CREATE TABLE IF NOT EXISTS tenant_subscriptions (
    subscription_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES tenants(tenant_id) ON DELETE CASCADE,
    plan_type VARCHAR(50) NOT NULL,
    user_limit INTEGER NOT NULL,
    storage_limit_gb INTEGER NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT valid_plan_type CHECK (plan_type IN ('Basic', 'Pro', 'Enterprise', 'Trial'))
);

CREATE INDEX idx_subscriptions_tenant ON tenant_subscriptions(tenant_id);
CREATE INDEX idx_subscriptions_active ON tenant_subscriptions(is_active);
CREATE INDEX idx_subscriptions_dates ON tenant_subscriptions(start_date, end_date);

COMMENT ON TABLE tenant_subscriptions IS 'Subscription plans and limits for each tenant';
COMMENT ON COLUMN tenant_subscriptions.plan_type IS 'Subscription plan: Basic, Pro, Enterprise, Trial';

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for tenants
CREATE TRIGGER update_tenants_updated_at
    BEFORE UPDATE ON tenants
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Create trigger for tenant_subscriptions
CREATE TRIGGER update_subscriptions_updated_at
    BEFORE UPDATE ON tenant_subscriptions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Insert initial data (demo tenant for development)
INSERT INTO tenants (tenant_name, subdomain, domain, is_active, settings)
VALUES
    ('Demo Organization', 'demo', 'demo.assetica.io', true, '{"color_theme": "blue", "timezone": "UTC"}'::jsonb),
    ('Test Company', 'test', 'test.assetica.io', true, '{"color_theme": "green", "timezone": "America/New_York"}'::jsonb)
ON CONFLICT (subdomain) DO NOTHING;

-- Insert subscriptions for demo tenants
INSERT INTO tenant_subscriptions (tenant_id, plan_type, user_limit, storage_limit_gb, start_date, is_active)
SELECT
    tenant_id,
    'Pro',
    50,
    25,
    CURRENT_DATE,
    true
FROM tenants
WHERE subdomain IN ('demo', 'test')
ON CONFLICT DO NOTHING;

-- Grant permissions
GRANT ALL PRIVILEGES ON DATABASE assetica_auth TO postgres;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO postgres;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO postgres;

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'Shared authentication database created successfully!';
    RAISE NOTICE 'Database: assetica_auth';
    RAISE NOTICE 'Tables created: tenants, tenant_subscriptions';
END $$;

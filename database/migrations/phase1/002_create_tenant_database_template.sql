-- =========================================
-- Assetica - Phase 1 Migration Script
-- File: 002_create_tenant_database_template.sql
-- Purpose: Create per-tenant database schema
-- Created: 2025-01-12
-- =========================================

-- This script creates a template tenant database
-- Replace 'demo' with actual tenant subdomain for new tenants

\c postgres

-- Drop database if exists (use with caution)
-- DROP DATABASE IF EXISTS assetica_tenant_demo;

-- Create tenant database
CREATE DATABASE assetica_tenant_demo
    WITH
    OWNER = postgres
    ENCODING = 'UTF8'
    LC_COLLATE = 'en_US.utf8'
    LC_CTYPE = 'en_US.utf8'
    TABLESPACE = pg_default
    CONNECTION LIMIT = -1;

COMMENT ON DATABASE assetica_tenant_demo IS 'Assetica tenant database for demo organization';

-- Connect to the tenant database
\c assetica_tenant_demo

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =========================================
-- USERS TABLE
-- =========================================
CREATE TABLE IF NOT EXISTS users (
    user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(100) UNIQUE NOT NULL,
    email VARCHAR(200) UNIQUE NOT NULL,
    password_hash VARCHAR(500) NOT NULL,
    employee_id UUID,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    department VARCHAR(100),
    role VARCHAR(50) NOT NULL,
    is_active BOOLEAN DEFAULT true,
    is_locked BOOLEAN DEFAULT false,
    failed_login_attempts INTEGER DEFAULT 0,
    last_login TIMESTAMP,
    force_password_change BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT valid_role CHECK (role IN ('TenantAdmin', 'ITTeam', 'Manager', 'Finance', 'Employee', 'Auditor'))
);

CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_employee ON users(employee_id);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_active ON users(is_active);

COMMENT ON TABLE users IS 'System users with access to the platform';
COMMENT ON COLUMN users.role IS 'User role: TenantAdmin, ITTeam, Manager, Finance, Employee, Auditor';

-- =========================================
-- EMPLOYEES TABLE
-- =========================================
CREATE TABLE IF NOT EXISTS employees (
    employee_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_code VARCHAR(50) UNIQUE NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(200) UNIQUE NOT NULL,
    phone VARCHAR(20),
    department VARCHAR(100) NOT NULL,
    designation VARCHAR(100),
    manager_id UUID REFERENCES employees(employee_id),
    location VARCHAR(100),
    status VARCHAR(20) DEFAULT 'Active',
    date_of_joining DATE,
    date_of_exit DATE,
    user_id UUID,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT valid_status CHECK (status IN ('Active', 'Inactive', 'OnLeave', 'Terminated'))
);

CREATE INDEX idx_employees_code ON employees(employee_code);
CREATE INDEX idx_employees_email ON employees(email);
CREATE INDEX idx_employees_department ON employees(department);
CREATE INDEX idx_employees_status ON employees(status);
CREATE INDEX idx_employees_manager ON employees(manager_id);

-- Add foreign key from users to employees (after both tables are created)
ALTER TABLE users ADD CONSTRAINT fk_users_employee
    FOREIGN KEY (employee_id) REFERENCES employees(employee_id) ON DELETE SET NULL;

COMMENT ON TABLE employees IS 'Employee master data for asset assignments';
COMMENT ON COLUMN employees.user_id IS 'Links to users table if employee has system access';

-- =========================================
-- AUDIT LOGS TABLE
-- =========================================
CREATE TABLE IF NOT EXISTS audit_logs (
    log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(user_id) ON DELETE SET NULL,
    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(100),
    entity_id UUID,
    old_value JSONB,
    new_value JSONB,
    ip_address VARCHAR(50),
    user_agent TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_audit_user ON audit_logs(user_id);
CREATE INDEX idx_audit_action ON audit_logs(action);
CREATE INDEX idx_audit_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX idx_audit_timestamp ON audit_logs(timestamp DESC);

COMMENT ON TABLE audit_logs IS 'Complete audit trail of all system actions';

-- =========================================
-- USER SESSIONS TABLE
-- =========================================
CREATE TABLE IF NOT EXISTS user_sessions (
    session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(user_id) ON DELETE CASCADE,
    token_hash VARCHAR(500) NOT NULL,
    refresh_token_hash VARCHAR(500),
    ip_address VARCHAR(50),
    user_agent TEXT,
    expires_at TIMESTAMP NOT NULL,
    is_active BOOLEAN DEFAULT true,
    last_activity TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_sessions_user ON user_sessions(user_id);
CREATE INDEX idx_sessions_token ON user_sessions(token_hash);
CREATE INDEX idx_sessions_active ON user_sessions(is_active);
CREATE INDEX idx_sessions_expiry ON user_sessions(expires_at);

COMMENT ON TABLE user_sessions IS 'Active user sessions for JWT token management';

-- =========================================
-- TRIGGERS
-- =========================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for updated_at
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_employees_updated_at
    BEFORE UPDATE ON employees
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =========================================
-- FUNCTIONS
-- =========================================

-- Function to cleanup expired sessions
CREATE OR REPLACE FUNCTION cleanup_expired_sessions()
RETURNS void AS $$
BEGIN
    DELETE FROM user_sessions
    WHERE expires_at < CURRENT_TIMESTAMP
    OR (is_active = true AND last_activity < CURRENT_TIMESTAMP - INTERVAL '30 minutes');
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION cleanup_expired_sessions() IS 'Removes expired and inactive sessions (run via Hangfire job)';

-- Grant permissions
GRANT ALL PRIVILEGES ON DATABASE assetica_tenant_demo TO postgres;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO postgres;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO postgres;

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'Tenant database created successfully!';
    RAISE NOTICE 'Database: assetica_tenant_demo';
    RAISE NOTICE 'Tables created: users, employees, audit_logs, user_sessions';
END $$;

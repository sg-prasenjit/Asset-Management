-- =========================================
-- Assetica - Seed Data Script
-- File: seed_admin_user.sql
-- Purpose: Create default admin user for demo tenant
-- Created: 2025-01-12
-- =========================================

-- Connect to demo tenant database
\c assetica_tenant_demo

-- Create default admin employee
INSERT INTO employees (
    employee_id,
    employee_code,
    first_name,
    last_name,
    email,
    phone,
    department,
    designation,
    location,
    status,
    date_of_joining
) VALUES (
    'a0000000-0000-0000-0000-000000000001'::uuid,
    'EMP-001',
    'Admin',
    'User',
    'admin@demo.assetica.io',
    '+1234567890',
    'IT',
    'System Administrator',
    'Head Office',
    'Active',
    CURRENT_DATE
) ON CONFLICT (employee_id) DO NOTHING;

-- Create default admin user
-- Password: Admin@123 (hashed with BCrypt cost factor 12)
-- IMPORTANT: Change this password after first login!
INSERT INTO users (
    user_id,
    username,
    email,
    password_hash,
    employee_id,
    first_name,
    last_name,
    department,
    role,
    is_active,
    is_locked,
    failed_login_attempts,
    force_password_change
) VALUES (
    'b0000000-0000-0000-0000-000000000001'::uuid,
    'admin',
    'admin@demo.assetica.io',
    '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYCkPFYZYoO', -- Admin@123
    'a0000000-0000-0000-0000-000000000001'::uuid,
    'Admin',
    'User',
    'IT',
    'TenantAdmin',
    true,
    false,
    0,
    true
) ON CONFLICT (user_id) DO NOTHING;

-- Update employee with user_id
UPDATE employees
SET user_id = 'b0000000-0000-0000-0000-000000000001'::uuid
WHERE employee_id = 'a0000000-0000-0000-0000-000000000001'::uuid;

-- Create additional test users for different roles
INSERT INTO employees (
    employee_code,
    first_name,
    last_name,
    email,
    department,
    designation,
    location,
    status,
    date_of_joining
) VALUES
    ('EMP-002', 'John', 'Doe', 'john.doe@demo.assetica.io', 'IT', 'IT Specialist', 'Head Office', 'Active', CURRENT_DATE),
    ('EMP-003', 'Jane', 'Smith', 'jane.smith@demo.assetica.io', 'Finance', 'Finance Manager', 'Head Office', 'Active', CURRENT_DATE),
    ('EMP-004', 'Bob', 'Johnson', 'bob.johnson@demo.assetica.io', 'Engineering', 'Engineering Manager', 'Branch Office', 'Active', CURRENT_DATE),
    ('EMP-005', 'Alice', 'Williams', 'alice.williams@demo.assetica.io', 'Sales', 'Sales Executive', 'Branch Office', 'Active', CURRENT_DATE)
ON CONFLICT (employee_code) DO NOTHING;

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'Admin user and test users created successfully!';
    RAISE NOTICE 'Default credentials:';
    RAISE NOTICE '  Username: admin';
    RAISE NOTICE '  Password: Admin@123';
    RAISE NOTICE 'IMPORTANT: Change the password after first login!';
END $$;

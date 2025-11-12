# PHASE 1: Foundation & Multi-Tenant Setup
## Assetica Implementation Guide

**Duration:** 3-4 weeks  
**Team:** 2 Backend + 2 Frontend + 1 QA  
**Priority:** Critical Foundation

---

## Overview

Build the foundational architecture with multi-tenant support, authentication, and basic user management. This phase establishes the core infrastructure that all subsequent phases will build upon.

---

## Deliverables

- ✅ Multi-tenant database architecture with isolation
- ✅ JWT-based authentication system with refresh tokens
- ✅ Role-Based Access Control (RBAC)
- ✅ User management with security features
- ✅ Tenant management for Super Admin
- ✅ Employee master data structure
- ✅ Basic dashboard framework
- ✅ Audit logging infrastructure
- ✅ Background job infrastructure (Hangfire)
- ✅ Session timeout management

---

## Database Architecture

### Shared Authentication Database

**Purpose:** Stores tenant information and shared authentication data

#### Table: tenants
```sql
CREATE TABLE tenants (
    tenant_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_name VARCHAR(200) NOT NULL,
    subdomain VARCHAR(100) UNIQUE NOT NULL,
    domain VARCHAR(200),
    logo_url VARCHAR(500),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    settings JSONB DEFAULT '{}'::jsonb
);

CREATE INDEX idx_tenants_subdomain ON tenants(subdomain);
CREATE INDEX idx_tenants_active ON tenants(is_active);
```

**Key Fields:**
- `subdomain`: Used for tenant identification (e.g., "acme" in acme.assetica.io)
- `settings`: JSON field for tenant-specific configurations

---

#### Table: tenant_subscriptions
```sql
CREATE TABLE tenant_subscriptions (
    subscription_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES tenants(tenant_id) ON DELETE CASCADE,
    plan_type VARCHAR(50) NOT NULL,
    user_limit INTEGER NOT NULL,
    storage_limit_gb INTEGER NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_subscriptions_tenant ON tenant_subscriptions(tenant_id);
CREATE INDEX idx_subscriptions_active ON tenant_subscriptions(is_active);
```

**Plan Types:**
- Basic: 10 users, 5GB storage
- Pro: 50 users, 25GB storage
- Enterprise: Unlimited users, 100GB storage

---

### Per-Tenant Database

**Purpose:** Each tenant has their own database for complete data isolation

#### Table: employees
```sql
CREATE TABLE employees (
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
    user_id UUID REFERENCES users(user_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_employees_code ON employees(employee_code);
CREATE INDEX idx_employees_email ON employees(email);
CREATE INDEX idx_employees_department ON employees(department);
CREATE INDEX idx_employees_status ON employees(status);
CREATE INDEX idx_employees_manager ON employees(manager_id);
```

**Key Relationships:**
- `user_id`: Links to users table if employee has system access (NULL for non-system users)
- `manager_id`: Self-referencing for organizational hierarchy

**Valid Status Values:**
- Active
- Inactive
- OnLeave
- Terminated

---

#### Table: users
```sql
CREATE TABLE users (
    user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(100) UNIQUE NOT NULL,
    email VARCHAR(200) UNIQUE NOT NULL,
    password_hash VARCHAR(500) NOT NULL,
    employee_id UUID REFERENCES employees(employee_id),
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
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_employee ON users(employee_id);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_active ON users(is_active);
```

**User Profile Logic:**
- If `employee_id` is NOT NULL: Use employee table data (first_name, last_name, department from employees)
- If `employee_id` IS NULL: Use user table data (for contractors, super admins, external users)

**Valid Roles:**
- SuperAdmin (platform level, not tenant specific)
- TenantAdmin
- ITTeam
- Manager
- Finance
- Employee
- Auditor

**Security Features:**
- Account locks after 5 failed attempts
- Force password change on first login
- Password complexity requirements enforced

---

#### Table: audit_logs
```sql
CREATE TABLE audit_logs (
    log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(user_id),
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
```

**Critical Actions to Log:**
- CREATE_USER, UPDATE_USER, DELETE_USER
- CREATE_ASSET, UPDATE_ASSET, DELETE_ASSET
- ASSIGN_ASSET, UNASSIGN_ASSET
- APPROVE_TRANSFER, REJECT_TRANSFER
- DISPOSE_ASSET
- LOGIN, LOGOUT, PASSWORD_CHANGE

---

#### Table: user_sessions
```sql
CREATE TABLE user_sessions (
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
```

**Session Management:**
- JWT Access Token: 1 hour expiry
- Refresh Token: 7 days expiry
- Session timeout: 30 minutes of inactivity
- Auto-logout on timeout

---

## API Endpoints

### Authentication APIs

#### POST /api/auth/login
**Purpose:** User authentication and token generation

**Request:**
```json
{
  "username": "string",
  "password": "string",
  "rememberMe": boolean
}
```

**Response (Success):**
```json
{
  "accessToken": "string",
  "refreshToken": "string",
  "expiresIn": 3600,
  "user": {
    "userId": "uuid",
    "username": "string",
    "email": "string",
    "role": "string",
    "fullName": "string",
    "forcePasswordChange": boolean
  }
}
```

**Business Rules:**
- Lock account after 5 failed attempts
- Log all login attempts (success and failure)
- Update last_login timestamp on success
- Create session record

---

#### POST /api/auth/refresh-token
**Purpose:** Refresh expired access token

**Request:**
```json
{
  "refreshToken": "string"
}
```

**Response:**
```json
{
  "accessToken": "string",
  "expiresIn": 3600
}
```

---

#### POST /api/auth/logout
**Purpose:** Invalidate current session

**Request:** None (uses Authorization header)

**Response:**
```json
{
  "message": "Logged out successfully"
}
```

**Business Rules:**
- Invalidate current session
- Clear token from database
- Log logout action

---

#### POST /api/auth/forgot-password
**Purpose:** Initiate password reset

**Request:**
```json
{
  "email": "string"
}
```

**Response:**
```json
{
  "message": "Password reset link sent to email"
}
```

**Business Rules:**
- Generate secure reset token (valid for 1 hour)
- Send email with reset link
- Don't reveal if email exists (security)

---

#### POST /api/auth/reset-password
**Purpose:** Complete password reset

**Request:**
```json
{
  "token": "string",
  "newPassword": "string"
}
```

**Business Rules:**
- Validate token not expired
- Enforce password complexity
- Invalidate all existing sessions
- Clear failed login attempts

---

#### POST /api/auth/change-password
**Purpose:** User changes their own password

**Request:**
```json
{
  "currentPassword": "string",
  "newPassword": "string"
}
```

**Requires:** Valid authentication

---

#### GET /api/auth/me
**Purpose:** Get current user profile

**Response:**
```json
{
  "userId": "uuid",
  "username": "string",
  "email": "string",
  "role": "string",
  "fullName": "string",
  "department": "string",
  "employeeDetails": {
    "employeeId": "uuid",
    "employeeCode": "string",
    "designation": "string",
    "manager": "string"
  }
}
```

---

### User Management APIs

#### GET /api/users
**Purpose:** List all users with filtering

**Query Parameters:**
- `page`: integer (default: 1)
- `pageSize`: integer (default: 25)
- `role`: string (optional filter)
- `status`: string (optional filter - Active/Inactive)
- `department`: string (optional filter)
- `search`: string (search by name, email, username)

**Response:**
```json
{
  "items": [
    {
      "userId": "uuid",
      "username": "string",
      "email": "string",
      "fullName": "string",
      "role": "string",
      "department": "string",
      "isActive": boolean,
      "lastLogin": "datetime",
      "createdAt": "datetime"
    }
  ],
  "total": integer,
  "page": integer,
  "pageSize": integer,
  "totalPages": integer
}
```

**Access:** TenantAdmin, ITTeam

---

#### POST /api/users
**Purpose:** Create new user

**Request:**
```json
{
  "username": "string",
  "email": "string",
  "password": "string",
  "employeeId": "uuid (optional)",
  "firstName": "string (required if no employeeId)",
  "lastName": "string (required if no employeeId)",
  "department": "string (required if no employeeId)",
  "role": "string"
}
```

**Business Rules:**
- Username must be unique
- Email must be unique
- Password must meet complexity requirements
- If employeeId provided, validate employee exists and is active
- If no employeeId, require first_name, last_name, department
- Set force_password_change = true
- Send welcome email with temporary password

**Access:** TenantAdmin, ITTeam

---

#### GET /api/users/{id}
**Purpose:** Get user details

**Response:**
```json
{
  "userId": "uuid",
  "username": "string",
  "email": "string",
  "role": "string",
  "isActive": boolean,
  "isLocked": boolean,
  "lastLogin": "datetime",
  "employeeDetails": {
    "employeeId": "uuid",
    "employeeCode": "string",
    "fullName": "string",
    "department": "string",
    "designation": "string",
    "manager": "string"
  },
  "createdAt": "datetime",
  "updatedAt": "datetime"
}
```

---

#### PUT /api/users/{id}
**Purpose:** Update user

**Request:**
```json
{
  "email": "string",
  "role": "string",
  "isActive": boolean
}
```

**Business Rules:**
- Cannot change username after creation
- Cannot change own role
- TenantAdmin cannot downgrade own role
- Log all changes in audit_logs

---

#### DELETE /api/users/{id}
**Purpose:** Soft delete user (set inactive)

**Business Rules:**
- Actually sets is_active = false (soft delete)
- Cannot delete own account
- Cannot delete last TenantAdmin
- Invalidate all user's sessions

---

#### POST /api/users/{id}/deactivate
**Purpose:** Deactivate user account

**Business Rules:**
- Set is_active = false
- Invalidate all sessions
- Send notification email

---

#### POST /api/users/{id}/reset-password
**Purpose:** Admin resets user password

**Response:**
```json
{
  "temporaryPassword": "string",
  "message": "Password reset email sent"
}
```

**Business Rules:**
- Generate temporary password
- Set force_password_change = true
- Clear failed login attempts
- Send email to user

---

#### GET /api/users/{id}/activity-log
**Purpose:** Get user's activity history

**Response:**
```json
{
  "items": [
    {
      "action": "string",
      "entityType": "string",
      "entityId": "uuid",
      "timestamp": "datetime",
      "ipAddress": "string"
    }
  ]
}
```

---

### Employee Management APIs

#### GET /api/employees
**Purpose:** List all employees

**Query Parameters:**
- `page`, `pageSize`: Pagination
- `department`: Filter by department
- `status`: Filter by status (Active/Inactive)
- `search`: Search by name, email, code

**Response:** Paginated list of employees

**Access:** All authenticated users

---

#### POST /api/employees
**Purpose:** Create new employee

**Request:**
```json
{
  "employeeCode": "string",
  "firstName": "string",
  "lastName": "string",
  "email": "string",
  "phone": "string",
  "department": "string",
  "designation": "string",
  "managerId": "uuid (optional)",
  "location": "string",
  "dateOfJoining": "date",
  "createUser": boolean,
  "userRole": "string (if createUser is true)"
}
```

**Business Rules:**
- Employee code must be unique
- Email must be unique
- If createUser = true, automatically create user account
- Validate manager exists if managerId provided

---

#### GET /api/employees/{id}
**Purpose:** Get employee details

---

#### PUT /api/employees/{id}
**Purpose:** Update employee

---

#### POST /api/employees/bulk-import
**Purpose:** Import employees from Excel/CSV

**Request:** Multipart form data with file

**Response:**
```json
{
  "totalRecords": integer,
  "successCount": integer,
  "errorCount": integer,
  "errors": [
    {
      "row": integer,
      "error": "string"
    }
  ]
}
```

**Business Rules:**
- Validate all rows before import
- Rollback on critical errors
- Skip and report individual row errors
- Maximum 1000 rows per import

---

#### GET /api/employees/export
**Purpose:** Export employees to Excel

**Query Parameters:** Same as GET /api/employees (for filtering)

**Response:** Excel file download

---

#### GET /api/employees/{id}/reporting-chain
**Purpose:** Get employee's hierarchical chain

**Response:**
```json
{
  "employee": { },
  "manager": { },
  "managersManager": { },
  "subordinates": [ ]
}
```

---

### Tenant Management APIs (Super Admin Only)

#### GET /api/admin/tenants
**Purpose:** List all tenants in the platform

**Access:** SuperAdmin only

---

#### POST /api/admin/tenants
**Purpose:** Create new tenant

**Request:**
```json
{
  "tenantName": "string",
  "subdomain": "string",
  "domain": "string (optional)",
  "adminEmail": "string",
  "adminFirstName": "string",
  "adminLastName": "string",
  "planType": "string",
  "userLimit": integer,
  "storageLimit": integer
}
```

**Business Rules:**
- Subdomain must be unique and valid (alphanumeric, lowercase)
- Create tenant database from template
- Create first admin user
- Send welcome email to admin
- Generate and send credentials

---

#### GET /api/admin/tenants/{id}
**Purpose:** Get tenant details with statistics

**Response:**
```json
{
  "tenant": { },
  "subscription": { },
  "statistics": {
    "totalUsers": integer,
    "totalAssets": integer,
    "storageUsed": integer,
    "lastActivity": "datetime"
  }
}
```

---

#### PUT /api/admin/tenants/{id}
**Purpose:** Update tenant

---

#### POST /api/admin/tenants/{id}/suspend
**Purpose:** Suspend tenant account

**Business Rules:**
- Set is_active = false
- Disable all user logins
- Send notification to tenant admin
- Keep data intact

---

#### POST /api/admin/tenants/{id}/activate
**Purpose:** Activate suspended tenant

---

#### GET /api/admin/tenants/{id}/stats
**Purpose:** Get detailed statistics

---

## Frontend Pages & Components

### Authentication Pages

#### 1. Login Page (`/login`)
**Components:**
- Login form with username/email and password
- "Remember me" checkbox
- "Forgot password" link
- Error message display
- Loading state
- Redirect to dashboard on success

**Validations:**
- Required fields
- Email format (if using email)

---

#### 2. Forgot Password Page (`/forgot-password`)
**Components:**
- Email input
- Submit button
- Success message
- Back to login link

---

#### 3. Reset Password Page (`/reset-password?token=...`)
**Components:**
- New password input
- Confirm password input
- Password strength indicator
- Submit button
- Requirements list

---

### User Management Pages

#### 1. User List Page (`/admin/users`)
**Components:**
- Data table with columns:
  - Name
  - Email
  - Role
  - Department
  - Status (badge)
  - Last Login
  - Actions (Edit, Deactivate, Reset Password)
- Filter panel:
  - Role dropdown
  - Status dropdown
  - Department dropdown
- Search bar (name, email, username)
- "Add User" button
- Pagination controls

**Features:**
- Sortable columns
- Export to Excel
- Bulk actions (future enhancement)

---

#### 2. User Form Page (`/admin/users/new` or `/admin/users/:id/edit`)
**Sections:**
- Basic Information
  - Username (disabled on edit)
  - Email
  - First Name (if no employee)
  - Last Name (if no employee)
- Account Settings
  - Role dropdown
  - Department (if no employee)
  - Employee selection (optional, searchable dropdown)
- Password (create only)
  - Password input
  - Generate password button
  - Requirements display

**Validations:**
- All required fields
- Email format
- Username format (alphanumeric, no spaces)
- Password complexity

---

#### 3. User Profile Page (`/profile`)
**Sections:**
- Personal Information (read-only)
  - Photo
  - Name
  - Email
  - Role
  - Department
  - Employee Code (if applicable)
- Change Password Form
  - Current password
  - New password
  - Confirm new password
- Recent Activity
  - Last 10 actions
  - Login history

---

### Employee Management Pages

#### 1. Employee List Page (`/employees`)
**Components:**
- Data table
- Advanced filters (department, status, location)
- Search functionality
- Quick view modal
- Export button
- Add employee button

---

#### 2. Employee Form Page (`/employees/new` or `/employees/:id/edit`)
**Sections:**
- Personal Information
- Contact Details
- Organizational Details
  - Department
  - Designation
  - Manager selection
  - Location
- Employment Details
  - Date of joining
  - Status
- System Access
  - Create user account checkbox
  - Role selection (if creating user)

---

#### 3. Bulk Import Page (`/employees/import`)
**Components:**
- Download template button
- File upload area (drag & drop)
- Upload button
- Progress bar
- Validation results table
- Error report download
- Success message

**Template Columns:**
- Employee Code*
- First Name*
- Last Name*
- Email*
- Phone
- Department*
- Designation
- Manager Email
- Location
- Date of Joining

---

### Dashboard Pages

#### 1. Dashboard Home (`/dashboard`)
**Widgets:**
- Welcome card
  - User name
  - Role
  - Last login
- Quick Stats (placeholders)
  - Total Assets
  - My Assigned Assets
  - Pending Actions
  - Active Maintenance
- Quick Links
  - Add Asset
  - View My Assets
  - Request Transfer
  - View Reports
- Recent Activity Feed
  - Last 10 system activities
  - Timestamp
  - User
  - Action

---

### Shared Components

#### 1. Header Component
**Elements:**
- Tenant logo (left)
- Application name
- Search bar (global)
- Notifications icon (future)
- User dropdown menu:
  - My Profile
  - Change Password
  - Help
  - Logout

---

#### 2. Sidebar Navigation
**Menu Structure:**
```
Dashboard
Assets
  - View Assets
  - Add Asset
  - Categories
  - Vendors
Employees
  - View Employees
  - Add Employee
  - Import Employees
Operations
  - Assignments
  - Transfers
  - Maintenance
Reports
Admin
  - User Management
  - Tenant Settings
  - Audit Logs
  - System Settings
```

**Features:**
- Collapsible sidebar
- Active route highlighting
- Role-based menu visibility
- Responsive (drawer on mobile)

---

#### 3. Data Table Component (Reusable)
**Features:**
- Column sorting
- Pagination
- Row selection
- Actions column
- Loading state
- Empty state
- Error state
- Export functionality

**Props:**
- columns: array
- data: array
- loading: boolean
- totalRecords: integer
- onPageChange: function
- onSort: function

---

#### 4. Form Components
**Standard form elements:**
- Text Input
- Email Input
- Password Input (with show/hide)
- Select Dropdown
- Multi-select
- Date Picker
- Textarea
- Checkbox
- Radio buttons
- File Upload

**Each component should include:**
- Label
- Validation message
- Help text
- Required indicator
- Disabled state
- Error state

---

#### 5. Modal/Dialog Component
**Types:**
- Confirmation dialog
- Form modal
- Info modal
- Full screen modal

**Features:**
- Header with close button
- Body content
- Footer with action buttons
- Overlay backdrop
- Close on escape key
- Close on backdrop click (optional)

---

#### 6. Toast Notification Service
**Types:**
- Success
- Error
- Warning
- Info

**Features:**
- Auto dismiss (configurable timeout)
- Manual close
- Position (top-right default)
- Multiple notifications stack
- Action button (optional)

---

## Technical Requirements

### Backend Infrastructure

#### 1. Tenant Resolution Middleware
**Functionality:**
- Detect tenant from subdomain or custom header
- Load tenant configuration
- Set tenant context for the request
- Reject requests with invalid tenant
- Handle www prefix appropriately

**Priority Order:**
1. Custom header: X-Tenant-Id (for API clients)
2. Subdomain extraction
3. Default tenant (for development)

---

#### 2. Authentication Middleware
**Functionality:**
- Validate JWT token
- Extract user claims
- Check token expiry
- Validate session is active
- Check user is not locked
- Update last activity timestamp

---

#### 3. Authorization Middleware
**Functionality:**
- Check user has required role
- Check user has permission for resource
- Handle role hierarchy
- Return 403 if unauthorized

---

#### 4. Exception Handling Middleware
**Functionality:**
- Catch all unhandled exceptions
- Log error details
- Return standardized error response
- Hide internal details in production
- Include request ID for tracking

**Error Response Format:**
```json
{
  "error": {
    "code": "string",
    "message": "string",
    "details": "string (dev only)",
    "requestId": "string",
    "timestamp": "datetime"
  }
}
```

---

#### 5. Database Context Management
**Requirements:**
- Shared AuthContext for tenant and auth tables
- Dynamic TenantContext per request
- Connection string templating
- Connection pooling
- Transaction management
- Tenant isolation enforcement

---

#### 6. Background Job Infrastructure (Hangfire)
**Setup Requirements:**
- Install Hangfire packages
- Configure PostgreSQL storage
- Set up Hangfire dashboard
- Implement authorization for dashboard
- Configure job retry policies

**Initial Jobs:**
- Session cleanup (hourly)
- Token cleanup (daily)
- Database backup (daily)
- Log archival (weekly)

**Dashboard URL:** /hangfire (admin only)

---

#### 7. Session Timeout Manager
**Requirements:**
- Middleware to check session activity
- Auto-logout after 30 minutes inactivity
- Update last_activity on each request
- Clear expired sessions periodically
- Send 401 when session expired

---

### Security Implementation

#### 1. Password Policy
**Requirements:**
- Minimum 8 characters
- At least 1 uppercase letter
- At least 1 lowercase letter
- At least 1 number
- At least 1 special character
- Cannot be same as username
- Cannot be same as last 3 passwords (future)

**Password Hashing:**
- Algorithm: BCrypt
- Cost factor: 12
- Salt: Auto-generated per password

---

#### 2. Account Lockout
**Rules:**
- Lock after 5 consecutive failed attempts
- Lockout duration: 30 minutes
- Reset counter on successful login
- Admin can unlock manually
- Send email notification on lockout

---

#### 3. JWT Token Configuration
**Settings:**
```
Secret: 256-bit key (environment variable)
Issuer: https://api.assetica.io
Audience: https://assetica.io
Access Token Expiry: 60 minutes
Refresh Token Expiry: 7 days
Algorithm: HS256
```

**Claims to Include:**
- userId
- username
- email
- role
- tenantId
- iat (issued at)
- exp (expiry)

---

#### 4. CORS Configuration
**Requirements:**
- Allow specific origins only
- Credentials: true
- Allow headers: Authorization, Content-Type, X-Tenant-Id
- Allow methods: GET, POST, PUT, DELETE
- Max age: 3600

---

#### 5. Rate Limiting
**Limits:**
- Login endpoint: 5 attempts per 15 minutes per IP
- Password reset: 3 attempts per hour per email
- API endpoints: 100 requests per minute per user
- Bulk import: 5 uploads per hour per tenant

---

### Frontend Infrastructure

#### 1. HTTP Interceptors

**Tenant Interceptor:**
- Add X-Tenant-Id header to all requests
- Extract tenant from URL

**Auth Interceptor:**
- Add Authorization header
- Attach JWT token
- Handle token refresh on 401
- Logout on refresh failure

**Error Interceptor:**
- Handle HTTP errors globally
- Show toast notifications
- Log errors
- Redirect on specific error codes

---

#### 2. Guards

**Auth Guard:**
- Check if user is authenticated
- Redirect to login if not
- Store return URL

**Role Guard:**
- Check if user has required role
- Redirect to access denied page
- Check against route data

---

#### 3. Services

**AuthService:**
- login()
- logout()
- refreshToken()
- getCurrentUser()
- isAuthenticated()
- hasRole(role)

**TenantService:**
- getCurrentTenant()
- getTenantSettings()

**UserService:**
- getUsers()
- createUser()
- updateUser()
- deleteUser()
- resetPassword()

**EmployeeService:**
- getEmployees()
- createEmployee()
- updateEmployee()
- bulkImport()
- exportEmployees()

**StorageService:**
- setItem()
- getItem()
- removeItem()
- clear()

---

#### 4. State Management
**Requirements:**
- Current user state
- Tenant configuration state
- Loading states
- Error states
- Form validation states

**Consider using:**
- NgRx (for complex state)
- BehaviorSubject (for simple state)
- Local component state

---

## Configuration Files

### Backend Configuration

#### appsettings.json
```json
{
  "ConnectionStrings": {
    "AuthDatabase": "Host=localhost;Database=assetica_auth;Username=postgres;Password=***",
    "TenantDatabaseTemplate": "Host=localhost;Database=assetica_tenant_{0};Username=postgres;Password=***",
    "HangfireConnection": "Host=localhost;Database=assetica_hangfire;Username=postgres;Password=***"
  },
  "JwtSettings": {
    "Secret": "*** (minimum 32 characters) ***",
    "Issuer": "https://api.assetica.io",
    "Audience": "https://assetica.io",
    "ExpiryMinutes": 60,
    "RefreshTokenExpiryDays": 7
  },
  "TenantSettings": {
    "IdentificationMode": "Subdomain",
    "DefaultTenant": "demo"
  },
  "SessionSettings": {
    "InactivityTimeoutMinutes": 30,
    "MaxConcurrentSessions": 3
  },
  "PasswordPolicy": {
    "MinLength": 8,
    "RequireUppercase": true,
    "RequireLowercase": true,
    "RequireDigit": true,
    "RequireSpecialChar": true
  },
  "RateLimiting": {
    "LoginAttemptsPerWindow": 5,
    "LoginWindowMinutes": 15
  }
}
```

---

### Frontend Configuration

#### environment.ts (Development)
```typescript
export const environment = {
  production: false,
  apiUrl: 'https://localhost:5001/api',
  tenantMode: 'subdomain',
  sessionTimeout: 30 * 60 * 1000, // 30 minutes in milliseconds
  tokenRefreshThreshold: 5 * 60 * 1000 // 5 minutes
};
```

#### environment.prod.ts (Production)
```typescript
export const environment = {
  production: true,
  apiUrl: 'https://api.assetica.io/api',
  tenantMode: 'subdomain',
  sessionTimeout: 30 * 60 * 1000,
  tokenRefreshThreshold: 5 * 60 * 1000
};
```

---

## Testing Requirements

### Unit Tests

**Backend:**
- [ ] User registration with all validations
- [ ] Login with correct credentials
- [ ] Login with incorrect credentials (account lockout)
- [ ] Password hashing and verification
- [ ] JWT token generation and validation
- [ ] Refresh token flow
- [ ] Tenant resolution from subdomain
- [ ] Tenant resolution from header
- [ ] RBAC permission checks
- [ ] Session timeout logic
- [ ] Password policy validation

**Frontend:**
- [ ] Login form validation
- [ ] Authentication guard
- [ ] Role guard
- [ ] Token refresh interceptor
- [ ] Error handling interceptor

---

### Integration Tests

- [ ] Complete login flow (UI to API)
- [ ] User CRUD operations
- [ ] Employee CRUD operations
- [ ] Tenant isolation verification
- [ ] Password reset flow
- [ ] Session timeout and logout
- [ ] Role-based access control

---

### Manual Testing Checklist

**Tenant Management:**
- [ ] Super Admin can create tenant
- [ ] Tenant database created correctly
- [ ] Tenant admin user created
- [ ] Subdomain routing works

**User Management:**
- [ ] Tenant Admin can create users
- [ ] Users can login
- [ ] Users see appropriate menus based on role
- [ ] User cannot access other tenant's data
- [ ] Account locks after 5 failed attempts
- [ ] Password reset flow works
- [ ] Force password change on first login works

**Employee Management:**
- [ ] Create employee
- [ ] Link employee to user
- [ ] Create employee without user
- [ ] Bulk import works with valid data
- [ ] Bulk import rejects invalid data
- [ ] Export to Excel works

**Session Management:**
- [ ] Session expires after 30 minutes inactivity
- [ ] Token refresh works
- [ ] Auto-logout on session expiry
- [ ] Multiple sessions handled correctly

**Security:**
- [ ] Password complexity enforced
- [ ] Cannot access APIs without token
- [ ] Cannot access resources without proper role
- [ ] SQL injection attempts blocked
- [ ] XSS attempts blocked

---

## Phase 1 Acceptance Criteria

### Database
- [ ] Shared authentication database created
- [ ] Tenant database template created
- [ ] All Phase 1 tables created with proper constraints
- [ ] Indexes created on key columns
- [ ] Sample tenant created for testing
- [ ] Sample users created for all roles

### Backend
- [ ] All authentication endpoints working
- [ ] All user management endpoints working
- [ ] All employee management endpoints working
- [ ] Tenant management endpoints working (Super Admin)
- [ ] JWT authentication implemented
- [ ] Refresh token flow working
- [ ] Tenant middleware functional
- [ ] Auth middleware functional
- [ ] Audit logging capturing all actions
- [ ] Hangfire setup and dashboard accessible
- [ ] Session timeout working
- [ ] API documentation (Swagger) complete

### Frontend
- [ ] Login page functional
- [ ] Forgot password flow working
- [ ] User management pages complete
- [ ] Employee management pages complete
- [ ] Dashboard framework ready
- [ ] Navigation working
- [ ] Responsive design (desktop and tablet)
- [ ] Loading states implemented
- [ ] Error handling implemented
- [ ] Toast notifications working

### Security
- [ ] Password complexity enforced
- [ ] Account lockout working
- [ ] Tenant data isolation verified
- [ ] CORS configured correctly
- [ ] Rate limiting functional
- [ ] No sensitive data in logs

### Deployment
- [ ] Backend deployed to development server
- [ ] Frontend deployed to development server
- [ ] Database migrations working
- [ ] Environment configurations set up
- [ ] Hangfire dashboard accessible
- [ ] Health check endpoint working

---

## Next Phase Preview

**Phase 2** will implement:
- Asset registration and management
- Asset categories with custom fields
- QR code generation
- Vendor management
- File upload and storage
- Basic asset search and listing

**Dependencies from Phase 1:**
- User authentication ✓
- Employee master data ✓
- Dashboard framework ✓
- Tenant context ✓
- Audit logging ✓
- Background jobs infrastructure ✓

---

## Critical Notes for Implementation

### Database Connection Strategy
1. **Shared DB Connection:** Used for tenant discovery and authentication
2. **Tenant DB Connection:** Dynamically selected based on resolved tenant
3. **Connection Pooling:** Required for performance
4. **Failover:** Implement connection retry logic

### Tenant Isolation
**Critical:** Every query in tenant database must:
- Use tenant context automatically
- Never leak data across tenants
- Validate tenant access on every request

### Password Security
- **Never** store plain text passwords
- **Never** send passwords in responses
- **Always** use BCrypt with cost factor 12+
- **Always** enforce complexity rules

### Token Security
- Store tokens as hashed values in database
- Never log tokens
- Implement token revocation
- Rotate secrets periodically

---

**End of Phase 1 Documentation**

**IMPLEMENTATION CHECKLIST:**
- ✅ Set up multi-tenant database architecture
- ✅ Implement authentication with JWT
- ✅ Build user management module
- ✅ Build employee management module
- ✅ Create dashboard framework
- ✅ Set up Hangfire for background jobs
- ✅ Implement session timeout management
- ✅ Test tenant isolation thoroughly
- ✅ Deploy to development environment

**READY TO PROCEED TO PHASE 2:** Only after all acceptance criteria are met.
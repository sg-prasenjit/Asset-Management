# PHASE 4: Financial Management & Maintenance
## Assetica Implementation Guide

**Duration:** 4-5 weeks  
**Prerequisites:** Phase 1, 2 & 3 Complete  
**Team:** 2 Backend + 2 Frontend + 1 QA  
**Priority:** Financial Tracking & Compliance

---

## Overview

Implement financial tracking, depreciation calculation, software license management, maintenance management, and budget monitoring. This phase adds critical financial oversight and operational capabilities for enterprise asset management.

---

## Deliverables

- ✅ Automated monthly depreciation calculation (SLM & WDV)
- ✅ Software license tracking and allocation
- ✅ Maintenance request and tracking system
- ✅ Warranty and AMC contract management with asset linking
- ✅ Budget tracking with automatic updates and alerts
- ✅ Asset disposal workflow with dual approval
- ✅ Financial reports and dashboards
- ✅ License assignment with concurrency control
- ✅ Budget triggers for INSERT/UPDATE/DELETE operations

---

## Database Schema

### Table: depreciation_schedules
```sql
CREATE TABLE depreciation_schedules (
    schedule_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    asset_id UUID REFERENCES assets(asset_id) NOT NULL UNIQUE,
    calculation_method VARCHAR(20) NOT NULL,
    depreciation_rate DECIMAL(5,2) NOT NULL,
    useful_life_years INTEGER NOT NULL,
    purchase_cost DECIMAL(15,2) NOT NULL,
    salvage_value DECIMAL(15,2) DEFAULT 0,
    start_date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES users(user_id)
);

CREATE INDEX idx_depreciation_schedule_asset ON depreciation_schedules(asset_id);
CREATE INDEX idx_depreciation_schedule_method ON depreciation_schedules(calculation_method);
```

**Calculation Methods:**
- SLM: Straight Line Method - Linear depreciation over useful life
- WDV: Written Down Value - Reducing balance method
- NA: No depreciation (software licenses, land)

**Auto-Creation:** When asset is created in Phase 2, depreciation schedule must be automatically created if category has depreciation settings.

**SLM Formula:**
```
Annual Depreciation = (Purchase Cost - Salvage Value) / Useful Life Years
Monthly Depreciation = Annual Depreciation / 12
```

**WDV Formula:**
```
Annual Depreciation = Opening Value × (Rate / 100)
Monthly Depreciation = Opening Value × (Rate / 100 / 12)
```

---

### Table: depreciation_entries
```sql
CREATE TABLE depreciation_entries (
    entry_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    asset_id UUID REFERENCES assets(asset_id) NOT NULL,
    schedule_id UUID REFERENCES depreciation_schedules(schedule_id),
    entry_date DATE NOT NULL,
    opening_value DECIMAL(15,2) NOT NULL,
    depreciation_amount DECIMAL(15,2) NOT NULL,
    closing_value DECIMAL(15,2) NOT NULL,
    accumulated_depreciation DECIMAL(15,2) NOT NULL,
    entry_type VARCHAR(30) DEFAULT 'Monthly',
    is_manual BOOLEAN DEFAULT false,
    remarks TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES users(user_id),
    UNIQUE(asset_id, entry_date, entry_type)
);

CREATE INDEX idx_depreciation_asset ON depreciation_entries(asset_id);
CREATE INDEX idx_depreciation_date ON depreciation_entries(entry_date DESC);
CREATE INDEX idx_depreciation_created ON depreciation_entries(created_at DESC);
```

**Entry Types:**
- Monthly: Automated monthly calculation
- Annual: Year-end calculation
- Manual: Manual adjustment by Finance

**Business Rules:**
- One entry per asset per month
- Cannot create future depreciation entries
- Closing value cannot go below salvage value
- Accumulated depreciation = sum of all depreciation amounts
- Manual entries require Finance role
- Auto-entries created by background job on 1st of each month

---

### Table: software_licenses
```sql
CREATE TABLE software_licenses (
    license_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    software_name VARCHAR(200) NOT NULL,
    software_version VARCHAR(50),
    license_key VARCHAR(500),
    license_type VARCHAR(30) NOT NULL,
    vendor_id UUID REFERENCES vendors(vendor_id),
    
    -- Quantity Management
    total_licenses INTEGER NOT NULL CHECK (total_licenses > 0),
    assigned_licenses INTEGER DEFAULT 0 CHECK (assigned_licenses >= 0),
    available_licenses INTEGER GENERATED ALWAYS AS (total_licenses - assigned_licenses) STORED,
    
    -- Financial
    cost_per_license DECIMAL(10,2) NOT NULL,
    total_cost DECIMAL(15,2) GENERATED ALWAYS AS (total_licenses * cost_per_license) STORED,
    purchase_date DATE NOT NULL,
    
    -- Subscription Details (if subscription type)
    billing_frequency VARCHAR(20),
    renewal_date DATE,
    auto_renewal BOOLEAN DEFAULT false,
    next_billing_amount DECIMAL(10,2),
    
    -- Support Details
    support_expiry_date DATE,
    support_contact_email VARCHAR(200),
    support_phone VARCHAR(20),
    
    -- Metadata
    description TEXT,
    notes TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES users(user_id),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_licenses_software ON software_licenses(software_name);
CREATE INDEX idx_licenses_type ON software_licenses(license_type);
CREATE INDEX idx_licenses_renewal ON software_licenses(renewal_date) WHERE renewal_date IS NOT NULL;
CREATE INDEX idx_licenses_vendor ON software_licenses(vendor_id);
CREATE INDEX idx_licenses_active ON software_licenses(is_active);

-- Constraint to prevent over-assignment
ALTER TABLE software_licenses ADD CONSTRAINT chk_assignment_limit 
CHECK (assigned_licenses <= total_licenses);
```

**Valid License Types:**
- Perpetual: One-time purchase, no renewal
- Subscription: Recurring billing (monthly/annual)
- Trial: Limited time trial license
- Concurrent: Floating licenses (concurrent user limit)
- Named: Assigned to specific users

**Valid Billing Frequency:**
- Monthly
- Quarterly
- Annual
- Biennial

**Assignment Tracking:**
- `total_licenses`: Total purchased
- `assigned_licenses`: Currently assigned (auto-updated)
- `available_licenses`: Computed field (total - assigned)

**Concurrency Control:** Use row-level locking when assigning licenses to prevent over-assignment.

---

### Table: license_assignments
```sql
CREATE TABLE license_assignments (
    assignment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    license_id UUID REFERENCES software_licenses(license_id) NOT NULL,
    assigned_to_type VARCHAR(20) NOT NULL,
    assigned_to_user_id UUID REFERENCES users(user_id),
    assigned_to_asset_id UUID REFERENCES assets(asset_id),
    assigned_date DATE NOT NULL,
    expiry_date DATE,
    license_key_assigned VARCHAR(500),
    status VARCHAR(20) DEFAULT 'Active',
    notes TEXT,
    assigned_by UUID REFERENCES users(user_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CHECK (
        (assigned_to_type = 'User' AND assigned_to_user_id IS NOT NULL) OR
        (assigned_to_type = 'Asset' AND assigned_to_asset_id IS NOT NULL)
    )
);

CREATE INDEX idx_license_assign_license ON license_assignments(license_id);
CREATE INDEX idx_license_assign_user ON license_assignments(assigned_to_user_id);
CREATE INDEX idx_license_assign_asset ON license_assignments(assigned_to_asset_id);
CREATE INDEX idx_license_assign_status ON license_assignments(status);
```

**Valid Assignment Types:**
- User: License assigned to specific user
- Asset: License installed on specific device

**Valid Status:**
- Active: Currently in use
- Revoked: License reclaimed
- Expired: Assignment expired

**Business Rules:**
- Cannot assign more licenses than available
- Use row-level locking on software_licenses when assigning
- Auto-increment assigned_licenses on assignment
- Auto-decrement assigned_licenses on revocation
- For subscription licenses, expiry_date = renewal_date
- Cannot revoke if not assigned

---

### Table: maintenance_requests
```sql
CREATE TABLE maintenance_requests (
    request_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_number VARCHAR(50) UNIQUE NOT NULL,
    asset_id UUID REFERENCES assets(asset_id) NOT NULL,
    reported_by UUID REFERENCES users(user_id) NOT NULL,
    reported_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Issue Details
    issue_type VARCHAR(50) NOT NULL,
    issue_description TEXT NOT NULL,
    severity VARCHAR(20) NOT NULL,
    
    -- Assignment
    assigned_to UUID REFERENCES users(user_id),
    assigned_at TIMESTAMP,
    
    -- Status
    status VARCHAR(30) DEFAULT 'Open',
    priority VARCHAR(20) DEFAULT 'Medium',
    
    -- Resolution
    resolution_notes TEXT,
    resolved_at TIMESTAMP,
    resolved_by UUID REFERENCES users(user_id),
    
    -- Additional
    attachments JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_maint_req_asset ON maintenance_requests(asset_id);
CREATE INDEX idx_maint_req_status ON maintenance_requests(status);
CREATE INDEX idx_maint_req_reported_by ON maintenance_requests(reported_by);
CREATE INDEX idx_maint_req_assigned_to ON maintenance_requests(assigned_to);
CREATE INDEX idx_maint_req_severity ON maintenance_requests(severity);
CREATE INDEX idx_maint_req_ticket ON maintenance_requests(ticket_number);
```

**Ticket Number Format:** MR-{YEAR}-{####} (e.g., MR-2025-0001)

**Valid Issue Types:**
- Hardware Failure
- Software Issue
- Performance Issue
- Physical Damage
- Connectivity Issue
- Preventive Maintenance
- Other

**Valid Severity:**
- Critical: System down, work blocked
- High: Major functionality impaired
- Medium: Some functionality impaired
- Low: Minor issue, workaround available

**Valid Status:**
- Open: Newly reported
- Acknowledged: IT team acknowledged
- InProgress: Being worked on
- Waiting: Waiting for parts/vendor
- Resolved: Issue fixed
- Closed: Confirmed resolved
- Cancelled: Request cancelled

**Valid Priority:**
- Urgent: Must fix immediately
- High: Fix within 24 hours
- Medium: Fix within 3 days
- Low: Fix when convenient

---

### Table: maintenance_logs
```sql
CREATE TABLE maintenance_logs (
    log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    asset_id UUID REFERENCES assets(asset_id) NOT NULL,
    request_id UUID REFERENCES maintenance_requests(request_id),
    maintenance_type VARCHAR(50) NOT NULL,
    service_provider VARCHAR(200),
    service_provider_type VARCHAR(20),
    
    -- Scheduling
    start_date DATE NOT NULL,
    completion_date DATE,
    expected_completion_date DATE,
    
    -- Cost
    estimated_cost DECIMAL(10,2),
    actual_cost DECIMAL(10,2),
    covered_under_warranty BOOLEAN DEFAULT false,
    covered_under_amc BOOLEAN DEFAULT false,
    amc_contract_id UUID REFERENCES amc_contracts(contract_id),
    
    -- Details
    work_description TEXT,
    parts_replaced TEXT,
    technician_name VARCHAR(100),
    
    -- Status
    status VARCHAR(30) DEFAULT 'Scheduled',
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES users(user_id)
);

CREATE INDEX idx_maint_log_asset ON maintenance_logs(asset_id);
CREATE INDEX idx_maint_log_request ON maintenance_logs(request_id);
CREATE INDEX idx_maint_log_dates ON maintenance_logs(start_date, completion_date);
CREATE INDEX idx_maint_log_status ON maintenance_logs(status);
CREATE INDEX idx_maint_log_amc ON maintenance_logs(amc_contract_id);
```

**Valid Maintenance Types:**
- Repair: Fix broken item
- Preventive: Scheduled maintenance
- Upgrade: Hardware/software upgrade
- Replacement: Part replacement
- Calibration: Equipment calibration
- Inspection: Regular inspection

**Valid Service Provider Types:**
- Internal: IT team
- Vendor: Original vendor/manufacturer
- ThirdParty: External service provider
- AMC: Under AMC contract

**Valid Status:**
- Scheduled: Scheduled for future date
- InProgress: Work in progress
- Completed: Work completed
- Cancelled: Maintenance cancelled

**Business Rules:**
- If covered_under_warranty = true, actual_cost should be minimal (shipping/handling only)
- If covered_under_amc = true, link to AMC contract
- Update asset status to 'Under Maintenance' when maintenance starts
- Update asset status back to 'Available' or 'Active' when completed

---

### Table: amc_contracts
```sql
CREATE TABLE amc_contracts (
    contract_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contract_number VARCHAR(50) UNIQUE NOT NULL,
    vendor_id UUID REFERENCES vendors(vendor_id) NOT NULL,
    contract_name VARCHAR(200) NOT NULL,
    
    -- Contract Period
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    
    -- Financial
    contract_value DECIMAL(15,2) NOT NULL,
    payment_frequency VARCHAR(20),
    billing_cycle VARCHAR(20),
    
    -- Coverage Details
    coverage_type VARCHAR(50),
    response_time_hours INTEGER,
    resolution_time_hours INTEGER,
    
    -- Terms
    terms_and_conditions TEXT,
    inclusions TEXT,
    exclusions TEXT,
    
    -- Status
    status VARCHAR(20) DEFAULT 'Active',
    auto_renewal BOOLEAN DEFAULT false,
    
    -- Contacts
    vendor_contact_person VARCHAR(100),
    vendor_contact_email VARCHAR(200),
    vendor_contact_phone VARCHAR(20),
    
    -- Metadata
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES users(user_id),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_amc_vendor ON amc_contracts(vendor_id);
CREATE INDEX idx_amc_dates ON amc_contracts(start_date, end_date);
CREATE INDEX idx_amc_status ON amc_contracts(status);
CREATE INDEX idx_amc_number ON amc_contracts(contract_number);
```

**Contract Number Format:** AMC-{YEAR}-{####}

**Valid Coverage Types:**
- Comprehensive: All repairs covered
- Preventive: Only preventive maintenance
- OnCall: Pay per service call
- Parts: Parts only, labor separate

**Valid Payment Frequency:**
- Monthly
- Quarterly  
- HalfYearly
- Annual
- OneTime

**Valid Status:**
- Active: Currently active
- Expired: Contract period ended
- Terminated: Terminated before end date
- Renewed: Renewed (old contract)

---

### Table: amc_contract_assets
```sql
CREATE TABLE amc_contract_assets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    amc_contract_id UUID REFERENCES amc_contracts(contract_id) ON DELETE CASCADE,
    asset_id UUID REFERENCES assets(asset_id) ON DELETE CASCADE,
    coverage_start_date DATE NOT NULL,
    coverage_end_date DATE,
    is_active BOOLEAN DEFAULT true,
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    added_by UUID REFERENCES users(user_id),
    removed_at TIMESTAMP,
    removed_by UUID REFERENCES users(user_id),
    UNIQUE(amc_contract_id, asset_id)
);

CREATE INDEX idx_amc_assets_contract ON amc_contract_assets(amc_contract_id);
CREATE INDEX idx_amc_assets_asset ON amc_contract_assets(asset_id);
CREATE INDEX idx_amc_assets_active ON amc_contract_assets(is_active);
```

**Purpose:** Links assets to AMC contracts (many-to-many relationship)

**Business Rules:**
- Assets can be added/removed during contract period
- Coverage dates can differ from contract dates
- When asset added, coverage_start_date = date added (or future date)
- When asset removed, set is_active = false, record removed_at
- Cannot add same asset to multiple active AMC contracts

---

### Table: budgets
```sql
CREATE TABLE budgets (
    budget_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fiscal_year INTEGER NOT NULL,
    department VARCHAR(100) NOT NULL,
    category_id UUID REFERENCES asset_categories(category_id),
    allocated_amount DECIMAL(15,2) NOT NULL CHECK (allocated_amount >= 0),
    spent_amount DECIMAL(15,2) DEFAULT 0 CHECK (spent_amount >= 0),
    available_amount DECIMAL(15,2) GENERATED ALWAYS AS (allocated_amount - spent_amount) STORED,
    utilization_percentage DECIMAL(5,2) GENERATED ALWAYS AS (
        CASE WHEN allocated_amount > 0 
        THEN (spent_amount / allocated_amount * 100) 
        ELSE 0 
        END
    ) STORED,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES users(user_id),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(fiscal_year, department, category_id)
);

CREATE INDEX idx_budgets_fiscal_year ON budgets(fiscal_year);
CREATE INDEX idx_budgets_department ON budgets(department);
CREATE INDEX idx_budgets_category ON budgets(category_id);
CREATE INDEX idx_budgets_active ON budgets(is_active);
CREATE INDEX idx_budgets_utilization ON budgets(utilization_percentage);
```

**Budget Hierarchy:**
- Department-wide budget: category_id = NULL
- Category-specific budget: category_id = specific category

**Business Rules:**
- Spent amount auto-updated via trigger on asset INSERT/UPDATE/DELETE
- Alert when utilization > 80%
- Cannot spend if no budget or budget exceeded (soft limit with warning)
- Fiscal year typically April to March (configurable)

---

### Budget Update Triggers
```sql
-- Function to update budget on asset changes
CREATE OR REPLACE FUNCTION update_budget_on_asset_change()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- New asset purchased - add to budget
        UPDATE budgets
        SET spent_amount = spent_amount + NEW.purchase_cost,
            updated_at = CURRENT_TIMESTAMP
        WHERE fiscal_year = EXTRACT(YEAR FROM NEW.purchase_date)
          AND department = NEW.department
          AND (category_id = NEW.category_id OR category_id IS NULL)
          AND is_active = true;
        
    ELSIF TG_OP = 'UPDATE' THEN
        -- Asset cost or department changed
        IF NEW.purchase_cost != OLD.purchase_cost OR NEW.department != OLD.department THEN
            -- Remove from old budget
            UPDATE budgets
            SET spent_amount = spent_amount - OLD.purchase_cost,
                updated_at = CURRENT_TIMESTAMP
            WHERE fiscal_year = EXTRACT(YEAR FROM OLD.purchase_date)
              AND department = OLD.department
              AND (category_id = OLD.category_id OR category_id IS NULL)
              AND is_active = true;
            
            -- Add to new budget
            UPDATE budgets
            SET spent_amount = spent_amount + NEW.purchase_cost,
                updated_at = CURRENT_TIMESTAMP
            WHERE fiscal_year = EXTRACT(YEAR FROM NEW.purchase_date)
              AND department = NEW.department
              AND (category_id = NEW.category_id OR category_id IS NULL)
              AND is_active = true;
        END IF;
        
    ELSIF TG_OP = 'DELETE' THEN
        -- Asset deleted (not disposed) - adjust budget
        IF OLD.current_status != 'Disposed' THEN
            UPDATE budgets
            SET spent_amount = spent_amount - OLD.purchase_cost,
                updated_at = CURRENT_TIMESTAMP
            WHERE fiscal_year = EXTRACT(YEAR FROM OLD.purchase_date)
              AND department = OLD.department
              AND (category_id = OLD.category_id OR category_id IS NULL)
              AND is_active = true;
        END IF;
    END IF;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER budget_update_trigger
AFTER INSERT OR UPDATE OR DELETE ON assets
FOR EACH ROW EXECUTE FUNCTION update_budget_on_asset_change();
```

**Trigger Logic:**
- INSERT: Add asset cost to appropriate budget
- UPDATE: If cost/department changed, adjust old and new budgets
- DELETE: Subtract cost (only if not already disposed)
- Disposal handled separately (doesn't affect budget as already spent)

---

### Table: disposal_requests
```sql
CREATE TABLE disposal_requests (
    disposal_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    asset_id UUID REFERENCES assets(asset_id) NOT NULL,
    disposal_reason VARCHAR(100) NOT NULL,
    detailed_reason TEXT,
    
    -- Financial
    current_book_value DECIMAL(15,2),
    expected_disposal_value DECIMAL(15,2),
    actual_disposal_value DECIMAL(15,2),
    gain_loss DECIMAL(15,2),
    
    -- Method
    disposal_method VARCHAR(50),
    disposal_to VARCHAR(200),
    
    -- Workflow Status
    status VARCHAR(30) DEFAULT 'Pending',
    requested_by UUID REFERENCES users(user_id),
    requested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Finance Approval
    finance_approver_id UUID REFERENCES users(user_id),
    finance_approved_at TIMESTAMP,
    finance_status VARCHAR(30),
    finance_remarks TEXT,
    
    -- Admin Approval
    admin_approver_id UUID REFERENCES users(user_id),
    admin_approved_at TIMESTAMP,
    admin_status VARCHAR(30),
    admin_remarks TEXT,
    
    -- Execution
    disposal_date DATE,
    disposal_certificate_url VARCHAR(500),
    disposed_by UUID REFERENCES users(user_id),
    disposal_notes TEXT,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_disposal_asset ON disposal_requests(asset_id);
CREATE INDEX idx_disposal_status ON disposal_requests(status);
CREATE INDEX idx_disposal_finance_approver ON disposal_requests(finance_approver_id) WHERE finance_status IS NULL;
CREATE INDEX idx_disposal_admin_approver ON disposal_requests(admin_approver_id) WHERE admin_status IS NULL;
```

**Valid Disposal Reasons:**
- EndOfLife: Asset reached end of useful life
- DamagedBeyondRepair: Cannot be economically repaired
- Obsolete: Technology obsolete
- Upgraded: Replaced with newer model
- Lost: Asset lost/missing
- Stolen: Asset stolen

**Valid Disposal Methods:**
- Sale: Sold to buyer
- Donation: Donated to charity/school
- Scrap: Scrapped for metal/parts
- EWaste: Electronic waste disposal
- Trade-In: Traded for new equipment
- Destruction: Secure destruction

**Valid Status:**
- Pending: Awaiting approvals
- FinanceApproved: Finance approved, awaiting admin
- Approved: Both approvals obtained
- Rejected: Rejected by approver
- Completed: Disposal executed
- Cancelled: Request cancelled

**Approval Workflow:**
- Level 1: Finance approval (valuation check)
- Level 2: Admin/IT approval (technical check)
- Both approvals required before disposal

**Gain/Loss Calculation:**
```
Gain/Loss = Actual Disposal Value - Current Book Value
Positive = Gain
Negative = Loss
```

---

## API Endpoints

### Depreciation APIs

#### POST /api/depreciation/calculate-all
**Purpose:** Manually trigger depreciation calculation for all assets

**Business Rules:**
- Admin only
- Creates entries for current month
- Skips if entry already exists for asset/month
- Logs execution
- Returns summary (assets processed, entries created, errors)

**Response:**
```json
{
  "processedAssets": 150,
  "entriesCreated": 145,
  "skipped": 5,
  "errors": [],
  "executionTime": "2.3s"
}
```

---

#### POST /api/depreciation/calculate/{assetId}
**Purpose:** Calculate depreciation for specific asset

**Response:**
```json
{
  "assetCode": "string",
  "entryCreated": boolean,
  "depreciation": {
    "openingValue": number,
    "depreciationAmount": number,
    "closingValue": number,
    "accumulatedDepreciation": number
  }
}
```

---

#### GET /api/depreciation/schedule/{assetId}
**Purpose:** Get complete depreciation schedule for asset

**Response:**
```json
{
  "asset": { },
  "schedule": {
    "method": "string",
    "rate": number,
    "usefulLifeYears": number,
    "purchaseCost": number,
    "salvageValue": number,
    "startDate": "date"
  },
  "entries": [
    {
      "entryDate": "date",
      "openingValue": number,
      "depreciationAmount": number,
      "closingValue": number,
      "accumulatedDepreciation": number,
      "entryType": "string"
    }
  ],
  "projectedEntries": [
    // Future months projected
  ]
}
```

---

#### GET /api/depreciation/entries
**Purpose:** List depreciation entries with filters

**Query Parameters:**
- `startDate`, `endDate`: Date range
- `assetIds`: Filter by assets
- `categoryIds`: Filter by categories
- `departmentIds`: Filter by departments
- `entryType`: Filter by type

---

#### POST /api/depreciation/manual-entry
**Purpose:** Create manual depreciation entry (Finance role only)

**Request:**
```json
{
  "assetId": "uuid",
  "entryDate": "date",
  "depreciationAmount": number,
  "remarks": "string (required)"
}
```

**Business Rules:**
- Finance role only
- Cannot create for future dates
- Validates depreciation amount reasonable
- Requires approval if amount > $1000
- Logs as manual entry

---

#### GET /api/depreciation/report
**Purpose:** Generate depreciation report

**Query Parameters:**
- `reportType`: monthly | annual | cumulative
- `fiscalYear`: number
- `month`: number (for monthly)
- `categories`: array
- `departments`: array

**Response:** Report data for display or Excel export

---

### Software License APIs

#### GET /api/licenses
**Purpose:** List all software licenses

**Query Parameters:**
- `licenseType`: Filter by type
- `vendorId`: Filter by vendor
- `status`: Active/Inactive
- `expiringInDays`: number (renewal alert)
- `underutilized`: boolean (< 60% assigned)

---

#### POST /api/licenses
**Purpose:** Create new license

**Request:**
```json
{
  "softwareName": "string",
  "softwareVersion": "string",
  "licenseKey": "string",
  "licenseType": "string",
  "vendorId": "uuid",
  "totalLicenses": number,
  "costPerLicense": number,
  "purchaseDate": "date",
  "billingFrequency": "string (if subscription)",
  "renewalDate": "date (if subscription)",
  "autoRenewal": boolean,
  "supportExpiryDate": "date",
  "description": "string"
}
```

**Business Rules:**
- Validate total_licenses > 0
- If subscription, renewal_date required
- Calculate total_cost automatically
- Initialize assigned_licenses = 0

---

#### GET /api/licenses/{id}
**Purpose:** Get license details with assignments

**Response:**
```json
{
  "license": { },
  "assignments": {
    "users": [ ],
    "assets": [ ]
  },
  "utilizationPercentage": number,
  "renewalStatus": "string",
  "daysToRenewal": number
}
```

---

#### PUT /api/licenses/{id}
#### DELETE /api/licenses/{id}

---

#### POST /api/licenses/{id}/assign
**Purpose:** Assign license to user or asset

**Request:**
```json
{
  "assignToType": "User | Asset",
  "assignToId": "uuid (userId or assetId)",
  "expiryDate": "date (optional)",
  "licenseKeyAssigned": "string (if specific key)",
  "notes": "string"
}
```

**Business Rules:**
- Use row-level locking: `SELECT * FROM software_licenses WHERE license_id = ? FOR UPDATE`
- Check available_licenses > 0
- Increment assigned_licenses atomically
- Create assignment record
- If subscription with expiry, set expiry_date
- Commit transaction
- Rollback if any step fails

**Concurrency Control:**
```
1. Start transaction
2. Lock license row for update
3. Check available > 0
4. Create assignment
5. Update assigned_licenses
6. Commit
```

---

#### POST /api/licenses/{id}/revoke
**Purpose:** Revoke license assignment

**Request:**
```json
{
  "assignmentId": "uuid"
}
```

**Business Rules:**
- Use row-level locking
- Update assignment status = 'Revoked'
- Decrement assigned_licenses
- Validate assignment exists and is active

---

#### GET /api/licenses/expiring
**Purpose:** Get licenses expiring soon

**Query Parameters:**
- `days`: number (default: 30)

---

#### GET /api/licenses/underutilized
**Purpose:** Get underutilized licenses (<60% assigned)

---

### Maintenance APIs

#### GET /api/maintenance/requests
**Purpose:** List maintenance requests

**Query Parameters:**
- `status`: Filter by status
- `severity`: Filter by severity
- `assignedTo`: Filter by assigned person
- `assetId`: Filter by asset
- `startDate`, `endDate`: Date range

---

#### POST /api/maintenance/requests
**Purpose:** Create maintenance request

**Request:**
```json
{
  "assetId": "uuid",
  "issueType": "string",
  "issueDescription": "string",
  "severity": "string",
  "attachments": ["file uploads"]
}
```

**Business Rules:**
- Auto-generate ticket number: MR-{YEAR}-{####}
- Set status = 'Open'
- reported_by = current user
- Send email to IT team
- If severity = Critical, send SMS alert (future)
- Log in audit trail

---

#### GET /api/maintenance/requests/{id}
**Purpose:** Get request details

---

#### PUT /api/maintenance/requests/{id}/acknowledge
**Purpose:** IT acknowledges request

**Business Rules:**
- Update status = 'Acknowledged'
- Set assigned_to = current user
- Send email to reporter

---

#### PUT /api/maintenance/requests/{id}/assign
**Purpose:** Assign to team member

**Request:**
```json
{
  "assignTo": "uuid",
  "priority": "string"
}
```

---

#### POST /api/maintenance/requests/{id}/send-for-repair
**Purpose:** Send asset for maintenance/repair

**Request:**
```json
{
  "maintenanceType": "string",
  "serviceProvider": "string",
  "serviceProviderType": "string",
  "startDate": "date",
  "expectedCompletionDate": "date",
  "estimatedCost": number,
  "coveredUnderWarranty": boolean,
  "coveredUnderAMC": boolean,
  "amcContractId": "uuid (if AMC)",
  "workDescription": "string"
}
```

**Business Rules:**
- Update request status = 'InProgress'
- Create maintenance_log entry
- Update asset status = 'Under Maintenance'
- Send email notification
- If AMC, link to contract and update utilization

---

#### PUT /api/maintenance/requests/{id}/resolve
**Purpose:** Mark request as resolved

**Request:**
```json
{
  "resolutionNotes": "string",
  "actualCost": number (if applicable),
  "completionDate": "date"
}
```

**Business Rules:**
- Update request status = 'Resolved'
- Update maintenance_log with completion details
- Update asset status back to 'Available' or 'Active'
- Send email to reporter for confirmation
- Calculate downtime (start to completion)

---

#### PUT /api/maintenance/requests/{id}/close
**Purpose:** Close resolved request

**Business Rules:**
- Update status = 'Closed'
- Can only close if status = 'Resolved'
- Final closure after user confirmation

---

### AMC Contract APIs

#### GET /api/amc-contracts
**Purpose:** List all AMC contracts

**Query Parameters:**
- `status`: Active/Expired/Terminated
- `vendorId`: Filter by vendor
- `expiringInDays`: number

---

#### POST /api/amc-contracts
**Purpose:** Create new AMC contract

**Request:**
```json
{
  "vendorId": "uuid",
  "contractName": "string",
  "startDate": "date",
  "endDate": "date",
  "contractValue": number,
  "paymentFrequency": "string",
  "coverageType": "string",
  "responseTimeHours": number,
  "resolutionTimeHours": number,
  "termsAndConditions": "string",
  "inclusions": "string",
  "exclusions": "string",
  "vendorContactPerson": "string",
  "vendorContactEmail": "string",
  "vendorContactPhone": "string"
}
```

**Business Rules:**
- Auto-generate contract number: AMC-{YEAR}-{####}
- end_date must be after start_date
- Set status = 'Active'

---

#### GET /api/amc-contracts/{id}
**Purpose:** Get contract details with covered assets

**Response:**
```json
{
  "contract": { },
  "coveredAssets": [
    {
      "asset": { },
      "coverageStartDate": "date",
      "coverageEndDate": "date",
      "maintenanceCount": number,
      "lastMaintenanceDate": "date"
    }
  ],
  "utilization": {
    "totalMaintenances": number,
    "totalCostSaved": number,
    "averageResolutionTime": "string"
  }
}
```

---

#### PUT /api/amc-contracts/{id}
#### DELETE /api/amc-contracts/{id} (terminate)

---

#### POST /api/amc-contracts/{id}/add-asset
**Purpose:** Add asset to AMC coverage

**Request:**
```json
{
  "assetId": "uuid",
  "coverageStartDate": "date",
  "coverageEndDate": "date (optional)"
}
```

**Business Rules:**
- Validate asset not in another active AMC
- coverage_start_date within contract period
- If no coverage_end_date, use contract end_date
- Create junction record

---

#### POST /api/amc-contracts/{id}/remove-asset
**Purpose:** Remove asset from AMC coverage

**Request:**
```json
{
  "assetId": "uuid"
}
```

**Business Rules:**
- Set is_active = false
- Set removed_at = now
- removed_by = current user

---

### Budget Management APIs

#### GET /api/budgets
**Purpose:** List all budgets

**Query Parameters:**
- `fiscalYear`: number (required)
- `department`: string
- `overUtilized`: boolean (>100%)
- `alertZone`: boolean (>80%)

---

#### POST /api/budgets
**Purpose:** Create new budget

**Request:**
```json
{
  "fiscalYear": number,
  "department": "string",
  "categoryId": "uuid (optional for department-wide)",
  "allocatedAmount": number
}
```

**Business Rules:**
- Unique constraint: (fiscal_year, department, category_id)
- allocated_amount must be > 0
- If category_id NULL, department-wide budget

---

#### GET /api/budgets/{id}
#### PUT /api/budgets/{id}

---

#### GET /api/budgets/utilization
**Purpose:** Get budget utilization summary for dashboard

**Response:**
```json
{
  "fiscalYear": number,
  "totalAllocated": number,
  "totalSpent": number,
  "totalAvailable": number,
  "overallUtilization": number,
  "departmentSummary": [
    {
      "department": "string",
      "allocated": number,
      "spent": number,
      "utilization": number,
      "status": "OK | Warning | Critical"
    }
  ],
  "categorySummary": [ ]
}
```

**Status Thresholds:**
- OK: < 80%
- Warning: 80-100%
- Critical: > 100%

---

#### GET /api/budgets/alerts
**Purpose:** Get budgets requiring attention

**Response:**
```json
{
  "overUtilized": [ ],
  "nearing80Percent": [ ],
  "fullyUtilized": [ ]
}
```

---

### Asset Disposal APIs

#### POST /api/disposal/requests
**Purpose:** Request asset disposal

**Request:**
```json
{
  "assetId": "uuid",
  "disposalReason": "string",
  "detailedReason": "string",
  "expectedDisposalValue": number,
  "disposalMethod": "string"
}
```

**Business Rules:**
- Get current_book_value from asset
- Set status = 'Pending'
- Determine approvers (Finance + Admin)
- Send email to Finance approver
- Log request

---

#### GET /api/disposal/requests
**Purpose:** List disposal requests

**Query Parameters:**
- `status`: Filter by status
- `pendingApprovalBy`: uuid

---

#### GET /api/disposal/requests/{id}
**Purpose:** Get disposal request details

---

#### PUT /api/disposal/requests/{id}/approve
**Purpose:** Approve disposal (Finance or Admin)

**Request:**
```json
{
  "approverType": "Finance | Admin",
  "remarks": "string"
}
```

**Business Rules:**
- Validate user is designated approver
- If Finance approval: Update finance_status = 'Approved', send to Admin approver
- If Admin approval and Finance already approved: Update status = 'Approved', notify IT team
- If both approved: Ready for execution

---

#### PUT /api/disposal/requests/{id}/reject
**Purpose:** Reject disposal

**Request:**
```json
{
  "approverType": "Finance | Admin",
  "remarks": "string (required)"
}
```

---

#### POST /api/disposal/requests/{id}/execute
**Purpose:** Execute approved disposal

**Request:**
```json
{
  "disposalDate": "date",
  "actualDisposalValue": number,
  "disposalTo": "string (buyer/recipient)",
  "disposalCertificate": "file upload",
  "disposalNotes": "string"
}
```

**Business Rules:**
- Validate status = 'Approved'
- Calculate gain/loss: actual_value - book_value
- Update asset:
  - status = 'Disposed'
  - is_active = false
- Update disposal request: status = 'Completed'
- Send completion emails
- Generate disposal certificate PDF
- Log in audit trail

---

#### GET /api/disposal/certificate/{id}
**Purpose:** Generate disposal certificate PDF

**Certificate Contents:**
- Company header
- Asset details (code, name, serial, category)
- Disposal details (method, date, value)
- Approver signatures (digital)
- Disposal officer signature
- Certificate number
- QR code for verification

---

## Frontend Pages & Components

### Depreciation Management

#### 1. Asset Financial Tab (on asset detail page)
**Sections:**
- Purchase Information (read-only)
  - Purchase Cost
  - Purchase Date
  - Vendor
- Current Financial Status
  - Current Book Value (large, highlighted)
  - Accumulated Depreciation
  - Depreciation Rate & Method
  - Useful Life Remaining
- Depreciation Chart
  - Line chart showing book value over time
  - Actual (past) vs Projected (future)
  - X-axis: Months, Y-axis: Value

---

#### 2. Depreciation Schedule Page (`/assets/:id/depreciation`)
**Table:**
- Month/Year
- Opening Value
- Depreciation Amount
- Closing Value
- Accumulated Depreciation
- Entry Type (badge)

**Actions:**
- Export to Excel
- Add Manual Entry (Finance only)
- View Projection (future months)

---

#### 3. Depreciation Report Page (`/reports/depreciation`)
**Filters:**
- Report Type (Monthly/Annual/Cumulative)
- Fiscal Year
- Month (if monthly)
- Categories (multi-select)
- Departments (multi-select)

**Summary Cards:**
- Total Depreciation This Month
- Total Depreciation This Year
- Total Assets Depreciating
- Avg Depreciation Rate

**Depreciation Table:**
- Asset Code
- Asset Name
- Category
- Department
- Purchase Cost
- Book Value
- Monthly Depreciation
- YTD Depreciation

**Chart:**
- Monthly depreciation trend (bar chart)

**Actions:**
- Export to Excel
- Export to PDF
- Schedule Report

---

### Software License Management

#### 1. License List Page (`/licenses`)
**View Toggle:** Table / Card

**Summary Cards:**
- Total Licenses
- Total Cost
- Assigned (%)
- Expiring Soon

**Table:**
- Software Name
- Version
- License Type
- Total / Assigned / Available
- Cost
- Renewal Date
- Utilization Bar
- Actions

**Filters:**
- License Type
- Vendor
- Expiring in (days)
- Underutilized (<60%)

---

#### 2. License Form Page (`/licenses/new` or `/:id/edit`)
**Sections:**
- Software Information
  - Name, Version, Vendor
- License Details
  - Type, Key, Total Count
- Financial Information
  - Cost per License, Total Cost (auto-calc)
  - Purchase Date
- Subscription Details (if type = Subscription)
  - Billing Frequency, Renewal Date
  - Auto Renewal checkbox
  - Next Billing Amount
- Support Details
  - Support Expiry
  - Contact Email, Phone
- Additional
  - Description, Notes

---

#### 3. License Detail Page (`/licenses/:id`)
**Tabs:**

**Tab 1: Overview**
- License information cards
- Utilization gauge (circular progress)
- Quick actions: Assign, Edit, Deactivate

**Tab 2: Assignments**
- Two sections: Users | Assets
- Table with assignment details
- Search and filter
- Bulk revoke
- Actions: View, Revoke

**Tab 3: Renewal & Support**
- Renewal information
- Support details
- Renewal history
- Set renewal reminder

**Tab 4: History**
- Assignment/revocation history
- Timeline view

---

#### 4. License Assignment Modal
**Form:**
- Assign To Type (radio: User/Asset)
- Select User/Asset (searchable dropdown)
- Expiry Date (if applicable)
- License Key (if specific key)
- Notes

**Validation:**
- Check available licenses > 0
- Warning if no licenses available
- Cannot submit if over limit

---

### Maintenance Management

#### 1. Maintenance Requests Page (`/maintenance/requests`)
**Tabs:**
- Open Requests
- In Progress
- Resolved
- All

**Table:**
- Ticket #
- Asset (clickable)
- Reported By
- Issue Type
- Severity (badge with color)
- Status (badge)
- Assigned To
- Reported Date
- Actions

**Filters:**
- Status, Severity, Issue Type
- Assigned To
- Date Range

**Actions:**
- Create Request
- Export

---

#### 2. Request Detail Page (`/maintenance/requests/:id`)
**Layout:**

**Request Information Card:**
- Ticket Number (large)
- Asset details with link
- Issue type and severity
- Description
- Attachments (with preview)
- Reported by and when

**Status Timeline:**
```
Open → Acknowledged → In Progress → Resolved → Closed
```

**Assignment Card:**
- Assigned to
- Priority
- Response time SLA
- Time elapsed

**Action Buttons (based on status and role):**
- Acknowledge (if Open)
- Assign to Team Member
- Send for Repair
- Add Update/Comment
- Resolve
- Close (if Resolved)
- Cancel

---

#### 3. Send for Repair Modal
**Form:**
- Maintenance Type (dropdown)
- Service Provider (dropdown + custom)
- Service Provider Type (radio)
- Start Date, Expected Completion
- Estimated Cost
- Warranty Coverage (checkbox)
- AMC Coverage (checkbox)
  - If checked, show AMC Contract selector
- Work Description (textarea)

---

#### 4. Maintenance History (on asset detail)
**Table:**
- Date
- Type
- Service Provider
- Cost
- Covered Under (Warranty/AMC)
- Downtime
- Status

**Summary:**
- Total Maintenance Cost
- Average Downtime
- Last Maintenance Date
- Maintenance Count

---

### AMC Contract Management

#### 1. AMC Contracts List Page (`/amc-contracts`)
**Table:**
- Contract #
- Contract Name
- Vendor
- Start Date - End Date
- Value
- Assets Covered
- Status (badge)
- Actions

**Filters:**
- Status, Vendor
- Expiring in (days)

---

#### 2. Contract Form Page (`/amc-contracts/new` or `/:id/edit`)
**Sections:**
- Basic Information
  - Name, Vendor
  - Contract Period
- Financial Terms
  - Contract Value
  - Payment Frequency
  - Billing Cycle
- Coverage Details
  - Coverage Type
  - Response Time (hours)
  - Resolution Time (hours)
- Terms & Conditions
  - Terms (textarea)
  - Inclusions (textarea)
  - Exclusions (textarea)
- Vendor Contact
  - Person, Email, Phone

---

#### 3. Contract Detail Page (`/amc-contracts/:id`)
**Tabs:**

**Tab 1: Overview**
- Contract details
- Vendor information
- Coverage summary
- Status and dates

**Tab 2: Covered Assets**
- Table of assets
- Columns: Asset, Category, Coverage Dates, Maintenance Count, Last Service
- Actions: Add Assets, Remove Asset
- Search and filter

**Tab 3: Maintenance History**
- All maintenances under this contract
- Filter by asset
- Total cost saved
- Average resolution time

**Tab 4: Utilization**
- Maintenance count over time (chart)
- Cost savings analysis
- Asset-wise utilization
- ROI calculation

---

#### 4. Add Assets to AMC Modal
**Features:**
- Asset selection (multi-select with search)
- Filter by category/department
- Bulk add
- Set coverage dates for all or individual
- Preview before confirm

---

### Budget Management

#### 1. Budget Management Page (`/finance/budgets`)
**Header:**
- Fiscal Year Selector (prominent)
- Create Budget button

**Summary Cards:**
- Total Allocated
- Total Spent
- Total Available
- Overall Utilization %

**Budget Table:**
- Department
- Category (if specific)
- Allocated
- Spent
- Available
- Utilization % (with progress bar)
- Status (icon: ✓ OK | ⚠️ Warning | ⛔ Critical)
- Actions

**Color Coding:**
- Green: < 80%
- Yellow: 80-100%
- Red: > 100%

**Filters:**
- Department
- Status (OK/Warning/Critical)

---

#### 2. Budget Form Modal
**Fields:**
- Fiscal Year
- Department (dropdown)
- Category (dropdown, optional for department-wide)
- Allocated Amount

**Validation:**
- Check for duplicate (year + dept + category)
- Amount must be positive

---

#### 3. Budget Dashboard Widget (on main dashboard)
**Sections:**
- Top 5 Departments by Spending (bar chart)
- Departments Over 80% (list with %)
- Budget vs Actual Chart (grouped column)

---

### Asset Disposal

#### 1. Disposal Request Form (`/assets/:id/dispose`)
**Sections:**
- Asset Information (read-only)
  - Asset details
  - Current book value
- Disposal Details
  - Disposal Reason (dropdown)
  - Detailed Reason (textarea, required)
  - Expected Disposal Value (number)
  - Disposal Method (dropdown)

**Preview:**
- Shows gain/loss calculation
- Approval workflow preview
- Submit button

---

#### 2. Disposal Approvals (part of approvals page)
**Pending Disposals Table:**
- Asset
- Reason
- Book Value
- Expected Value
- Gain/Loss
- Requested By
- Requested Date
- My Role (Finance/Admin)
- Actions: Approve, Reject

---

#### 3. Execute Disposal Page (`/disposal/requests/:id/execute`)
**Form:**
- Disposal Date (date picker, default today)
- Actual Disposal Value (number)
- Disposal To (buyer/recipient name)
- Upload Disposal Certificate
- Disposal Notes (textarea)

**Summary:**
- Asset details
- Approvals received
- Calculated gain/loss (updated based on actual value)

**Submit Button:** Complete Disposal

---

## Background Jobs

### Job 1: Monthly Depreciation Calculation
**Schedule:** 1st of every month at 2:00 AM
**Purpose:** Calculate depreciation for all active assets

**Logic:**
1. Get all active assets with depreciation schedules
2. Check if entry already exists for current month
3. For each asset without entry:
   - Get last entry for opening value
   - Calculate depreciation based on method (SLM/WDV)
   - Ensure book value doesn't go below salvage value
   - Create depreciation entry
   - Update asset's current_book_value and accumulated_depreciation
4. Log summary (processed, created, errors)
5. Send email report to Finance team

---

### Job 2: License Renewal Reminder
**Schedule:** Daily at 8:00 AM
**Purpose:** Remind about expiring licenses

**Logic:**
1. Get licenses expiring in next 30 days
2. For each license:
   - Calculate days remaining
   - If 30/15/7/1 days remaining: Send reminder email
3. Send to procurement team and license admin

---

### Job 3: AMC Expiry Alert
**Schedule:** Daily at 8:00 AM
**Purpose:** Alert about expiring AMC contracts

**Logic:**
1. Get contracts expiring in next 30 days
2. Send alerts at 30/15/7 days
3. Notify procurement and IT admin

---

### Job 4: Budget Alert Monitor
**Schedule:** Daily at 9:00 AM
**Purpose:** Monitor budget utilization and send alerts

**Logic:**
1. Get all active budgets for current fiscal year
2. For each budget over 80%:
   - Send alert to department head
   - If over 100%, escalate to Finance
3. Weekly summary to CFO

---

### Job 5: Maintenance SLA Monitor
**Schedule:** Hourly
**Purpose:** Monitor maintenance requests for SLA breaches

**Logic:**
1. Get all open/in-progress maintenance requests
2. Check response time SLA (if AMC contract)
3. Check resolution time SLA
4. If SLA breach imminent or occurred:
   - Send escalation email
   - Update priority to Urgent
5. Log SLA status

---

## Business Rules Summary

### Depreciation Rules
1. ✅ Auto-created when asset registered (if category has depreciation)
2. ✅ Calculated monthly on 1st of month
3. ✅ SLM: Linear depreciation over useful life
4. ✅ WDV: Reducing balance method
5. ✅ Book value cannot go below salvage value
6. ✅ Manual entries require Finance role
7. ✅ One entry per asset per month
8. ✅ Cannot create future entries
9. ✅ Depreciation stops when fully depreciated

### License Management Rules
1. ✅ Use row-level locking when assigning (prevents over-assignment)
2. ✅ Cannot assign if available_licenses = 0
3. ✅ Assignment increments assigned_licenses atomically
4. ✅ Revocation decrements assigned_licenses
5. ✅ Subscription licenses have expiry dates
6. ✅ Alert at 30/15/7 days before renewal
7. ✅ Can assign to user OR asset (not both)

### Maintenance Rules
1. ✅ Auto-generate ticket numbers
2. ✅ Update asset status to 'Under Maintenance'
3. ✅ If AMC covered, link to contract
4. ✅ Track response and resolution time
5. ✅ Send alerts for SLA breaches
6. ✅ Cannot close without resolution
7. ✅ Calculate and track downtime

### Budget Rules
1. ✅ Automatically updated by trigger on asset INSERT/UPDATE/DELETE
2. ✅ Alert when utilization > 80%
3. ✅ Critical alert when utilization > 100%
4. ✅ Department-wide budget: category_id = NULL
5. ✅ Category-specific budget: has category_id
6. ✅ Fiscal year configurable (default: April-March)

### Disposal Rules
1. ✅ Requires dual approval (Finance + Admin)
2. ✅ Finance checks valuation
3. ✅ Admin checks technical feasibility
4. ✅ Calculate gain/loss automatically
5. ✅ Update asset status to 'Disposed'
6. ✅ Generate disposal certificate
7. ✅ Cannot dispose active assigned assets
8. ✅ Log in audit trail

---

## Phase 4 Acceptance Criteria

### Database
- [ ] All financial tables created with constraints
- [ ] Depreciation tables created
- [ ] Budget triggers working for INSERT/UPDATE/DELETE
- [ ] AMC contract-assets junction table created
- [ ] Foreign keys and indexes optimized

### Backend
- [ ] Automated depreciation job scheduled and running
- [ ] Depreciation calculation working (SLM & WDV)
- [ ] License assignment with row-level locking working
- [ ] Cannot over-assign licenses (concurrent test)
- [ ] Maintenance workflow complete
- [ ] AMC contract management working
- [ ] Budget tracking and auto-update working
- [ ] Budget alerts at 80% threshold
- [ ] Disposal dual approval workflow working
- [ ] All background jobs running on schedule

### Frontend
- [ ] Depreciation schedule and reports working
- [ ] Financial tab on asset detail showing correct values
- [ ] License management pages complete
- [ ] License assignment preventing over-assignment
- [ ] Maintenance request workflow working
- [ ] AMC management interface complete
- [ ] Asset-AMC linking working
- [ ] Budget dashboard and management complete
- [ ] Disposal request and approval pages working
- [ ] All financial reports generating correctly

### Business Logic
- [ ] Depreciation calculates correctly for SLM
- [ ] Depreciation calculates correctly for WDV
- [ ] Book value never goes below salvage value
- [ ] Cannot assign more licenses than available
- [ ] Concurrent license assignment handled correctly
- [ ] Asset status changes during maintenance
- [ ] Budget updates automatically when asset purchased
- [ ] Budget updates on asset UPDATE/DELETE
- [ ] Budget alerts sent at 80% threshold
- [ ] Disposal requires both approvals
- [ ] AMC contracts link correctly to assets

### Financial Accuracy
- [ ] Depreciation calculations verified against manual calc
- [ ] Budget tracking matches actual purchases
- [ ] Gain/loss calculations correct
- [ ] Total cost calculations correct
- [ ] License utilization percentages correct

### Testing
- [ ] Run depreciation for 50 assets, verify calculations
- [ ] Test concurrent license assignments (no over-assignment)
- [ ] Create and resolve maintenance requests
- [ ] Verify budget updates when assets purchased
- [ ] Test budget trigger on UPDATE and DELETE
- [ ] Test complete disposal workflow with dual approval
- [ ] Verify AMC contract asset coverage tracking
- [ ] Load test background jobs with 1000+ assets
- [ ] Verify all email notifications sending

---

## Next Phase Preview

**Phase 5** will implement:
- Comprehensive reporting suite (10+ reports)
- Mobile PWA with QR scanning
- Bulk operations and data import/export
- Advanced dashboard analytics with charts
- Complete audit trail system
- Performance optimization
- System polish and production readiness

**Dependencies from Phase 4:**
- Depreciation data ✓
- License tracking ✓
- Maintenance history ✓
- Budget data ✓
- Complete financial records ✓

---

## Critical Notes for Implementation

### Depreciation Schedule Auto-Creation
**CRITICAL:** In Phase 2 asset creation, add logic:
```
After asset created:
1. Check if category has depreciation settings
2. If yes, create depreciation_schedule:
   - Link to asset
   - Copy rate, method, useful_life from category
   - Set purchase_cost, salvage_value, start_date from asset
3. Commit in same transaction
```

### License Assignment Concurrency
**CRITICAL:** Use row-level locking:
```
Transaction steps:
1. BEGIN TRANSACTION
2. SELECT * FROM software_licenses WHERE license_id = ? FOR UPDATE
3. Check available_licenses > 0
4. If yes:
   - Create license_assignment
   - UPDATE software_licenses SET assigned_licenses = assigned_licenses + 1
5. COMMIT
6. On error: ROLLBACK
```

### Budget Trigger Testing
**CRITICAL:** Test all scenarios:
- INSERT: Budget increased
- UPDATE cost: Budget adjusted (old - new)
- UPDATE department: Budget moved between departments
- DELETE non-disposed: Budget decreased
- DELETE disposed: No change (already accounted)

### AMC Contract Asset Linking
**CRITICAL:** Maintain junction table properly:
- Add: Create amc_contract_assets record
- Remove: Set is_active = false (don't delete)
- Validate: No asset in multiple active AMCs
- Query: JOIN to get covered assets

---

**End of Phase 4 Documentation**

**IMPLEMENTATION CHECKLIST:**
- ✅ Build depreciation calculation engine
- ✅ Implement license management with locking
- ✅ Create maintenance workflow
- ✅ Build AMC contract system with asset linking
- ✅ Implement budget tracking with triggers
- ✅ Create disposal workflow with dual approval
- ✅ Set up all background jobs
- ✅ Test concurrency scenarios thoroughly
- ✅ Verify financial calculations accuracy
- ✅ Deploy and monitor automated jobs

**READY TO PROCEED TO PHASE 5:** Only after all acceptance criteria met, financial calculations verified, and concurrency tested.
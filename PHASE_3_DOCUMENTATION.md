# PHASE 3: Asset Operations & Tracking
## Assetica Implementation Guide

**Duration:** 4-5 weeks  
**Prerequisites:** Phase 1 & 2 Complete  
**Team:** 2 Backend + 2 Frontend + 1 QA  
**Priority:** Core Workflow Automation

---

## Overview

Implement complete asset lifecycle operations including assignment, transfer workflows, check-in/check-out, and notification system. This phase brings the asset management workflow to life with automated approvals and email notifications.

---

## Deliverables

- ✅ Asset assignment and unassignment to employees
- ✅ Multi-level transfer approval workflow
- ✅ Check-in/check-out tracking system
- ✅ Email notification system with templates
- ✅ Activity timeline and history
- ✅ Employee asset dashboard
- ✅ Approval queue for managers
- ✅ Overdue tracking and alerts
- ✅ Transfer workflow with role-to-user resolution

---

## Database Schema

### Table: asset_assignments
```sql
CREATE TABLE asset_assignments (
    assignment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    asset_id UUID REFERENCES assets(asset_id) NOT NULL,
    employee_id UUID REFERENCES employees(employee_id) NOT NULL,
    assignment_type VARCHAR(30) NOT NULL,
    assigned_date DATE NOT NULL,
    expected_return_date DATE,
    actual_return_date DATE,
    assigned_location VARCHAR(100),
    assignment_status VARCHAR(30) DEFAULT 'Active',
    assignment_notes TEXT,
    condition_on_assignment VARCHAR(50),
    condition_on_return VARCHAR(50),
    return_notes TEXT,
    assigned_by UUID REFERENCES users(user_id),
    returned_to UUID REFERENCES users(user_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_assignments_asset ON asset_assignments(asset_id);
CREATE INDEX idx_assignments_employee ON asset_assignments(employee_id);
CREATE INDEX idx_assignments_status ON asset_assignments(assignment_status);
CREATE INDEX idx_assignments_dates ON asset_assignments(assigned_date, expected_return_date);
```

**Valid Assignment Types:**
- Permanent: Long-term assignment until employee leaves or asset replaced
- Temporary: Short-term assignment with expected return date

**Valid Assignment Status:**
- Active: Currently assigned and in use
- Returned: Asset returned by employee
- CheckedOut: Temporarily checked out (different from active)

**Valid Condition Values:**
- New: Brand new, unused
- Excellent: Like new, minimal wear
- Good: Normal wear, fully functional
- Fair: Some wear, fully functional
- Poor: Heavy wear, may have minor issues
- Damaged: Not fully functional

**Business Rules:**
- Only one active assignment per asset at a time
- Cannot assign if asset status is not 'Available'
- Expected return date required for temporary assignments
- Condition on assignment must be recorded

---

### Table: checkout_logs
```sql
CREATE TABLE checkout_logs (
    checkout_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    asset_id UUID REFERENCES assets(asset_id) NOT NULL,
    employee_id UUID REFERENCES employees(employee_id) NOT NULL,
    checkout_date DATE NOT NULL,
    expected_checkin_date DATE NOT NULL,
    actual_checkin_date DATE,
    checkout_reason VARCHAR(200),
    checkout_location VARCHAR(100),
    checkin_notes TEXT,
    status VARCHAR(30) DEFAULT 'CheckedOut',
    checked_out_by UUID REFERENCES users(user_id),
    checked_in_by UUID REFERENCES users(user_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_checkout_asset ON checkout_logs(asset_id);
CREATE INDEX idx_checkout_employee ON checkout_logs(employee_id);
CREATE INDEX idx_checkout_status ON checkout_logs(status);
CREATE INDEX idx_checkout_dates ON checkout_logs(expected_checkin_date) WHERE status = 'CheckedOut';
```

**Valid Status Values:**
- CheckedOut: Currently checked out
- CheckedIn: Returned on time
- Overdue: Past expected check-in date and not returned

**Use Cases:**
- Employee borrows projector for meeting
- Employee takes laptop home for remote work
- Employee borrows equipment for client visit
- Pool assets (like conference room equipment)

**Business Rules:**
- Asset must be 'Available' or already assigned to the employee
- System automatically marks as 'Overdue' if past expected date
- Email reminders sent 1 day before due date and daily when overdue

---

### Table: asset_transfers
```sql
CREATE TABLE asset_transfers (
    transfer_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    asset_id UUID REFERENCES assets(asset_id) NOT NULL,
    transfer_type VARCHAR(30) NOT NULL,
    
    -- From
    from_employee_id UUID REFERENCES employees(employee_id),
    from_department VARCHAR(100),
    from_location VARCHAR(100),
    
    -- To
    to_employee_id UUID REFERENCES employees(employee_id),
    to_department VARCHAR(100),
    to_location VARCHAR(100),
    
    transfer_reason TEXT NOT NULL,
    effective_date DATE NOT NULL,
    
    -- Workflow
    status VARCHAR(30) DEFAULT 'Pending',
    requested_by UUID REFERENCES users(user_id),
    requested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Approval Level 1
    level1_approver_id UUID REFERENCES users(user_id),
    level1_approved_at TIMESTAMP,
    level1_status VARCHAR(30),
    level1_remarks TEXT,
    
    -- Approval Level 2
    level2_approver_id UUID REFERENCES users(user_id),
    level2_approved_at TIMESTAMP,
    level2_status VARCHAR(30),
    level2_remarks TEXT,
    
    -- Execution
    executed_by UUID REFERENCES users(user_id),
    executed_at TIMESTAMP,
    execution_notes TEXT,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_transfers_asset ON asset_transfers(asset_id);
CREATE INDEX idx_transfers_status ON asset_transfers(status);
CREATE INDEX idx_transfers_from_emp ON asset_transfers(from_employee_id);
CREATE INDEX idx_transfers_to_emp ON asset_transfers(to_employee_id);
CREATE INDEX idx_transfers_level1 ON asset_transfers(level1_approver_id) WHERE level1_status IS NULL;
CREATE INDEX idx_transfers_level2 ON asset_transfers(level2_approver_id) WHERE level2_status IS NULL;
```

**Valid Transfer Types:**
- EmployeeTransfer: From one employee to another
- DepartmentTransfer: Moving asset between departments
- LocationTransfer: Moving asset between locations
- OwnershipTransfer: Changing primary custodian

**Valid Status Values:**
- Pending: Awaiting approval
- Level1Approved: First level approved, awaiting second level
- Approved: All required approvals obtained
- Rejected: Rejected by approver
- Completed: Transfer executed
- Cancelled: Cancelled by requester

**Valid Approval Status:**
- Approved
- Rejected

**Business Rules:**
- Transfer requires at least 1 level of approval
- High-value assets (>$5000) require 2 levels of approval
- Level 1: Manager approval
- Level 2: Finance/IT Admin approval
- Transfer can be cancelled only if status is 'Pending'
- Upon completion, update asset's current assignment

---

### Table: approval_workflows
```sql
CREATE TABLE approval_workflows (
    workflow_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workflow_name VARCHAR(100) NOT NULL,
    workflow_type VARCHAR(50) NOT NULL,
    conditions JSONB,
    approval_levels INTEGER NOT NULL,
    level1_role VARCHAR(50),
    level2_role VARCHAR(50),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES users(user_id)
);

CREATE INDEX idx_workflows_type ON approval_workflows(workflow_type, is_active);
```

**Workflow Types:**
- AssetTransfer
- AssetDisposal
- MaintenanceRequest
- PurchaseRequest (future)

**Conditions Format:**
```json
{
  "assetValue": {
    "greaterThan": 5000
  },
  "category": ["Laptops", "Servers"]
}
```

**Level Roles:**
- Manager: Employee's direct manager
- Finance: Any user with Finance role
- ITAdmin: Any user with ITAdmin role
- TenantAdmin: Tenant administrator

**Default Workflows:**
1. Standard Transfer: 1 level (Manager)
2. High-Value Transfer: 2 levels (Manager + Finance)
3. IT Asset Transfer: 1 level (ITAdmin)

**Role-to-User Resolution Logic:**
Required for workflow execution - system must resolve role to actual user ID:
- Manager: Get employee's manager from employees.manager_id
- Finance/ITAdmin/TenantAdmin: Get first active user with that role
- Department Manager: Get manager of specific department
- If no user found, escalate to TenantAdmin

---

### Table: notification_templates
```sql
CREATE TABLE notification_templates (
    template_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_code VARCHAR(50) UNIQUE NOT NULL,
    template_name VARCHAR(100) NOT NULL,
    subject VARCHAR(200) NOT NULL,
    body TEXT NOT NULL,
    placeholders JSONB,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_templates_code ON notification_templates(template_code);
```

**Placeholder Format:**
```json
{
  "placeholders": [
    {"key": "EmployeeName", "description": "Employee full name"},
    {"key": "AssetCode", "description": "Asset code"},
    {"key": "AssetName", "description": "Asset name"}
  ]
}
```

**Placeholder Usage in Templates:**
Use double curly braces: `{{EmployeeName}}`

**Required Templates:**

1. **ASSET_ASSIGNED**
   - Subject: Asset Assigned: {{AssetCode}}
   - Sent to: Employee
   - When: Asset assigned
   - Placeholders: EmployeeName, AssetCode, AssetName, AssignmentDate, Location, AssignedBy

2. **ASSET_RETURN_REQUEST**
   - Subject: Request to Return Asset: {{AssetCode}}
   - Sent to: Employee
   - When: IT requests asset return
   - Placeholders: EmployeeName, AssetCode, AssetName, ExpectedReturnDate, Reason

3. **ASSET_RETURNED**
   - Subject: Asset Returned: {{AssetCode}}
   - Sent to: IT Team
   - When: Asset returned by employee
   - Placeholders: EmployeeName, AssetCode, ReturnDate, Condition

4. **TRANSFER_REQUEST**
   - Subject: Action Required: Asset Transfer Approval
   - Sent to: Approver
   - When: Transfer request created
   - Placeholders: ApproverName, AssetCode, AssetName, FromEmployee, ToEmployee, Reason, RequestedBy

5. **TRANSFER_APPROVED**
   - Subject: Transfer Request Approved: {{AssetCode}}
   - Sent to: Requester
   - When: Transfer approved
   - Placeholders: RequesterName, AssetCode, ApprovedBy, Level

6. **TRANSFER_REJECTED**
   - Subject: Transfer Request Rejected: {{AssetCode}}
   - Sent to: Requester
   - When: Transfer rejected
   - Placeholders: RequesterName, AssetCode, RejectedBy, Remarks

7. **TRANSFER_COMPLETED**
   - Subject: Asset Transfer Completed: {{AssetCode}}
   - Sent to: Both employees
   - When: Transfer executed
   - Placeholders: EmployeeName, AssetCode, FromEmployee, ToEmployee, EffectiveDate

8. **CHECKOUT_REMINDER**
   - Subject: Reminder: Asset Check-in Due Tomorrow
   - Sent to: Employee
   - When: 1 day before due date
   - Placeholders: EmployeeName, AssetCode, ExpectedDate

9. **CHECKOUT_OVERDUE**
   - Subject: URGENT: Asset Check-in Overdue
   - Sent to: Employee + Manager
   - When: Past due date (daily)
   - Placeholders: EmployeeName, AssetCode, ExpectedDate, DaysOverdue

10. **ASSIGNMENT_EXPIRING**
    - Subject: Temporary Assignment Ending Soon: {{AssetCode}}
    - Sent to: Employee + IT
    - When: 7 days before expected return
    - Placeholders: EmployeeName, AssetCode, ExpectedReturnDate

---

### Table: notification_logs
```sql
CREATE TABLE notification_logs (
    log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_code VARCHAR(50),
    recipient_email VARCHAR(200) NOT NULL,
    recipient_name VARCHAR(200),
    subject VARCHAR(200),
    body TEXT,
    status VARCHAR(30),
    sent_at TIMESTAMP,
    error_message TEXT,
    retry_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_notif_logs_status ON notification_logs(status);
CREATE INDEX idx_notif_logs_created ON notification_logs(created_at DESC);
CREATE INDEX idx_notif_logs_recipient ON notification_logs(recipient_email);
```

**Valid Status Values:**
- Pending: Queued for sending
- Sent: Successfully sent
- Failed: Failed to send
- Retrying: Being retried

**Retry Logic:**
- Retry failed emails up to 3 times
- Exponential backoff: 5 min, 15 min, 1 hour
- After 3 failures, mark as permanently failed
- Log all attempts

---

## API Endpoints

### Asset Assignment APIs

#### POST /api/assets/{id}/assign
**Purpose:** Assign asset to employee

**Request:**
```json
{
  "employeeId": "uuid",
  "assignmentType": "Permanent | Temporary",
  "assignedDate": "date",
  "expectedReturnDate": "date (required if Temporary)",
  "location": "string",
  "condition": "string",
  "notes": "string"
}
```

**Business Rules:**
- Validate asset status is 'Available'
- Validate employee exists and is active
- For temporary: expectedReturnDate required and must be future date
- Update asset status to 'Active'
- Create assignment record
- Send email notification to employee
- Log in audit trail

**Response:**
```json
{
  "assignmentId": "uuid",
  "message": "Asset assigned successfully"
}
```

**Access:** ITTeam, Manager (with approval)

---

#### POST /api/assets/{id}/unassign
**Purpose:** Unassign/return asset

**Request:**
```json
{
  "returnDate": "date",
  "condition": "string",
  "notes": "string"
}
```

**Business Rules:**
- Validate asset has active assignment
- Update assignment: set actual_return_date, condition_on_return, status='Returned'
- Update asset status to 'Available'
- Send email notification to IT team
- Log in audit trail

**Access:** ITTeam, assigned employee (return own asset)

---

#### GET /api/assets/{id}/assignment-history
**Purpose:** Get complete assignment history of asset

**Response:**
```json
{
  "currentAssignment": {
    "assignmentId": "uuid",
    "employee": { },
    "assignedDate": "date",
    "assignmentType": "string",
    "condition": "string"
  },
  "history": [
    {
      "assignmentId": "uuid",
      "employee": { },
      "assignedDate": "date",
      "returnedDate": "date",
      "duration": "string (e.g., '3 months')"
    }
  ]
}
```

---

#### GET /api/employees/{id}/assigned-assets
**Purpose:** Get all assets assigned to employee

**Response:**
```json
{
  "assets": [
    {
      "assetId": "uuid",
      "assetCode": "string",
      "assetName": "string",
      "category": "string",
      "assignedDate": "date",
      "assignmentType": "string",
      "condition": "string"
    }
  ]
}
```

---

### Check-in/Check-out APIs

#### POST /api/assets/{id}/checkout
**Purpose:** Check out asset temporarily

**Request:**
```json
{
  "employeeId": "uuid",
  "checkoutDate": "date",
  "expectedCheckinDate": "date",
  "reason": "string",
  "location": "string"
}
```

**Business Rules:**
- Asset must be 'Available' or already assigned to this employee
- Expected check-in date must be future
- Update asset status to 'CheckedOut'
- Create checkout log
- Send confirmation email
- Schedule reminder email (1 day before due)

**Access:** ITTeam, Employees (for available assets)

---

#### POST /api/assets/{id}/checkin
**Purpose:** Check in asset after checkout

**Request:**
```json
{
  "checkinDate": "date",
  "notes": "string"
}
```

**Business Rules:**
- Validate active checkout exists
- Calculate if overdue
- Update checkout log: actual_checkin_date, status='CheckedIn'
- Update asset status back to 'Available' or 'Active' (if was assigned)
- Send confirmation email
- If overdue, send notification to manager

---

#### GET /api/assets/{id}/checkout-history
**Purpose:** Get checkout history

---

#### GET /api/checkouts/overdue
**Purpose:** Get all overdue checkouts

**Response:**
```json
{
  "overdueCheckouts": [
    {
      "checkoutId": "uuid",
      "asset": { },
      "employee": { },
      "expectedDate": "date",
      "daysOverdue": number
    }
  ]
}
```

**Access:** ITTeam, Managers

---

### Asset Transfer APIs

#### POST /api/transfers
**Purpose:** Request asset transfer

**Request:**
```json
{
  "assetId": "uuid",
  "transferType": "string",
  "fromEmployeeId": "uuid (optional)",
  "toEmployeeId": "uuid (optional)",
  "fromDepartment": "string (optional)",
  "toDepartment": "string (optional)",
  "fromLocation": "string (optional)",
  "toLocation": "string (optional)",
  "reason": "string",
  "effectiveDate": "date"
}
```

**Business Rules:**
- Validate asset exists and is assigned/available
- Based on transfer type, validate appropriate fields
- Determine applicable workflow based on conditions
- Resolve approver IDs from workflow roles
- Create transfer request with status='Pending'
- Send email to level 1 approver
- Log creation

**Workflow Resolution:**
1. Get asset value from assets table
2. Find matching workflow based on:
   - workflow_type = 'AssetTransfer'
   - conditions match (asset value, category, etc.)
   - is_active = true
3. If multiple matches, use most specific one
4. Get approval_levels from workflow
5. Resolve level1_role to actual user ID:
   - If 'Manager': Get from employee's manager_id
   - If other role: Query users table for active user with that role
6. If 2 levels, resolve level2_role similarly
7. Store approver IDs in transfer record

**Access:** All authenticated users (can request transfer of own assets)

---

#### GET /api/transfers
**Purpose:** List transfers

**Query Parameters:**
- `status`: Filter by status
- `assetId`: Filter by asset
- `pendingApprovalBy`: UUID (get transfers pending this user's approval)

**Response:** Paginated list of transfers

---

#### GET /api/transfers/{id}
**Purpose:** Get transfer details

**Response:**
```json
{
  "transfer": {
    "transferId": "uuid",
    "asset": { },
    "transferType": "string",
    "fromEmployee": { },
    "toEmployee": { },
    "reason": "string",
    "effectiveDate": "date",
    "status": "string",
    "workflow": {
      "level1": {
        "approver": { },
        "status": "string",
        "approvedAt": "datetime",
        "remarks": "string"
      },
      "level2": {
        "approver": { },
        "status": "string",
        "approvedAt": "datetime",
        "remarks": "string"
      }
    },
    "requestedBy": { },
    "requestedAt": "datetime"
  }
}
```

---

#### PUT /api/transfers/{id}/approve
**Purpose:** Approve transfer request

**Request:**
```json
{
  "level": 1 | 2,
  "remarks": "string (optional)"
}
```

**Business Rules:**
- Validate user is the designated approver for this level
- Validate transfer status allows approval
- Update approval status and timestamp
- If level 1 approved and level 2 required: Update status to 'Level1Approved', notify level 2 approver
- If all approvals obtained: Update status to 'Approved', notify requester and IT team
- Send email notifications
- Log approval

**Access:** Designated approver only

---

#### PUT /api/transfers/{id}/reject
**Purpose:** Reject transfer request

**Request:**
```json
{
  "level": 1 | 2,
  "remarks": "string (required)"
}
```

**Business Rules:**
- Validate user is designated approver
- Update status to 'Rejected'
- Record rejection details
- Send email to requester
- Log rejection

---

#### POST /api/transfers/{id}/execute
**Purpose:** Execute approved transfer

**Request:**
```json
{
  "executionNotes": "string"
}
```

**Business Rules:**
- Validate transfer status is 'Approved'
- Validate effective date is today or past
- Update old assignment (if exists): set status='Returned'
- Create new assignment (if to employee specified)
- Update asset location/department
- Update transfer: status='Completed', execution details
- Send completion emails to all parties
- Log execution

**Access:** ITTeam only

---

#### DELETE /api/transfers/{id}
**Purpose:** Cancel transfer request

**Business Rules:**
- Can only cancel if status='Pending'
- Requester or admin can cancel
- Send cancellation email to approvers
- Log cancellation

---

### Approval Queue APIs

#### GET /api/approvals/pending
**Purpose:** Get all items pending current user's approval

**Response:**
```json
{
  "transfers": [
    {
      "transferId": "uuid",
      "asset": { },
      "requester": { },
      "requestedAt": "datetime",
      "reason": "string",
      "level": 1 | 2
    }
  ],
  "disposals": [ ],
  "maintenanceRequests": [ ]
}
```

**Access:** Users with approval roles

---

#### GET /api/approvals/history
**Purpose:** Get approval history for current user

**Query Parameters:**
- `startDate`, `endDate`: Date range
- `action`: Approved | Rejected

---

### My Assets (Employee View)

#### GET /api/my-assets
**Purpose:** Get assets assigned to current logged-in user

**Response:**
```json
{
  "assignedAssets": [
    {
      "asset": { },
      "assignmentDate": "date",
      "assignmentType": "string",
      "condition": "string"
    }
  ],
  "checkedOutAssets": [
    {
      "asset": { },
      "checkoutDate": "date",
      "expectedReturnDate": "date",
      "daysRemaining": number
    }
  ]
}
```

---

#### POST /api/my-assets/{id}/report-issue
**Purpose:** Employee reports issue with assigned asset

**Request:**
```json
{
  "issueType": "string",
  "description": "string",
  "severity": "string",
  "photos": ["base64 images"]
}
```

**Business Rules:**
- Create maintenance request (Phase 4 feature)
- Send email to IT team
- Update asset status if severity is high

---

### Notification Template Management

#### GET /api/notification-templates
**Purpose:** List all templates

**Access:** Admin only

---

#### GET /api/notification-templates/{code}
**Purpose:** Get template details

---

#### PUT /api/notification-templates/{code}
**Purpose:** Update template

**Request:**
```json
{
  "subject": "string",
  "body": "string"
}
```

**Business Rules:**
- Cannot change template_code
- Cannot delete system templates
- Validate placeholders in body exist
- Preview functionality available

---

#### POST /api/notification-templates/test
**Purpose:** Send test email

**Request:**
```json
{
  "templateCode": "string",
  "testEmail": "string",
  "sampleData": {
    "EmployeeName": "John Doe",
    "AssetCode": "LAP-2025-0001"
  }
}
```

---

### Notification Logs

#### GET /api/notification-logs
**Purpose:** View sent notifications

**Query Parameters:**
- `status`: Filter by status
- `recipient`: Filter by email
- `startDate`, `endDate`: Date range
- `templateCode`: Filter by template

**Access:** Admin only

---

#### POST /api/notification-logs/{id}/retry
**Purpose:** Retry failed notification

**Access:** Admin only

---

## Frontend Pages & Components

### Asset Assignment

#### 1. Assignment Modal (opened from asset detail)
**Form Fields:**
- Employee selection (searchable dropdown)
- Assignment type (radio: Permanent/Temporary)
- Assignment date (date picker, default today)
- Expected return date (if temporary, date picker)
- Location (dropdown with asset's current location pre-filled)
- Condition on assignment (dropdown)
- Notes (textarea)

**Features:**
- Employee search by name or code
- Validation: All required fields
- Preview assignment before confirm
- Cancel and Assign buttons

---

#### 2. Return Asset Modal
**Form Fields:**
- Return date (date picker, default today)
- Condition on return (dropdown)
- Return checklist:
  - [ ] All accessories returned (charger, mouse, etc.)
  - [ ] Asset cleaned
  - [ ] No physical damage
  - [ ] Data backed up (for IT assets)
- Return notes (textarea)

**Features:**
- Show original condition for comparison
- Calculate assignment duration
- Condition warning if worse than original

---

### Transfer Workflow

#### 1. Transfer Request Page (`/transfers/new`)
**Steps:**

**Step 1: Select Asset**
- Asset selection (searchable)
- Shows current assignment/location
- Validates asset can be transferred

**Step 2: Transfer Details**
- Transfer type selection (radio buttons with icons)
- From/To fields (dynamic based on type)
  - Employee Transfer: Employee dropdowns
  - Department Transfer: Department dropdowns
  - Location Transfer: Location dropdowns
- Reason (textarea, required)
- Effective date (date picker)

**Step 3: Review & Submit**
- Summary of transfer
- Expected approval workflow display
- Approver names shown
- Submit button

---

#### 2. Transfer List Page (`/transfers`)
**Tabs:**
- My Requests (transfers I requested)
- Pending My Approval (transfers waiting for my approval)
- All Transfers (admin view)

**Table Columns:**
- Transfer ID
- Asset
- From → To
- Requested Date
- Status (with color badge)
- Current Approver
- Actions

**Filters:**
- Status
- Date range
- Asset category

---

#### 3. Transfer Detail Page (`/transfers/:id`)
**Sections:**

**Transfer Information Card:**
- Asset details
- Transfer type
- From and To details
- Reason
- Effective date
- Requested by and when

**Approval Workflow Timeline:**
```
1. Requested ✓ (John Doe, Jan 15, 2025)
2. Manager Approval ⏳ (Pending - Jane Smith)
3. Finance Approval ○ (Waiting)
4. Execution ○ (Waiting)
```

**Approval Actions (if pending user's approval):**
- Approve button (opens remarks modal)
- Reject button (requires remarks)

**Status History:**
- Timeline of all status changes
- User, date, action, remarks

---

#### 4. Approvals Dashboard (`/approvals`)
**Summary Cards:**
- Pending My Approval (count with urgency indicator)
- Approved This Month
- Rejected This Month
- Average Approval Time

**Pending Approvals Table:**
- Sortable by age (oldest first default)
- Quick approve/reject actions
- Batch approval (select multiple)
- Filter by type

**Approval History:**
- All past approvals
- Export to Excel

---

### Check-in/Check-out

#### 1. Check-out Modal
**Form Fields:**
- Employee (searchable dropdown)
- Check-out date (default today)
- Expected check-in date (required, future date)
- Reason (dropdown + text)
  - Business Travel
  - Remote Work
  - Client Meeting
  - Training
  - Other
- Location/Destination (text)

**Features:**
- Calculate duration automatically
- Warning if >30 days
- Reminder email scheduled automatically

---

#### 2. Check-in Modal
**Display:**
- Checkout details (read-only)
- Expected return date (highlighted if overdue)
- Days overdue (if applicable)

**Form Fields:**
- Check-in date (default today)
- Condition check (read-only condition comparison)
- Notes (any issues during checkout)

**Features:**
- Auto-calculate overdue days
- Show warning if overdue

---

#### 3. Overdue Checkouts Page (`/checkouts/overdue`)
**Table:**
- Asset Code & Name
- Employee
- Expected Return Date
- Days Overdue (color-coded)
- Actions:
  - Send Reminder
  - Check-in
  - Report Issue

**Features:**
- Sort by days overdue
- Bulk send reminders
- Export report

---

### Employee Asset Views

#### 1. My Assets Page (`/my-assets`)
**Layout:**

**Section 1: Assigned to Me**
- Card layout (grid)
- Each card shows:
  - Asset image
  - Asset code & name
  - Category
  - Assigned date
  - Assignment type badge
  - Actions: View Details, Report Issue

**Section 2: Currently Checked Out**
- Table layout
- Shows due date countdown
- Overdue highlighted in red
- Actions: Check-in, Extend (request)

**Section 3: Quick Actions**
- Request Asset
- Report Issue
- View History

---

#### 2. Employee Asset Dashboard (for Managers - `/team/assets`)
**Widgets:**
- Assets Assigned to My Team
- Asset Distribution by Employee
- Overdue Items from My Team
- Recent Asset Movements

**Team Assets Table:**
- Employee Name
- Assets Assigned
- Overdue Items
- Last Activity
- Action: View Details

---

### Activity History & Timeline

#### 1. Asset History Timeline (on asset detail page)
**Display Format:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

● Created
  Jan 15, 2025 by IT Admin
  Asset registered in system
  Purchase Cost: $1,200

● Assigned
  Jan 20, 2025 by IT Admin
  Assigned to John Doe (Engineering)
  Condition: New
  Type: Permanent

● Checked Out
  Feb 5, 2025 by John Doe
  Reason: Business travel to Delhi
  Expected return: Feb 10, 2025

● Checked In
  Feb 11, 2025 by IT Admin
  1 day overdue
  Condition: Good

● Transfer Requested
  Mar 1, 2025 by John Doe
  Transfer to Jane Smith
  Reason: Changing projects

● Transfer Approved (Level 1)
  Mar 2, 2025 by Manager Alex
  Remarks: Approved for project needs

● Transfer Completed
  Mar 3, 2025 by IT Admin
  New assignment created

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Features:**
- Expandable entries (click for full details)
- Filter by action type
- Date range filter
- Export timeline

---

#### 2. Employee Activity History
Similar timeline for employee showing all asset interactions

---

### Notification Management

#### 1. Notification Templates Page (`/admin/notifications`)
**Table:**
- Template Name
- Code
- Subject
- Last Modified
- Status (Active/Inactive)
- Actions: Edit, Test, View Logs

---

#### 2. Template Editor Page (`/admin/notifications/:code/edit`)
**Sections:**

**Template Information:**
- Name (read-only)
- Code (read-only)
- Active toggle

**Email Content:**
- Subject line editor
- Body editor (rich text with placeholder insertion)
- Available placeholders panel (click to insert)

**Preview:**
- Enter sample data
- See rendered email
- Send test email

**Actions:**
- Save
- Test Send
- Revert to Default

---

#### 3. Notification Logs Page (`/admin/notification-logs`)
**Filters:**
- Date range
- Status (Sent/Failed/Pending)
- Template type
- Recipient email

**Table:**
- Timestamp
- Template
- Recipient
- Subject
- Status (badge)
- Actions: View, Retry (if failed)

**Features:**
- View email content
- Retry failed emails
- Export logs

---

## Email Configuration

### SMTP Settings
**Configuration Required:**
```
SmtpServer: smtp.gmail.com (or other provider)
SmtpPort: 587 (TLS) or 465 (SSL)
Username: noreply@assetica.io
Password: *** (app password)
FromEmail: noreply@assetica.io
FromName: Assetica Asset Management
EnableSSL: true
```

### Email Templates Structure
**HTML Template Layout:**
```
[Company Logo]

[Header with Asset Management branding]

[Email Content with placeholders replaced]

[Footer with:]
- Login link
- Support email
- Company address
- Unsubscribe link (future)
```

---

## Background Jobs

### Job 1: Checkout Reminder Job
**Schedule:** Daily at 9:00 AM
**Purpose:** Send reminders for checkouts due within 1 day

**Logic:**
1. Query checkout_logs where status = 'CheckedOut'
2. Filter: expected_checkin_date = tomorrow
3. For each checkout:
   - Get employee and asset details
   - Send reminder email
   - Log notification

---

### Job 2: Overdue Checkout Job
**Schedule:** Daily at 9:00 AM
**Purpose:** Mark overdue checkouts and send alerts

**Logic:**
1. Query checkout_logs where status = 'CheckedOut' AND expected_checkin_date < today
2. Update status to 'Overdue'
3. For each overdue:
   - Send overdue alert to employee
   - Send alert to employee's manager
   - Send daily reminders (limit to once per day)
   - Log notifications

---

### Job 3: Assignment Expiry Reminder
**Schedule:** Daily at 9:00 AM
**Purpose:** Remind about expiring temporary assignments

**Logic:**
1. Query asset_assignments where:
   - assignment_type = 'Temporary'
   - assignment_status = 'Active'
   - expected_return_date between today and 7 days from now
2. Send reminder emails to employee and IT team
3. Log notifications

---

### Job 4: Transfer Pending Escalation
**Schedule:** Daily at 10:00 AM
**Purpose:** Escalate transfers pending for >3 days

**Logic:**
1. Query asset_transfers where:
   - status = 'Pending' or 'Level1Approved'
   - requested_at < 3 days ago
2. Send escalation email to:
   - Pending approver
   - Pending approver's manager
   - TenantAdmin (if >7 days)
3. Log escalations

---

## Business Rules Summary

### Asset Assignment Rules
1. ✅ Asset must be in 'Available' status
2. ✅ Employee must be active
3. ✅ Only one active assignment per asset
4. ✅ Temporary assignments must have expected return date
5. ✅ Condition must be recorded on assignment
6. ✅ Email sent to employee on assignment
7. ✅ Asset status updated to 'Active'
8. ✅ Audit log created

### Asset Return Rules
1. ✅ Must have active assignment
2. ✅ Condition on return must be recorded
3. ✅ Asset status updated to 'Available'
4. ✅ Assignment marked as 'Returned'
5. ✅ Email sent to IT team
6. ✅ If condition degraded significantly, trigger review

### Transfer Workflow Rules
1. ✅ Determine workflow based on asset value/category
2. ✅ Resolve approver roles to actual user IDs
3. ✅ Manager role → employee's manager from employees table
4. ✅ Other roles → first active user with that role
5. ✅ If no approver found → escalate to TenantAdmin
6. ✅ High-value assets (>$5000) require 2-level approval
7. ✅ Each approval level sends email to next approver
8. ✅ Rejection stops workflow immediately
9. ✅ Completed transfer updates asset assignment
10. ✅ All parties notified at each stage

### Check-out Rules
1. ✅ Asset must be 'Available' or already assigned to employee
2. ✅ Expected return date must be in future
3. ✅ Reminder sent 1 day before due date
4. ✅ Auto-marked overdue if not returned by due date
5. ✅ Daily overdue alerts sent
6. ✅ Manager copied on overdue alerts
7. ✅ Can extend checkout by submitting new expected date

### Notification Rules
1. ✅ All placeholders must be replaced before sending
2. ✅ Failed emails retried up to 3 times
3. ✅ All notifications logged in database
4. ✅ Test emails available for template validation
5. ✅ System emails sent from noreply address
6. ✅ HTML formatting supported
7. ✅ Attachments supported (for reports)

---

## Phase 3 Acceptance Criteria

### Database
- [ ] All operation-related tables created with proper indexes
- [ ] Workflow templates populated
- [ ] Notification templates populated with all 10 required templates
- [ ] Foreign key constraints working
- [ ] Indexes optimized for approval queries

### Backend
- [ ] All Phase 3 API endpoints functional
- [ ] Assignment and unassignment working correctly
- [ ] Transfer workflow with role-to-user resolution working
- [ ] Multi-level approval logic implemented
- [ ] Check-in/Check-out tracking working
- [ ] Email notifications sending correctly
- [ ] Template placeholder replacement working
- [ ] History aggregation API working
- [ ] Background jobs scheduled and running
- [ ] Retry logic for failed emails working

### Frontend
- [ ] Asset assignment flow complete with validation
- [ ] Asset return flow working
- [ ] Transfer request form (multi-step) working
- [ ] Transfer approval pages functional
- [ ] Pending approvals dashboard working
- [ ] My Assets page for employees complete
- [ ] Check-in/Check-out modals functional
- [ ] Activity timeline displaying correctly
- [ ] Notification template management working
- [ ] Notification logs viewer working
- [ ] All pages mobile-responsive

### Business Logic
- [ ] Cannot assign unavailable asset
- [ ] Cannot assign to inactive employee
- [ ] Only one active assignment per asset
- [ ] Transfer requires appropriate approvals based on value
- [ ] Overdue checkouts flagged correctly
- [ ] Role-to-user resolution working for all cases
- [ ] If no approver found, escalates correctly
- [ ] Assignment prevents concurrent active assignments
- [ ] All email placeholders replaced correctly

### Email System
- [ ] SMTP configuration working
- [ ] All 10 template emails sending
- [ ] Placeholders replaced correctly
- [ ] HTML formatting rendering correctly
- [ ] Failed emails being retried
- [ ] Email logs capturing all sends
- [ ] Test email functionality working

### Background Jobs
- [ ] Checkout reminder job running daily
- [ ] Overdue marking job running daily
- [ ] Assignment expiry reminder job running
- [ ] Transfer escalation job running
- [ ] All jobs logging executions
- [ ] Job failures handled gracefully

### Testing
- [ ] Test complete assignment flow (assign and return)
- [ ] Test transfer with 1-level approval
- [ ] Test transfer with 2-level approval
- [ ] Test transfer rejection
- [ ] Verify emails sent at each step
- [ ] Test checkout and verify overdue detection
- [ ] Test role-to-user resolution for all roles
- [ ] Test concurrent assignment attempts (should fail)
- [ ] Verify audit logs capture all actions
- [ ] Load test with 50 concurrent transfer requests

---

## Next Phase Preview

**Phase 4** will implement:
- Automated depreciation calculation engine
- Software license management with allocation tracking
- Maintenance management system
- Warranty and AMC contract management
- Budget tracking and alerts
- Asset disposal workflow with approvals
- Financial reports and dashboards

**Dependencies from Phase 3:**
- Assignment tracking ✓
- Transfer workflow ✓
- Email notification system ✓
- Approval workflow framework ✓

---

## Critical Notes for Implementation

### Role-to-User Resolution
**CRITICAL:** Always resolve approval roles to actual user IDs:
```
Resolution Logic:
1. If role = "Manager": 
   - Get from employee's manager_id in employees table
   - If NULL, escalate to department manager
   - If still NULL, escalate to TenantAdmin

2. If role = "Finance" or "ITAdmin" or other role:
   - Query users table: WHERE role = {role} AND is_active = true
   - Get first active user
   - If none found, escalate to TenantAdmin

3. Store resolved user_id in transfer record
4. Send email to resolved user
```

### Email Placeholder Replacement
**CRITICAL:** Replace ALL placeholders before sending:
1. Get template from database
2. Build placeholder dictionary from context
3. Replace each {{Placeholder}} with actual value
4. Validate no unreplaced placeholders remain
5. Send email
6. Log with final content

### Concurrent Assignment Prevention
**CRITICAL:** Use database constraints and locking:
1. Start transaction
2. Check for existing active assignment
3. If exists, rollback with error
4. Create new assignment
5. Update asset status
6. Commit transaction

### Overdue Detection
**IMPLEMENTATION:** Use database query, not application logic:
```sql
-- Mark overdue in database
UPDATE checkout_logs 
SET status = 'Overdue'
WHERE status = 'CheckedOut' 
  AND expected_checkin_date < CURRENT_DATE;

-- Then send notifications
```

---

**End of Phase 3 Documentation**

**IMPLEMENTATION CHECKLIST:**
- ✅ Build assignment system with validation
- ✅ Implement transfer workflow with role resolution
- ✅ Create approval system with email notifications
- ✅ Build check-in/check-out tracking
- ✅ Set up email system with all templates
- ✅ Implement background jobs for reminders/overdue
- ✅ Create activity timeline aggregation
- ✅ Test email delivery and placeholder replacement
- ✅ Test role-to-user resolution for all scenarios
- ✅ Deploy and monitor background jobs

**READY TO PROCEED TO PHASE 4:** Only after all acceptance criteria met and approval workflows tested thoroughly.
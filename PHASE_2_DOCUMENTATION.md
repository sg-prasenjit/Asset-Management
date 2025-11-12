# PHASE 2: Asset Registration & Core Management
## Assetica Implementation Guide

**Duration:** 4-5 weeks  
**Prerequisites:** Phase 1 Complete  
**Team:** 2 Backend + 2 Frontend + 1 QA  
**Priority:** Core Business Value

---

## Overview

Implement core asset management functionality including asset registration, categorization, QR code generation, and inventory tracking. This phase delivers the primary value proposition of the application.

---

## Deliverables

- ✅ Complete asset registration system with custom fields
- ✅ Asset categories with depreciation configuration
- ✅ QR code generation and printing system
- ✅ Asset search and advanced filtering
- ✅ Basic inventory dashboard with analytics
- ✅ Vendor management system
- ✅ Document attachment system with cloud storage
- ✅ File upload with security
- ✅ Asset code generation with race condition prevention
- ✅ Auto-creation of depreciation schedules
- ✅ Full-text search capability

---

## Database Schema

### Table: asset_categories
```sql
CREATE TABLE asset_categories (
    category_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_name VARCHAR(100) NOT NULL,
    category_code VARCHAR(20) UNIQUE NOT NULL,
    description TEXT,
    depreciation_rate DECIMAL(5,2),
    depreciation_method VARCHAR(20) DEFAULT 'SLM',
    useful_life_years INTEGER,
    is_system_defined BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES users(user_id),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_categories_code ON asset_categories(category_code);
CREATE INDEX idx_categories_active ON asset_categories(is_active);
```

**System Pre-defined Categories:**
| Category | Code | Dep. Rate | Life | Method |
|----------|------|-----------|------|--------|
| Laptops | LAP | 33.33% | 3 years | SLM |
| Desktops | DSK | 33.33% | 3 years | SLM |
| Monitors | MON | 25.00% | 4 years | SLM |
| Mobile Phones | MOB | 50.00% | 2 years | SLM |
| Tablets | TAB | 50.00% | 2 years | SLM |
| Servers | SRV | 20.00% | 5 years | WDV |
| Network Equipment | NET | 20.00% | 5 years | WDV |
| Printers | PRT | 25.00% | 4 years | SLM |
| Peripherals | PER | 25.00% | 4 years | SLM |
| Software | SFT | 0% | 0 | N/A |

**Depreciation Methods:**
- SLM: Straight Line Method
- WDV: Written Down Value
- N/A: No depreciation (for software, land, etc.)

---

### Table: custom_fields
```sql
CREATE TABLE custom_fields (
    field_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id UUID REFERENCES asset_categories(category_id) ON DELETE CASCADE,
    field_name VARCHAR(100) NOT NULL,
    field_label VARCHAR(100) NOT NULL,
    field_type VARCHAR(20) NOT NULL,
    options JSONB,
    is_mandatory BOOLEAN DEFAULT false,
    display_order INTEGER,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(category_id, field_name)
);

CREATE INDEX idx_custom_fields_category ON custom_fields(category_id);
CREATE INDEX idx_custom_fields_active ON custom_fields(is_active, display_order);
```

**Valid Field Types:**
- text: Single line text input
- textarea: Multi-line text input
- number: Numeric input
- dropdown: Single selection from options
- multiselect: Multiple selections from options
- date: Date picker
- boolean: Yes/No checkbox
- email: Email format validation
- url: URL format validation

**Options Format (for dropdown/multiselect):**
```json
{
  "values": ["Option 1", "Option 2", "Option 3"]
}
```

**Example Custom Fields by Category:**
- Laptops: RAM Size, Processor, HDD/SSD Capacity, Screen Size, OS
- Phones: IMEI Number, Phone Number, SIM Provider, Data Plan
- Servers: IP Address, Server Type, CPU Cores, RAM GB

---

### Table: vendors
```sql
CREATE TABLE vendors (
    vendor_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_name VARCHAR(200) NOT NULL,
    vendor_code VARCHAR(50) UNIQUE NOT NULL,
    contact_person VARCHAR(100),
    email VARCHAR(200),
    phone VARCHAR(20),
    address TEXT,
    city VARCHAR(100),
    state VARCHAR(100),
    country VARCHAR(100),
    postal_code VARCHAR(20),
    gst_number VARCHAR(50),
    pan_number VARCHAR(50),
    website VARCHAR(200),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES users(user_id),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_vendors_code ON vendors(vendor_code);
CREATE INDEX idx_vendors_name ON vendors(vendor_name);
CREATE INDEX idx_vendors_active ON vendors(is_active);
```

**Vendor Code Format:** VEN-YYYY-#### (e.g., VEN-2025-0001)

---

### Table: asset_code_sequences
```sql
CREATE TABLE asset_code_sequences (
    category_code VARCHAR(20) PRIMARY KEY,
    last_number INTEGER NOT NULL DEFAULT 0,
    year INTEGER NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(category_code, year)
);

CREATE INDEX idx_sequences_year ON asset_code_sequences(year);
```

**Purpose:** Prevents race conditions in asset code generation by using row-level locking

**Usage:** When generating asset code:
1. Lock row: `SELECT last_number FROM asset_code_sequences WHERE category_code = 'LAP' AND year = 2025 FOR UPDATE`
2. Increment: `UPDATE asset_code_sequences SET last_number = last_number + 1 WHERE ...`
3. Use new number for asset code

---

### Table: assets
```sql
CREATE TABLE assets (
    asset_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    asset_code VARCHAR(50) UNIQUE NOT NULL,
    asset_name VARCHAR(200) NOT NULL,
    category_id UUID REFERENCES asset_categories(category_id) NOT NULL,
    serial_number VARCHAR(100) UNIQUE,
    mac_address VARCHAR(50),
    model VARCHAR(100),
    brand VARCHAR(100),
    
    -- Financial Information
    purchase_cost DECIMAL(15,2) NOT NULL,
    purchase_date DATE NOT NULL,
    invoice_number VARCHAR(100),
    vendor_id UUID REFERENCES vendors(vendor_id),
    
    -- Warranty Information
    warranty_expiry_date DATE,
    warranty_months INTEGER,
    warranty_provider VARCHAR(200),
    
    -- Location & Assignment
    location VARCHAR(100),
    department VARCHAR(100),
    current_status VARCHAR(30) DEFAULT 'Available',
    
    -- Depreciation (calculated fields - updated by jobs)
    current_book_value DECIMAL(15,2),
    accumulated_depreciation DECIMAL(15,2) DEFAULT 0,
    salvage_value DECIMAL(15,2) DEFAULT 0,
    
    -- QR Code
    qr_code_url VARCHAR(500),
    qr_code_data TEXT,
    
    -- Custom Fields
    custom_fields JSONB DEFAULT '{}'::jsonb,
    
    -- Full-text search
    search_vector tsvector,
    
    -- Metadata
    description TEXT,
    notes TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES users(user_id)
);

-- Standard Indexes
CREATE INDEX idx_assets_code ON assets(asset_code);
CREATE INDEX idx_assets_serial ON assets(serial_number) WHERE serial_number IS NOT NULL;
CREATE INDEX idx_assets_category ON assets(category_id);
CREATE INDEX idx_assets_status ON assets(current_status);
CREATE INDEX idx_assets_department ON assets(department);
CREATE INDEX idx_assets_location ON assets(location);
CREATE INDEX idx_assets_created ON assets(created_at DESC);
CREATE INDEX idx_assets_purchase_date ON assets(purchase_date);

-- Composite Indexes for common queries
CREATE INDEX idx_assets_category_status ON assets(category_id, current_status);
CREATE INDEX idx_assets_dept_status ON assets(department, current_status);

-- Full-text Search Index
CREATE INDEX idx_assets_search ON assets USING GIN(search_vector);

-- Trigger to update search_vector
CREATE FUNCTION assets_search_trigger() RETURNS trigger AS $$
BEGIN
    NEW.search_vector := 
        setweight(to_tsvector('english', COALESCE(NEW.asset_code, '')), 'A') ||
        setweight(to_tsvector('english', COALESCE(NEW.asset_name, '')), 'A') ||
        setweight(to_tsvector('english', COALESCE(NEW.serial_number, '')), 'B') ||
        setweight(to_tsvector('english', COALESCE(NEW.brand, '')), 'C') ||
        setweight(to_tsvector('english', COALESCE(NEW.model, '')), 'C') ||
        setweight(to_tsvector('english', COALESCE(NEW.description, '')), 'D');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER assets_search_update
BEFORE INSERT OR UPDATE ON assets
FOR EACH ROW EXECUTE FUNCTION assets_search_trigger();
```

**Valid Status Values:**
- Available: Asset not assigned, ready for use
- Active: Asset assigned and in use
- Under Maintenance: Currently being repaired/serviced
- Checked Out: Temporarily checked out (like from pool)
- Disposed: Asset disposed/written off
- Damaged: Damaged beyond economical repair
- Lost: Asset lost/missing
- Stolen: Asset stolen (police report filed)

**Asset Code Format:** {CATEGORY}-{YEAR}-{NUMBER}
- Example: LAP-2025-0001, DSK-2025-0012

**QR Code Data Format:**
```json
{
  "assetCode": "LAP-2025-0001",
  "assetId": "uuid",
  "tenantId": "uuid",
  "url": "https://{tenant}.assetica.io/scan/LAP-2025-0001"
}
```

---

### Table: asset_documents
```sql
CREATE TABLE asset_documents (
    document_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    asset_id UUID REFERENCES assets(asset_id) ON DELETE CASCADE,
    document_type VARCHAR(50) NOT NULL,
    document_name VARCHAR(200) NOT NULL,
    file_url VARCHAR(500) NOT NULL,
    file_size_kb INTEGER,
    file_type VARCHAR(50),
    uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    uploaded_by UUID REFERENCES users(user_id)
);

CREATE INDEX idx_asset_docs_asset ON asset_documents(asset_id);
CREATE INDEX idx_asset_docs_type ON asset_documents(document_type);
```

**Valid Document Types:**
- Invoice: Purchase invoice
- Warranty: Warranty certificate
- Insurance: Insurance document
- Manual: User manual/guide
- ServiceReport: Service/maintenance report
- Photo: Asset photo
- Other: Any other document

**File Upload Requirements:**
- Maximum file size: 10 MB per file
- Maximum files per asset: 20
- Allowed types: PDF, DOC, DOCX, XLS, XLSX, JPG, JPEG, PNG, GIF
- Storage: AWS S3 or Azure Blob Storage
- URL format: https://{bucket}/{tenantId}/{year}/{month}/{filename}

---

### Table: asset_images
```sql
CREATE TABLE asset_images (
    image_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    asset_id UUID REFERENCES assets(asset_id) ON DELETE CASCADE,
    image_url VARCHAR(500) NOT NULL,
    thumbnail_url VARCHAR(500),
    is_primary BOOLEAN DEFAULT false,
    display_order INTEGER,
    uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    uploaded_by UUID REFERENCES users(user_id)
);

CREATE INDEX idx_asset_images_asset ON asset_images(asset_id);
CREATE INDEX idx_asset_images_primary ON asset_images(asset_id, is_primary) WHERE is_primary = true;
```

**Image Requirements:**
- Maximum size: 5 MB per image
- Maximum images per asset: 10
- Formats: JPG, JPEG, PNG, GIF
- Thumbnail generation: 200x200 pixels
- Primary image: Used in listings and cards
- Display order: For gallery view

---

## API Endpoints

### Asset Category APIs

#### GET /api/asset-categories
**Purpose:** List all categories

**Query Parameters:**
- `includeInactive`: boolean (default: false)
- `page`, `pageSize`: Pagination

**Response:**
```json
{
  "items": [
    {
      "categoryId": "uuid",
      "categoryName": "string",
      "categoryCode": "string",
      "description": "string",
      "depreciationRate": number,
      "depreciationMethod": "string",
      "usefulLifeYears": number,
      "isSystemDefined": boolean,
      "assetCount": number
    }
  ]
}
```

**Access:** All authenticated users

---

#### POST /api/asset-categories
**Purpose:** Create new category

**Request:**
```json
{
  "categoryName": "string",
  "categoryCode": "string (max 20 chars, uppercase, alphanumeric)",
  "description": "string",
  "depreciationRate": number,
  "depreciationMethod": "string (SLM/WDV/NA)",
  "usefulLifeYears": number
}
```

**Business Rules:**
- Category code must be unique
- Cannot modify system-defined categories
- If depreciation method is SLM, rate is calculated from useful life
- If depreciation method is WDV, rate must be provided

**Access:** TenantAdmin, ITTeam

---

#### GET /api/asset-categories/{id}
**Purpose:** Get category details with custom fields

**Response:** Category details + array of custom fields

---

#### PUT /api/asset-categories/{id}
**Purpose:** Update category

**Business Rules:**
- Cannot update if assets exist (only description can be updated)
- Cannot update system-defined categories
- Changing depreciation settings affects only new assets

---

#### DELETE /api/asset-categories/{id}
**Purpose:** Soft delete category (set inactive)

**Business Rules:**
- Cannot delete if assets exist
- Cannot delete system-defined categories

---

### Custom Fields APIs

#### GET /api/asset-categories/{categoryId}/custom-fields
**Purpose:** Get all custom fields for a category

---

#### POST /api/asset-categories/{categoryId}/custom-fields
**Purpose:** Add custom field to category

**Request:**
```json
{
  "fieldName": "string (camelCase, no spaces)",
  "fieldLabel": "string (display label)",
  "fieldType": "string (text/number/dropdown/etc)",
  "options": {
    "values": ["option1", "option2"]
  },
  "isMandatory": boolean,
  "displayOrder": number
}
```

**Business Rules:**
- Field name must be unique within category
- Options required for dropdown/multiselect types
- Display order auto-assigned if not provided

---

#### PUT /api/asset-categories/{categoryId}/custom-fields/{id}
**Purpose:** Update custom field

**Business Rules:**
- Cannot change field type if assets have data
- Can modify options, labels, mandatory status

---

#### DELETE /api/asset-categories/{categoryId}/custom-fields/{id}
**Purpose:** Soft delete custom field

**Business Rules:**
- Marks as inactive
- Existing asset data preserved
- Field hidden in forms

---

### Vendor APIs

#### GET /api/vendors
**Purpose:** List all vendors

**Query Parameters:**
- `search`: string
- `isActive`: boolean
- `page`, `pageSize`: Pagination

---

#### POST /api/vendors
**Purpose:** Create vendor

**Request:**
```json
{
  "vendorName": "string",
  "contactPerson": "string",
  "email": "string",
  "phone": "string",
  "address": "string",
  "city": "string",
  "state": "string",
  "country": "string",
  "postalCode": "string",
  "gstNumber": "string",
  "panNumber": "string",
  "website": "string"
}
```

**Business Rules:**
- Auto-generate vendor code: VEN-{YEAR}-{####}
- Validate email format
- Validate GST/PAN format (if India)

---

#### GET /api/vendors/{id}
#### PUT /api/vendors/{id}
#### DELETE /api/vendors/{id} (soft delete)

---

### Asset Management APIs

#### POST /api/assets/generate-code
**Purpose:** Generate next available asset code for category

**Request:**
```json
{
  "categoryId": "uuid"
}
```

**Response:**
```json
{
  "assetCode": "LAP-2025-0042"
}
```

**Implementation:**
1. Lock row in asset_code_sequences
2. Get and increment last_number
3. Return formatted code
4. Rollback if transaction fails

---

#### POST /api/assets
**Purpose:** Create new asset

**Request:**
```json
{
  "assetName": "string",
  "categoryId": "uuid",
  "serialNumber": "string",
  "macAddress": "string",
  "model": "string",
  "brand": "string",
  "purchaseCost": number,
  "purchaseDate": "date",
  "invoiceNumber": "string",
  "vendorId": "uuid",
  "warrantyMonths": number,
  "location": "string",
  "department": "string",
  "salvageValue": number,
  "description": "string",
  "notes": "string",
  "customFields": {
    "fieldName": "value"
  }
}
```

**Business Rules:**
- Generate asset code using sequence table with row lock
- Serial number must be unique if provided
- Create depreciation schedule automatically if category has depreciation
- Set current_book_value = purchase_cost initially
- Calculate warranty_expiry_date from purchase_date + warranty_months
- Generate and store QR code
- Set initial status = 'Available'
- Validate custom fields match category definition

**Response:**
```json
{
  "assetId": "uuid",
  "assetCode": "string",
  "qrCodeUrl": "string",
  "message": "Asset created successfully"
}
```

**Access:** TenantAdmin, ITTeam, Manager (with approval)

---

#### GET /api/assets
**Purpose:** List assets with advanced filtering

**Query Parameters:**
- `page`: integer (default: 1)
- `pageSize`: integer (default: 25)
- `search`: string (searches code, name, serial, brand, model)
- `categoryIds`: array of UUIDs
- `statuses`: array of strings
- `location`: string
- `department`: string
- `purchaseDateFrom`: date
- `purchaseDateTo`: date
- `costMin`: number
- `costMax`: number
- `sortBy`: string (CreatedAt, AssetCode, PurchaseCost, etc.)
- `sortOrder`: string (ASC/DESC)

**Response:** Paginated list with assets

**Performance:** Use indexes on category, status, department

---

#### GET /api/assets/{id}
**Purpose:** Get complete asset details

**Response:**
```json
{
  "asset": {
    "assetId": "uuid",
    "assetCode": "string",
    "assetName": "string",
    "category": { },
    "serialNumber": "string",
    "model": "string",
    "brand": "string",
    "purchaseCost": number,
    "currentBookValue": number,
    "purchaseDate": "date",
    "vendor": { },
    "warrantyExpiryDate": "date",
    "location": "string",
    "department": "string",
    "currentStatus": "string",
    "customFields": { },
    "qrCodeUrl": "string",
    "description": "string",
    "notes": "string"
  },
  "images": [ ],
  "documents": [ ],
  "assignmentInfo": {
    "isAssigned": boolean,
    "assignedTo": "string",
    "assignedDate": "date"
  }
}
```

---

#### PUT /api/assets/{id}
**Purpose:** Update asset

**Business Rules:**
- Cannot change asset code
- Cannot change category if assigned
- Serial number uniqueness check
- Update search_vector on change
- Log changes in audit_logs

---

#### DELETE /api/assets/{id}
**Purpose:** Soft delete asset

**Business Rules:**
- Can only delete if status is 'Available' or 'Damaged'
- Cannot delete if assigned
- Cannot delete if has active maintenance
- Sets is_active = false

---

#### POST /api/assets/{id}/images
**Purpose:** Upload asset images

**Request:** Multipart form data

**Business Rules:**
- Max 5 MB per image
- Max 10 images per asset
- Generate thumbnail (200x200)
- Store in cloud storage
- First image becomes primary automatically

---

#### DELETE /api/assets/{id}/images/{imageId}
**Purpose:** Delete asset image

**Business Rules:**
- Delete from cloud storage
- If deleting primary image, make first remaining image primary

---

#### POST /api/assets/{id}/documents
**Purpose:** Upload asset documents

**Request:** Multipart form data with document type

**Business Rules:**
- Max 10 MB per document
- Max 20 documents per asset
- Validate file type
- Scan for viruses (if available)
- Store in cloud storage with organized path

---

#### DELETE /api/assets/{id}/documents/{documentId}
**Purpose:** Delete asset document

---

#### GET /api/assets/{id}/qrcode
**Purpose:** Get QR code image

**Query Parameters:**
- `format`: string (png/svg, default: png)
- `size`: integer (pixels, default: 200)

**Response:** Image file (binary)

**QR Code Content:**
```
https://{tenant}.assetica.io/scan/{assetCode}
```

---

#### GET /api/assets/{id}/label
**Purpose:** Generate printable label (PDF) with QR code

**Response:** PDF file

**Label Format:**
```
┌─────────────────────┐
│   [QR CODE IMAGE]   │
│                     │
│   LAP-2025-0001     │
│ Dell Latitude 5420  │
│   Serial: ABC123    │
└─────────────────────┘
```

**Label Size:** 50mm x 25mm (standard asset tag size)

---

#### POST /api/assets/bulk-labels
**Purpose:** Generate labels for multiple assets

**Request:**
```json
{
  "assetIds": ["uuid1", "uuid2", "..."]
}
```

**Response:** PDF file with multiple labels (print-ready)

---

#### POST /api/assets/bulk-import
**Purpose:** Import assets from Excel/CSV

**Request:** Multipart form data

**Template Columns:**
- Asset Name*
- Category Code*
- Serial Number
- Model
- Brand
- Purchase Cost*
- Purchase Date*
- Invoice Number
- Vendor Code
- Warranty Months
- Location
- Department
- Description
- Custom field columns (dynamic based on category)

**Response:**
```json
{
  "totalRecords": integer,
  "successCount": integer,
  "errorCount": integer,
  "errors": [
    {
      "row": integer,
      "field": "string",
      "error": "string",
      "value": "string"
    }
  ],
  "importedAssetIds": ["uuid1", "uuid2"]
}
```

**Business Rules:**
- Validate all rows before import (no partial import)
- Check category code exists
- Check vendor code exists (if provided)
- Validate serial number uniqueness
- Validate custom field values
- Generate asset codes automatically
- Create depreciation schedules automatically
- Generate QR codes for all imported assets
- Maximum 500 rows per import

---

#### GET /api/assets/export
**Purpose:** Export assets to Excel

**Query Parameters:** Same as GET /api/assets (for filtering)

**Response:** Excel file

**Excel Format:**
- Sheet 1: Assets (main data)
- Sheet 2: Custom Fields (flattened)
- Sheet 3: Depreciation Summary
- Formatted with headers, colors, totals

---

### QR Code Scanning

#### GET /scan/{assetCode}
**Purpose:** Public endpoint for QR code scanning

**Access:** Anonymous (no auth required)

**Behavior:**
- If user logged in: Redirect to asset detail page
- If user not logged in: Show mobile-optimized asset information card

**Response (Not Logged In):**
```json
{
  "assetCode": "string",
  "assetName": "string",
  "category": "string",
  "serialNumber": "string",
  "location": "string",
  "status": "string",
  "message": "Log in to see more details or report issues"
}
```

---

### Dashboard APIs

#### GET /api/dashboard/summary
**Purpose:** Get overview statistics

**Response:**
```json
{
  "totalAssets": integer,
  "activeAssets": integer,
  "availableAssets": integer,
  "underMaintenance": integer,
  "totalValue": number,
  "totalBookValue": number,
  "assetsByStatus": {
    "Available": integer,
    "Active": integer,
    "Under Maintenance": integer
  }
}
```

---

#### GET /api/dashboard/asset-distribution
**Purpose:** Asset count by category

**Response:**
```json
{
  "categories": [
    {
      "categoryName": "string",
      "count": integer,
      "percentage": number
    }
  ]
}
```

---

#### GET /api/dashboard/asset-value-by-category
**Purpose:** Asset value by category (top 5)

**Response:**
```json
{
  "categories": [
    {
      "categoryName": "string",
      "totalValue": number,
      "bookValue": number,
      "assetCount": integer
    }
  ]
}
```

---

#### GET /api/dashboard/recent-assets
**Purpose:** Recently added assets (last 10)

---

#### GET /api/dashboard/warranty-expiring
**Purpose:** Assets with warranties expiring soon

**Query Parameters:**
- `days`: integer (default: 30)

---

## Frontend Pages & Components

### Category Management

#### 1. Category List Page (`/admin/categories`)
**Components:**
- Data table with categories
- Add Category button
- Edit, Delete actions
- Asset count per category
- Filter: Show inactive checkbox

---

#### 2. Category Form Page (`/admin/categories/new` or `/:id/edit`)
**Sections:**
- Basic Information
  - Category Name*
  - Category Code* (uppercase, alphanumeric)
  - Description
- Depreciation Settings
  - Method dropdown (SLM/WDV/NA)
  - Rate (auto-calculated for SLM, manual for WDV)
  - Useful Life (years)
- Custom Fields Manager
  - List of custom fields
  - Add/Edit/Delete field buttons
  - Drag to reorder

---

#### 3. Custom Field Modal
**Fields:**
- Field Name* (technical, camelCase)
- Field Label* (display label)
- Field Type* dropdown
- Options (if dropdown/multiselect)
- Mandatory checkbox
- Display Order

---

### Vendor Management

#### 1. Vendor List Page (`/vendors`)
**Features:**
- Data table
- Search by name, contact, email
- Filter: Active/Inactive
- Add Vendor button
- Export to Excel

---

#### 2. Vendor Form Page (`/vendors/new` or `/:id/edit`)
**Sections:**
- Basic Information
  - Vendor Name*
  - Contact Person
  - Email, Phone
- Address Information
  - Address, City, State, Country, Postal Code
- Tax Information (India-specific)
  - GST Number
  - PAN Number
- Additional
  - Website

---

### Asset Management

#### 1. Asset List Page (`/assets`)
**Layout:**
- Advanced filter panel (collapsible on left)
  - Category (multi-select with checkboxes)
  - Status (multi-select)
  - Location (dropdown)
  - Department (dropdown)
  - Purchase Date Range (date range picker)
  - Cost Range (min-max sliders)
- Main content area
  - Search bar (searches code, name, serial, brand, model)
  - View toggle: Table / Grid / Gallery
  - Sort dropdown
  - Action buttons: Add Asset, Bulk Import, Export, Print Labels
  - Results count

**Table Columns:**
- Asset Code (clickable)
- Thumbnail image
- Asset Name
- Category
- Serial Number
- Status (colored badge)
- Purchase Date
- Cost
- Current Value
- Location
- Actions dropdown

**Grid View:**
- Cards with image, code, name, status, quick actions

**Gallery View:**
- Large image cards for visual browsing

---

#### 2. Asset Registration Form (`/assets/new`)
**Multi-step wizard:**

**Step 1: Basic Information**
- Category Selection* (required first - determines custom fields)
- Asset Name*
- Serial Number (with uniqueness check)
- MAC Address (for network devices)
- Model
- Brand
- Description (textarea)

**Step 2: Financial Details**
- Purchase Cost*
- Purchase Date*
- Invoice Number
- Vendor (searchable dropdown)
- Salvage Value (optional, used in depreciation)

**Step 3: Warranty & Insurance**
- Warranty Months
- Warranty Provider
- Warranty Expiry Date (auto-calculated, can override)
- Insurance Policy Number
- Insurance Provider
- Insurance Expiry Date

**Step 4: Location & Department**
- Location* (dropdown with common locations, can add new)
- Department* (dropdown from employees table)
- Notes (textarea)

**Step 5: Custom Fields**
- Dynamic fields based on selected category
- Rendered according to field type
- Show help text/tooltips
- Validate mandatory fields

**Step 6: Images & Documents**
- Drag-and-drop area for images (up to 10)
- Mark primary image
- Document upload by type
- Preview uploaded files

**Step 7: Review & Submit**
- Summary of all entered data
- Edit buttons for each section
- Final submit button

**Features:**
- Save as draft functionality
- Step navigation (can go back)
- Validation per step
- Progress indicator

---

#### 3. Asset Detail Page (`/assets/:id`)
**Layout:** Tabs

**Tab 1: Overview**
- Asset image gallery (with primary image prominent)
- Asset information cards
  - Basic Info: Code, Name, Category, Serial, Status
  - Financial: Cost, Current Value, Depreciation
  - Location: Department, Location, Building
  - Warranty: Expiry date, status (Active/Expired)
- Quick actions: Edit, Assign, Transfer, Dispose, QR Code, Print Label

**Tab 2: Financial Details**
- Purchase information
- Depreciation summary
  - Current Book Value (prominent)
  - Accumulated Depreciation
  - Depreciation Rate & Method
  - Useful Life Remaining
- Link to detailed depreciation schedule

**Tab 3: Documents**
- Table with documents
  - Type, Name, Size, Uploaded By, Date, Actions
- Upload new document button
- View/Download actions

**Tab 4: Assignment History**
- Timeline of assignments
- Current assignment (if any)
- Total assignment duration

**Tab 5: Activity History**
- Complete audit trail
- Filter by action type
- Export history

---

#### 4. Bulk Import Page (`/assets/import`)
**Components:**
- Instructions card
  - Template format explanation
  - Custom fields note
- Download Template button (generates Excel with category-specific template)
- Category selection (to download appropriate template)
- File upload area
- Upload button
- Progress bar
- Validation results:
  - Success count (green)
  - Error count (red)
  - Error details table (row, field, error, value)
  - Download error report button
- Import button (after validation passes)

---

#### 5. QR Code & Labels

**QR Code Viewer Modal:**
- Large QR code display
- Asset code below
- Download as PNG/SVG buttons
- Print button

**Label Print Dialog:**
- Label size selection
- Quantity input
- Preview
- Print button

---

### Dashboard Updates

#### New Dashboard Widgets (Add to Phase 1 Dashboard)

**1. Asset Summary Cards (Grid - 4 columns)**
- Total Assets (icon: briefcase)
  - Count, trend arrow
- Active Assets (icon: check-circle)
  - Count, percentage of total
- Available Assets (icon: package)
  - Count, ready to assign
- Under Maintenance (icon: wrench)
  - Count, attention needed

**2. Asset Distribution Chart (Pie/Donut)**
- Category-wise distribution
- Interactive (click to filter)
- Legend with counts

**3. Asset Value Chart (Bar Chart)**
- Top 5 categories by value
- Purchase Cost vs Current Value
- Depreciation visible

**4. Department-wise Assets (Bar Chart)**
- Horizontal bars
- Assets per department
- Clickable

**5. Recent Assets Widget (List/Cards)**
- Last 10 added assets
- Thumbnail, code, name, category
- Quick link to view

**6. Warranty Alerts**
- Assets with warranties expiring in 30 days
- Count badge
- List with expiry dates

---

## File Upload & Storage

### Requirements

**Backend Storage Service Interface:**
- `UploadAsync(fileName, fileData, contentType)` → returns URL
- `DownloadAsync(fileUrl)` → returns byte array
- `DeleteAsync(fileUrl)` → returns boolean
- `GetSizeAsync(fileUrl)` → returns size in bytes

**Implementation Options:**
1. AWS S3
2. Azure Blob Storage
3. Google Cloud Storage
4. Local file system (dev only)

**Storage Structure:**
```
/{tenantId}/
  /assets/
    /images/{year}/{month}/{assetId}/
      image1.jpg
      image1_thumb.jpg
    /documents/{year}/{month}/{assetId}/
      invoice.pdf
      warranty.pdf
```

**Security:**
- Generate signed URLs with expiration (1 hour)
- Validate file types (whitelist)
- Scan for malware (ClamAV or cloud service)
- Check file size before upload
- Restrict direct access (CDN with auth)

---

### Frontend Upload Component

**Features:**
- Drag and drop
- Click to browse
- Multiple file selection
- File type filtering
- Size validation
- Upload progress bar
- Preview before upload
- Remove file from queue
- Retry failed uploads

**States:**
- Idle
- Validating
- Uploading
- Success
- Error

---

## Search & Filter Implementation

### Full-Text Search

**Backend Implementation:**
- Use PostgreSQL full-text search (tsvector)
- Index on: asset_code, asset_name, serial_number, brand, model, description
- Weighted search (asset_code highest priority)

**Query Example:**
```sql
SELECT * FROM assets 
WHERE search_vector @@ plainto_tsquery('english', 'laptop dell')
ORDER BY ts_rank(search_vector, plainto_tsquery('english', 'laptop dell')) DESC;
```

---

### Advanced Filters

**Filter Request Object:**
```json
{
  "categoryIds": ["uuid1", "uuid2"],
  "statuses": ["Available", "Active"],
  "location": "string",
  "department": "string",
  "purchaseDateFrom": "date",
  "purchaseDateTo": "date",
  "costMin": number,
  "costMax": number,
  "warrantyExpiringInDays": number,
  "searchTerm": "string",
  "page": 1,
  "pageSize": 25,
  "sortBy": "CreatedAt",
  "sortOrder": "DESC"
}
```

**Backend Processing:**
1. Build base query
2. Apply each filter with AND condition
3. Apply search term with full-text search
4. Get total count (for pagination)
5. Apply sorting
6. Apply pagination (OFFSET and LIMIT)
7. Include related data (Category, Vendor)

---

## Business Rules Summary

### Asset Creation
1. ✅ Generate unique asset code using sequence table with row lock
2. ✅ Validate serial number uniqueness within tenant
3. ✅ Auto-create depreciation schedule if category has depreciation settings
4. ✅ Set initial current_book_value = purchase_cost
5. ✅ Calculate warranty_expiry_date from purchase_date + warranty_months
6. ✅ Generate and store QR code immediately
7. ✅ Set initial status = 'Available'
8. ✅ Validate all custom fields according to category definition
9. ✅ Log creation in audit_logs

### Asset Code Generation
1. ✅ Use database sequence table with row-level locking (prevents race conditions)
2. ✅ Format: {CATEGORY}-{YEAR}-{NUMBER}
3. ✅ Number padded to 4 digits: 0001, 0002, etc.
4. ✅ Sequence resets each year per category
5. ✅ Transaction must rollback if asset creation fails

### Asset Updates
1. ✅ Cannot change asset code (immutable)
2. ✅ Cannot change category if asset is assigned
3. ✅ Update search_vector on any text field change
4. ✅ Log all changes with old and new values
5. ✅ Update updated_at timestamp

### Asset Deletion
1. ✅ Soft delete only (set is_active = false)
2. ✅ Can only delete if status is 'Available' or 'Damaged'
3. ✅ Cannot delete if currently assigned
4. ✅ Cannot delete if has active maintenance
5. ✅ Do not delete from depreciation schedules (for records)

### Custom Fields
1. ✅ Stored as JSONB in assets table
2. ✅ Validated against category's custom field definitions
3. ✅ Mandatory fields must have values
4. ✅ Dropdown fields must match allowed options
5. ✅ Number fields validated as numeric
6. ✅ Date fields validated as dates

### File Uploads
1. ✅ Maximum file sizes enforced
2. ✅ Maximum file counts enforced
3. ✅ Only allowed file types accepted
4. ✅ Virus scanning if available
5. ✅ Generate thumbnails for images
6. ✅ Store in tenant-specific folder structure
7. ✅ Use signed URLs with expiration
8. ✅ Delete from storage when record deleted

### QR Codes
1. ✅ Generated immediately on asset creation
2. ✅ URL format: https://{tenant}.assetica.io/scan/{assetCode}
3. ✅ QR code data includes asset ID and tenant ID
4. ✅ Publicly accessible (no auth required for scan)
5. ✅ Redirect logged-in users to asset detail
6. ✅ Show limited info to non-logged-in users

---

## Phase 2 Acceptance Criteria

### Database
- [ ] All asset-related tables created with proper constraints
- [ ] asset_code_sequences table created for race condition prevention
- [ ] Default categories populated
- [ ] Proper indexes on all key columns
- [ ] Full-text search indexes created
- [ ] Triggers for search_vector updates working
- [ ] Foreign key constraints working

### Backend
- [ ] All Phase 2 API endpoints functional
- [ ] Asset code generation with row locking working (no duplicates)
- [ ] Depreciation schedule auto-creation working
- [ ] QR code generation and storage working
- [ ] File upload to cloud storage working
- [ ] Search and filtering with pagination working
- [ ] Full-text search working with ranking
- [ ] Bulk operations (import/export) working
- [ ] Document and image upload working
- [ ] API documentation (Swagger) updated

### Frontend
- [ ] Asset registration multi-step form complete with validation
- [ ] Asset list with advanced filters and search working
- [ ] Grid and gallery views implemented
- [ ] Asset detail page with all tabs working
- [ ] Category management pages complete
- [ ] Vendor management pages complete
- [ ] QR code display and download working
- [ ] Label generation and printing working
- [ ] File upload components working
- [ ] Bulk import with validation and error reporting
- [ ] Dashboard widgets showing asset data
- [ ] Mobile-responsive design

### Business Logic
- [ ] Asset code follows format and increments correctly
- [ ] No race conditions in asset code generation
- [ ] Serial number uniqueness enforced
- [ ] Cannot create asset without required fields
- [ ] Custom fields render dynamically based on category
- [ ] Depreciation schedules created automatically
- [ ] QR codes are publicly accessible
- [ ] File size and type restrictions enforced

### Testing
- [ ] Create 50 test assets across all categories
- [ ] Test asset code generation under concurrent load (no duplicates)
- [ ] Verify QR codes work and resolve correctly
- [ ] Test bulk import with 100 records
- [ ] Test bulk import with errors (validation)
- [ ] Verify search returns correct results (full-text)
- [ ] Test file upload limits (size and count)
- [ ] Test image thumbnail generation
- [ ] Verify depreciation schedules created correctly
- [ ] Test all filters and their combinations
- [ ] Performance test with 10,000 assets
- [ ] Mobile responsive testing

### Performance
- [ ] Asset list loads in < 2 seconds with 1000+ assets
- [ ] Search returns results in < 1 second
- [ ] File upload progress tracked accurately
- [ ] QR code generation in < 500ms
- [ ] Dashboard widgets load in < 1 second

---

## Next Phase Preview

**Phase 3** will implement:
- Asset assignment to employees
- Asset transfer workflow with multi-level approvals
- Check-in/Check-out functionality
- Email notification system
- Assignment history tracking
- Employee asset dashboard

**Dependencies from Phase 2:**
- Asset registration ✓
- Asset categories ✓
- QR code system ✓
- Employee data (from Phase 1) ✓

---

## Critical Notes for Implementation

### Asset Code Generation
**CRITICAL:** Use row-level locking to prevent race conditions:
1. Start transaction
2. Lock sequence row: `FOR UPDATE`
3. Get and increment counter
4. Create asset with new code
5. Commit transaction
6. If any step fails, rollback entire transaction

### Depreciation Schedule
**AUTO-CREATE:** When asset is created:
1. Check if category has depreciation settings
2. If yes, create depreciation_schedule record
3. Link to asset
4. Copy depreciation settings from category
5. Set start_date = purchase_date

### QR Code URLs
**FORMAT:** Always use pattern:
```
https://{tenant-subdomain}.assetica.io/scan/{asset-code}
```

**ENDPOINT:** Create public scan endpoint:
- No authentication required
- Resolve asset by code
- Show appropriate view based on auth status

### File Storage
**ORGANIZATION:**
- Keep tenant data separate
- Organize by year/month for easier management
- Use UUIDs in filenames to avoid conflicts
- Generate thumbnails for images
- Clean up orphaned files periodically

### Full-Text Search
**IMPLEMENTATION:**
- Update search_vector trigger on every text change
- Use weighted search (asset code most important)
- Rank results by relevance
- Support partial matches
- Consider fuzzy matching for typos

---

**End of Phase 2 Documentation**

**IMPLEMENTATION CHECKLIST:**
- ✅ Implement sequence table for asset codes
- ✅ Build asset registration with auto-depreciation schedule
- ✅ Implement QR code generation and scanning
- ✅ Set up file upload with cloud storage
- ✅ Implement full-text search
- ✅ Build category and vendor management
- ✅ Create advanced filtering system
- ✅ Test concurrent asset creation (no duplicates)
- ✅ Deploy and test in staging

**READY TO PROCEED TO PHASE 3:** Only after all acceptance criteria are met and race conditions are verified as fixed.
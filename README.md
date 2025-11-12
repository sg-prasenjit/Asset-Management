# Assetica - Multi-Tenant SaaS Asset Management Platform

**Comprehensive Asset Management Solution for IT Organizations**

[![.NET Core](https://img.shields.io/badge/.NET%20Core-8.0-purple)](https://dotnet.microsoft.com/)
[![Angular](https://img.shields.io/badge/Angular-16+-red)](https://angular.io/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15+-blue)](https://www.postgresql.org/)
[![License](https://img.shields.io/badge/license-Proprietary-green)](./LICENSE)

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Technology Stack](#technology-stack)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
- [Development Phases](#development-phases)
- [Architecture](#architecture)
- [API Documentation](#api-documentation)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

**Assetica** is a modern, cloud-based asset management platform designed to streamline the complete lifecycle of organizational assets. Built on a robust multi-tenant SaaS architecture, Assetica empowers IT organizations to efficiently register, track, maintain, and optimize their physical and digital assets.

### Vision
To be the most intuitive and comprehensive asset management solution that transforms how organizations manage their resources.

### Mission
Deliver a seamless, secure, and scalable platform that provides complete visibility and control over asset lifecycles, enabling data-driven decisions and operational excellence.

---

## Features

### Phase 1: Foundation & Multi-Tenant Setup ✅
- Multi-tenant database architecture with complete data isolation
- JWT-based authentication with refresh tokens
- Role-Based Access Control (RBAC)
- User and employee management
- Comprehensive audit logging
- Session management with timeout
- Tenant management for Super Admin

### Phase 2: Asset Registration & Core Management ✅
- Asset registration with auto-generated codes
- QR code generation and printing
- Category management with custom fields
- Vendor management
- Document and image uploads with cloud storage
- Advanced search and filtering
- Bulk import/export operations
- Asset inventory dashboard

### Phase 3: Asset Operations & Tracking ✅
- Asset assignment and unassignment
- Multi-level transfer approval workflow
- Check-in/check-out tracking
- Email notification system
- Activity timeline and history
- Employee asset dashboard
- Overdue tracking and alerts

### Phase 4: Financial Management & Maintenance ✅
- Automated depreciation calculation (SLM & WDV methods)
- Software license tracking and allocation
- Maintenance request and tracking
- Warranty and AMC contract management
- Budget tracking with alerts
- Asset disposal workflow
- Financial reports and dashboards

### Phase 5: Reporting, Mobile & System Polish ✅
- Comprehensive reporting suite (10+ standard reports)
- Mobile Progressive Web App (PWA)
- QR code scanning via mobile
- Advanced analytics with interactive charts
- Scheduled report generation
- Performance optimization
- Production deployment readiness

---

## Technology Stack

### Backend
- **Framework**: .NET Core 8.0 (ASP.NET Core Web API)
- **Language**: C# 12
- **Database**: PostgreSQL 15+
- **ORM**: Entity Framework Core
- **Background Jobs**: Hangfire
- **Authentication**: JWT (JSON Web Tokens)
- **Documentation**: Swagger/OpenAPI
- **Caching**: Redis (optional)

### Frontend
- **Framework**: Angular 16+
- **Language**: TypeScript 5+
- **UI Components**: Angular Material / PrimeNG
- **State Management**: RxJS / NgRx
- **Charts**: Chart.js / ApexCharts
- **PWA**: Angular Service Worker
- **Mobile**: Progressive Web App (PWA)

### Cloud Infrastructure
- **Primary**: AWS (S3, EC2, RDS)
- **Alternative**: Azure (Blob Storage, App Service, SQL Database)
- **Storage**: AWS S3 / Azure Blob Storage
- **Email**: SendGrid / AWS SES

### DevOps
- **Version Control**: Git
- **CI/CD**: GitHub Actions / Azure DevOps
- **Containerization**: Docker
- **Orchestration**: Kubernetes (optional for enterprise)

---

## Project Structure

```
assetica/
├── backend/                          # .NET Core Backend
│   ├── Assetica.API/                # Web API Project
│   │   ├── Controllers/             # API Controllers
│   │   ├── Middleware/              # Custom Middleware
│   │   ├── Filters/                 # Action Filters
│   │   └── Program.cs               # Application Entry Point
│   ├── Assetica.Core/               # Core Business Logic
│   │   ├── Entities/                # Domain Entities
│   │   ├── Interfaces/              # Repository Interfaces
│   │   ├── Services/                # Business Services
│   │   ├── DTOs/                    # Data Transfer Objects
│   │   └── Enums/                   # Enumerations
│   ├── Assetica.Infrastructure/     # Data Access & External Services
│   │   ├── Data/                    # Database Contexts
│   │   ├── Repositories/            # Repository Implementations
│   │   ├── Migrations/              # EF Core Migrations
│   │   └── Services/                # Infrastructure Services
│   └── Assetica.Tests/              # Unit & Integration Tests
│       ├── Unit/                    # Unit Tests
│       └── Integration/             # Integration Tests
│
├── frontend/                         # Angular Frontend
│   ├── src/
│   │   ├── app/
│   │   │   ├── core/                # Core Services & Guards
│   │   │   │   ├── auth/            # Authentication
│   │   │   │   ├── guards/          # Route Guards
│   │   │   │   └── interceptors/    # HTTP Interceptors
│   │   │   ├── shared/              # Shared Components & Modules
│   │   │   │   ├── components/      # Reusable Components
│   │   │   │   ├── directives/      # Custom Directives
│   │   │   │   └── pipes/           # Custom Pipes
│   │   │   ├── features/            # Feature Modules
│   │   │   │   ├── auth/            # Authentication Module
│   │   │   │   ├── assets/          # Asset Management Module
│   │   │   │   ├── employees/       # Employee Module
│   │   │   │   ├── maintenance/     # Maintenance Module
│   │   │   │   ├── reports/         # Reports Module
│   │   │   │   └── admin/           # Admin Module
│   │   │   ├── models/              # TypeScript Models
│   │   │   ├── services/            # Business Services
│   │   │   └── app.component.ts     # Root Component
│   │   ├── assets/                  # Static Assets
│   │   ├── environments/            # Environment Configs
│   │   └── styles/                  # Global Styles
│   ├── angular.json                 # Angular Configuration
│   ├── package.json                 # NPM Dependencies
│   └── tsconfig.json                # TypeScript Configuration
│
├── database/                         # Database Scripts
│   ├── migrations/                  # Phase-wise Migrations
│   │   ├── phase1/                  # Phase 1 Migrations
│   │   ├── phase2/                  # Phase 2 Migrations
│   │   ├── phase3/                  # Phase 3 Migrations
│   │   ├── phase4/                  # Phase 4 Migrations
│   │   └── phase5/                  # Phase 5 Migrations
│   ├── scripts/                     # Utility Scripts
│   └── seed-data/                   # Seed Data Scripts
│
├── docs/                            # Documentation
│   ├── api/                         # API Documentation
│   ├── architecture/                # Architecture Diagrams
│   ├── deployment/                  # Deployment Guides
│   └── user-guides/                 # User Guides
│
├── frd_asset_mgmt.md               # Functional Requirements Document
├── PHASE_1_DOCUMENTATION.md        # Phase 1 Implementation Guide
├── PHASE_2_DOCUMENTATION.md        # Phase 2 Implementation Guide
├── PHASE_3_DOCUMENTATION.md        # Phase 3 Implementation Guide
├── PHASE_4_DOCUMENTATION.md        # Phase 4 Implementation Guide
├── PHASE_5_DOCUMENTATION.md        # Phase 5 Implementation Guide
├── README.md                       # This File
├── .gitignore                      # Git Ignore Rules
└── docker-compose.yml              # Docker Compose Configuration
```

---

## Getting Started

### Prerequisites

#### Required Software
- **.NET SDK 8.0+**: [Download](https://dotnet.microsoft.com/download)
- **Node.js 18+ and npm**: [Download](https://nodejs.org/)
- **Angular CLI**: `npm install -g @angular/cli`
- **PostgreSQL 15+**: [Download](https://www.postgresql.org/download/)
- **Git**: [Download](https://git-scm.com/)

#### Optional
- **Docker**: [Download](https://www.docker.com/)
- **Visual Studio 2022** or **Visual Studio Code**
- **pgAdmin** or **DBeaver** for database management

### Installation

#### 1. Clone the Repository
```bash
git clone https://github.com/your-org/assetica.git
cd assetica
```

#### 2. Backend Setup

```bash
cd backend

# Restore NuGet packages
dotnet restore

# Update database connection strings
# Edit: Assetica.API/appsettings.Development.json

# Run database migrations
dotnet ef database update --project Assetica.Infrastructure --startup-project Assetica.API

# Run the API
cd Assetica.API
dotnet run
```

The API will be available at: `https://localhost:5001`

#### 3. Frontend Setup

```bash
cd frontend

# Install npm packages
npm install

# Update API URL
# Edit: src/environments/environment.ts

# Run the Angular application
ng serve
```

The application will be available at: `http://localhost:4200`

#### 4. Database Setup

```bash
# Create databases
psql -U postgres

CREATE DATABASE assetica_auth;
CREATE DATABASE assetica_tenant_demo;
CREATE DATABASE assetica_hangfire;

\q

# Run migration scripts
cd database/migrations/phase1
psql -U postgres -d assetica_auth -f 001_create_tenants.sql
psql -U postgres -d assetica_tenant_demo -f 002_create_users.sql
# ... continue with other scripts
```

#### 5. Seed Initial Data

```bash
cd database/seed-data
psql -U postgres -d assetica_tenant_demo -f seed_categories.sql
psql -U postgres -d assetica_tenant_demo -f seed_admin_user.sql
```

---

## Development Phases

The project is developed in **5 phases**, each building upon the previous:

### Phase 1: Foundation & Multi-Tenant Setup (Weeks 1-4)
**Status**: ✅ Complete
**Focus**: Multi-tenant architecture, authentication, user management

### Phase 2: Asset Registration & Core Management (Weeks 5-9)
**Status**: ✅ Complete
**Focus**: Asset CRUD, QR codes, search, bulk operations

### Phase 3: Asset Operations & Tracking (Weeks 10-14)
**Status**: ✅ Complete
**Focus**: Assignments, transfers, check-in/out, notifications

### Phase 4: Financial Management & Maintenance (Weeks 15-19)
**Status**: ✅ Complete
**Focus**: Depreciation, licenses, maintenance, budgets

### Phase 5: Reporting, Mobile & Polish (Weeks 20-24)
**Status**: ✅ Complete
**Focus**: Reports, PWA, analytics, optimization

**Total Duration**: 24 weeks (6 months)

---

## Architecture

### Multi-Tenant Architecture

Assetica uses a **Database-per-Tenant** model for complete data isolation:

```
┌─────────────────────────────────────────────┐
│         Assetica Platform                   │
├─────────────────────────────────────────────┤
│  Shared Authentication Database             │
│  - tenants                                  │
│  - tenant_subscriptions                     │
└─────────────────────────────────────────────┘
                    │
        ┌───────────┴───────────┐
        ▼                       ▼
┌───────────────┐       ┌───────────────┐
│ Tenant A DB   │       │ Tenant B DB   │
│ - users       │       │ - users       │
│ - employees   │       │ - employees   │
│ - assets      │       │ - assets      │
│ - ...         │       │ - ...         │
└───────────────┘       └───────────────┘
```

### Request Flow

```
User Request
    │
    ▼
[Tenant Resolution Middleware]  ← Extract subdomain
    │
    ▼
[Authentication Middleware]     ← Validate JWT
    │
    ▼
[Authorization Middleware]      ← Check permissions
    │
    ▼
[Controller]                    ← Handle request
    │
    ▼
[Service Layer]                 ← Business logic
    │
    ▼
[Repository]                    ← Data access
    │
    ▼
[Tenant Database]               ← PostgreSQL
```

### Key Design Patterns

- **Repository Pattern**: Data access abstraction
- **Unit of Work**: Transaction management
- **Dependency Injection**: Loose coupling
- **CQRS**: Command Query Responsibility Segregation (partial)
- **Mediator Pattern**: Request handling (using MediatR)

---

## API Documentation

### Base URL
```
Development: https://localhost:5001/api
Production: https://api.assetica.io/api
```

### Authentication
All API endpoints (except login and QR scan) require JWT authentication:

```bash
Authorization: Bearer {access_token}
```

### Key Endpoints

#### Authentication
- `POST /api/auth/login` - User login
- `POST /api/auth/refresh-token` - Refresh access token
- `POST /api/auth/logout` - Logout
- `POST /api/auth/forgot-password` - Initiate password reset
- `POST /api/auth/reset-password` - Complete password reset

#### Users
- `GET /api/users` - List users
- `POST /api/users` - Create user
- `GET /api/users/{id}` - Get user details
- `PUT /api/users/{id}` - Update user
- `DELETE /api/users/{id}` - Deactivate user

#### Assets
- `GET /api/assets` - List assets with filters
- `POST /api/assets` - Create asset
- `GET /api/assets/{id}` - Get asset details
- `PUT /api/assets/{id}` - Update asset
- `DELETE /api/assets/{id}` - Soft delete asset
- `POST /api/assets/bulk-import` - Bulk import
- `GET /api/assets/export` - Export to Excel

#### Assignments
- `POST /api/assignments` - Assign asset to employee
- `POST /api/assignments/{id}/return` - Return asset
- `GET /api/assignments/employee/{id}` - Get employee assets

#### Transfers
- `POST /api/transfers` - Initiate transfer request
- `POST /api/transfers/{id}/approve` - Approve transfer
- `POST /api/transfers/{id}/reject` - Reject transfer
- `GET /api/transfers/pending` - Get pending approvals

### Swagger Documentation
Interactive API documentation is available at:
```
https://localhost:5001/swagger
```

---

## Configuration

### Backend Configuration (`appsettings.json`)

```json
{
  "ConnectionStrings": {
    "AuthDatabase": "Host=localhost;Database=assetica_auth;Username=postgres;Password=your_password",
    "TenantDatabaseTemplate": "Host=localhost;Database=assetica_tenant_{0};Username=postgres;Password=your_password",
    "HangfireConnection": "Host=localhost;Database=assetica_hangfire;Username=postgres;Password=your_password"
  },
  "JwtSettings": {
    "Secret": "your-super-secret-key-minimum-32-characters-long",
    "Issuer": "https://api.assetica.io",
    "Audience": "https://assetica.io",
    "ExpiryMinutes": 60,
    "RefreshTokenExpiryDays": 7
  },
  "TenantSettings": {
    "IdentificationMode": "Subdomain",
    "DefaultTenant": "demo"
  },
  "CloudStorage": {
    "Provider": "AWS",
    "AWS": {
      "AccessKey": "your-access-key",
      "SecretKey": "your-secret-key",
      "BucketName": "assetica-assets",
      "Region": "us-east-1"
    }
  },
  "Email": {
    "Provider": "SendGrid",
    "SendGrid": {
      "ApiKey": "your-sendgrid-api-key",
      "FromEmail": "noreply@assetica.io",
      "FromName": "Assetica"
    }
  }
}
```

### Frontend Configuration (`environment.ts`)

```typescript
export const environment = {
  production: false,
  apiUrl: 'https://localhost:5001/api',
  tenantMode: 'subdomain',
  sessionTimeout: 30 * 60 * 1000, // 30 minutes
  tokenRefreshThreshold: 5 * 60 * 1000, // 5 minutes
  maxFileSize: 10 * 1024 * 1024, // 10 MB
  allowedFileTypes: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'jpg', 'jpeg', 'png']
};
```

---

## Testing

### Backend Tests

```bash
cd backend
dotnet test
```

### Frontend Tests

```bash
cd frontend

# Unit tests
ng test

# E2E tests
ng e2e

# Code coverage
ng test --code-coverage
```

---

## Deployment

### Docker Deployment

```bash
# Build and run all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

### Manual Deployment

Refer to `docs/deployment/` for detailed deployment guides:
- AWS Deployment Guide
- Azure Deployment Guide
- On-Premise Deployment Guide

---

## Security

### Authentication & Authorization
- JWT tokens with 1-hour expiry
- Refresh tokens with 7-day expiry
- Role-Based Access Control (RBAC)
- Session management with timeout

### Password Policy
- Minimum 8 characters
- At least 1 uppercase letter
- At least 1 lowercase letter
- At least 1 number
- At least 1 special character
- BCrypt hashing with cost factor 12

### Data Security
- TLS 1.3 for data in transit
- AES-256 encryption for sensitive data at rest
- Complete tenant data isolation
- SQL injection prevention via parameterized queries
- XSS prevention via input sanitization

### Account Security
- Account lockout after 5 failed attempts
- Password reset with time-limited tokens
- Audit logging of all actions

---

## Performance

### Optimization Techniques
- Database indexing on key columns
- Full-text search with PostgreSQL
- Query optimization with EF Core
- Caching with Redis (optional)
- Lazy loading and pagination
- Image thumbnails for faster loading
- CDN for static assets

### Performance Targets
- Page load time: < 2 seconds
- API response time: < 500ms
- Concurrent users: 500 per tenant
- Asset search: < 1 second with 10,000+ assets

---

## Monitoring & Logging

### Application Logging
- Structured logging with Serilog
- Log levels: Debug, Info, Warning, Error, Fatal
- Log storage: File, Database, Cloud (optional)

### Audit Trail
- All CRUD operations logged
- User actions tracked with timestamp and IP
- 90-day retention policy

### Monitoring
- Health check endpoints
- Hangfire dashboard for background jobs
- Application Insights (optional)

---

## Support

### Documentation
- **FRD**: See `frd_asset_mgmt.md`
- **Phase Guides**: See `PHASE_*_DOCUMENTATION.md`
- **API Docs**: https://localhost:5001/swagger
- **User Guides**: See `docs/user-guides/`

### Issues
Report issues on GitHub: [Issues](https://github.com/your-org/assetica/issues)

### Contact
- Email: support@assetica.io
- Website: https://assetica.io

---

## License

**Proprietary License**

This software is the property of Assetica Development Team. All rights reserved.

© 2025 Assetica. All Rights Reserved.

---

## Acknowledgments

- .NET Core Team at Microsoft
- Angular Team at Google
- PostgreSQL Community
- All open-source contributors

---

## Changelog

### Version 1.0.0 (2025-06-01) - Initial Release
- Complete Phase 1-5 implementation
- Multi-tenant SaaS platform
- Asset lifecycle management
- Financial tracking and depreciation
- Maintenance management
- Software license tracking
- Comprehensive reporting
- Mobile PWA

---

**Built with ❤️ by the Assetica Development Team**

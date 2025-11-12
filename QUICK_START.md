# Assetica - Quick Start Guide

This guide will help you get the Assetica platform up and running in your development environment quickly.

---

## Prerequisites

Before you begin, ensure you have the following installed:

✅ **PostgreSQL 15+**: [Download](https://www.postgresql.org/download/)
✅ **.NET SDK 8.0+**: [Download](https://dotnet.microsoft.com/download)
✅ **Node.js 18+ and npm**: [Download](https://nodejs.org/)
✅ **Angular CLI**: `npm install -g @angular/cli`
✅ **Git**: [Download](https://git-scm.com/)

### Optional (but recommended)
- Docker Desktop: [Download](https://www.docker.com/)
- Visual Studio Code: [Download](https://code.visualstudio.com/)
- pgAdmin: [Download](https://www.pgadmin.org/)

---

## Quick Start (Docker Method - Easiest)

If you have Docker installed, this is the fastest way to get started:

```bash
# 1. Clone the repository
git clone https://github.com/your-org/assetica.git
cd assetica

# 2. Start all services with Docker Compose
docker-compose up -d

# 3. Wait for services to be healthy (about 30 seconds)
docker-compose ps

# 4. Initialize the databases
docker exec -it assetica-postgres psql -U postgres -f /docker-entrypoint-initdb.d/phase1/001_create_shared_auth_database.sql
docker exec -it assetica-postgres psql -U postgres -f /docker-entrypoint-initdb.d/phase1/002_create_tenant_database_template.sql
docker exec -it assetica-postgres psql -U postgres -f /docker-entrypoint-initdb.d/phase1/003_create_hangfire_database.sql
docker exec -it assetica-postgres psql -U postgres -d assetica_tenant_demo -f /docker-entrypoint-initdb.d/seed-data/seed_admin_user.sql
```

### Access the Application

- **Frontend**: http://localhost:4200
- **Backend API**: http://localhost:5000
- **Swagger Docs**: http://localhost:5000/swagger
- **Hangfire Dashboard**: http://localhost:5000/hangfire
- **pgAdmin**: http://localhost:5050 (login: admin@assetica.io / admin)

### Default Credentials
```
Username: admin
Password: Admin@123
```

**⚠️ IMPORTANT**: Change the default password after first login!

---

## Manual Setup (Without Docker)

### Step 1: Database Setup

```bash
# 1. Ensure PostgreSQL is running
sudo service postgresql start  # Linux
# or
brew services start postgresql  # macOS

# 2. Navigate to database scripts
cd database/migrations/phase1

# 3. Run migration scripts in order
psql -U postgres -f 001_create_shared_auth_database.sql
psql -U postgres -f 002_create_tenant_database_template.sql
psql -U postgres -f 003_create_hangfire_database.sql

# 4. Seed initial data
cd ../../seed-data
psql -U postgres -d assetica_tenant_demo -f seed_admin_user.sql
```

### Step 2: Backend Setup

```bash
# 1. Navigate to backend directory
cd backend

# 2. Restore NuGet packages
dotnet restore

# 3. Update connection strings (if needed)
# Edit: Assetica.API/appsettings.Development.json

# 4. Build the solution
dotnet build

# 5. Run the API
cd Assetica.API
dotnet run
```

The API will start at: `https://localhost:5001`

### Step 3: Frontend Setup

```bash
# 1. Navigate to frontend directory
cd frontend

# 2. Install npm packages
npm install

# 3. Update API URL (if needed)
# Edit: src/environments/environment.ts

# 4. Start the development server
ng serve
```

The application will start at: `http://localhost:4200`

---

## Verify Installation

### 1. Check Database Connection

```bash
# Connect to auth database
psql -U postgres -d assetica_auth

# List tables
\dt

# You should see: tenants, tenant_subscriptions
\q
```

### 2. Check API Health

```bash
# Test health endpoint
curl http://localhost:5000/health

# Expected response:
# {"Status":"Healthy","Timestamp":"2025-01-12T..."}
```

### 3. Check Frontend

Open your browser and navigate to: `http://localhost:4200`

You should see the Assetica login page.

---

## First Login

1. **Open the application**: http://localhost:4200
2. **Login with default credentials**:
   - Username: `admin`
   - Password: `Admin@123`
3. **You will be prompted to change password** (this is by design)
4. **Set a new password** following the policy:
   - Minimum 8 characters
   - At least 1 uppercase letter
   - At least 1 lowercase letter
   - At least 1 number
   - At least 1 special character

---

## Explore the Application

### Default Tenant: Demo Organization

- **Subdomain**: demo
- **Database**: assetica_tenant_demo
- **Admin User**: admin@demo.assetica.io

### Key Features to Try

1. **User Management**
   - Navigate to Admin → Users
   - Create a new user
   - Assign roles

2. **Employee Management**
   - Navigate to Employees
   - View existing employees
   - Add a new employee

3. **Dashboard**
   - View system statistics
   - Check recent activities

4. **API Documentation**
   - Visit: http://localhost:5000/swagger
   - Explore available endpoints
   - Test API calls with authentication

5. **Background Jobs**
   - Visit: http://localhost:5000/hangfire
   - View scheduled jobs
   - Monitor job execution

---

## Troubleshooting

### Database Connection Issues

**Problem**: Cannot connect to PostgreSQL

**Solutions**:
```bash
# Check if PostgreSQL is running
sudo service postgresql status

# Start PostgreSQL if not running
sudo service postgresql start

# Check if port 5432 is in use
netstat -an | grep 5432

# Verify pg_hba.conf allows local connections
sudo nano /etc/postgresql/15/main/pg_hba.conf
# Add: local all all trust
sudo service postgresql restart
```

### Backend Not Starting

**Problem**: .NET API fails to start

**Solutions**:
```bash
# Verify .NET SDK version
dotnet --version  # Should be 8.0 or higher

# Clear build artifacts
cd backend
dotnet clean
dotnet restore
dotnet build

# Check for port conflicts
netstat -an | grep 5001

# Run with verbose logging
dotnet run --verbosity detailed
```

### Frontend Not Starting

**Problem**: Angular application fails to start

**Solutions**:
```bash
# Verify Node.js version
node --version  # Should be 18 or higher

# Clear npm cache
cd frontend
rm -rf node_modules package-lock.json
npm cache clean --force
npm install

# Check for port conflicts
netstat -an | grep 4200

# Run with verbose output
ng serve --verbose
```

### Migration Script Errors

**Problem**: SQL scripts fail to execute

**Solutions**:
```bash
# Ensure you're using PostgreSQL 15+
psql --version

# Check if databases already exist
psql -U postgres -l

# Drop existing databases if needed (CAUTION: This deletes all data!)
psql -U postgres -c "DROP DATABASE IF EXISTS assetica_auth;"
psql -U postgres -c "DROP DATABASE IF EXISTS assetica_tenant_demo;"
psql -U postgres -c "DROP DATABASE IF EXISTS assetica_hangfire;"

# Re-run migration scripts
cd database/migrations/phase1
psql -U postgres -f 001_create_shared_auth_database.sql
```

---

## Next Steps

Once you have the application running:

### For Developers

1. **Review Documentation**:
   - Read `frd_asset_mgmt.md` for functional requirements
   - Review `PHASE_1_DOCUMENTATION.md` for Phase 1 details
   - Check API documentation at `/swagger`

2. **Explore the Codebase**:
   - Backend: `backend/Assetica.API/`
   - Frontend: `frontend/src/app/`
   - Database: `database/migrations/`

3. **Run Tests**:
   ```bash
   # Backend tests
   cd backend
   dotnet test

   # Frontend tests
   cd frontend
   ng test
   ```

4. **Start Development**:
   - Pick a task from the project board
   - Create a feature branch
   - Implement and test
   - Submit a pull request

### For Administrators

1. **Configure Email Settings**:
   - Update `appsettings.json` with SMTP/SendGrid details
   - Test email notifications

2. **Set Up Cloud Storage**:
   - Configure AWS S3 or Azure Blob Storage
   - Update connection settings

3. **Create Additional Tenants**:
   - Use Super Admin account
   - Navigate to Admin → Tenants
   - Create new tenant organizations

4. **Customize Settings**:
   - Adjust session timeout
   - Configure password policy
   - Set up rate limiting

---

## Useful Commands

### Database

```bash
# Backup database
pg_dump -U postgres assetica_tenant_demo > backup.sql

# Restore database
psql -U postgres -d assetica_tenant_demo < backup.sql

# Reset demo tenant
psql -U postgres -c "DROP DATABASE assetica_tenant_demo;"
psql -U postgres -f database/migrations/phase1/002_create_tenant_database_template.sql
psql -U postgres -d assetica_tenant_demo -f database/seed-data/seed_admin_user.sql
```

### Backend

```bash
# Watch for changes and auto-rebuild
dotnet watch run

# Run specific project
dotnet run --project Assetica.API

# Generate database migration
dotnet ef migrations add MigrationName --project Assetica.Infrastructure --startup-project Assetica.API

# Apply migrations
dotnet ef database update --project Assetica.Infrastructure --startup-project Assetica.API
```

### Frontend

```bash
# Build for production
ng build --configuration production

# Run with specific host
ng serve --host 0.0.0.0 --port 4200

# Generate component
ng generate component features/assets/asset-list

# Generate service
ng generate service services/asset

# Run tests with coverage
ng test --code-coverage
```

### Docker

```bash
# View logs
docker-compose logs -f backend
docker-compose logs -f frontend

# Restart specific service
docker-compose restart backend

# Stop all services
docker-compose down

# Remove volumes (CAUTION: Deletes all data!)
docker-compose down -v
```

---

## Development Workflow

### Daily Development

```bash
# 1. Pull latest changes
git pull origin main

# 2. Start backend (Terminal 1)
cd backend/Assetica.API
dotnet watch run

# 3. Start frontend (Terminal 2)
cd frontend
ng serve

# 4. Make changes and test
# Backend will auto-reload on file changes
# Frontend will auto-reload on file changes
```

### Before Committing

```bash
# 1. Run tests
cd backend && dotnet test
cd ../frontend && ng test

# 2. Check code style
cd backend && dotnet format
cd ../frontend && ng lint

# 3. Build for production
cd backend && dotnet build --configuration Release
cd ../frontend && ng build --configuration production
```

---

## Support

### Documentation
- **FRD**: See `frd_asset_mgmt.md`
- **Phase Guides**: See `PHASE_*_DOCUMENTATION.md`
- **API Docs**: http://localhost:5000/swagger
- **Full README**: See `README.md`

### Getting Help
- **Issues**: Create an issue on GitHub
- **Email**: support@assetica.io
- **Slack**: Join #assetica-dev channel

---

## Success!

You're now ready to start developing with Assetica! 🎉

**Happy Coding!**

---

**Last Updated**: 2025-01-12
**Version**: 1.0.0

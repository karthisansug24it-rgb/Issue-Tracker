# DEVTRACK 🚀

### Hierarchy-Based Issue Tracking & Project Management Desktop Application

DevTrack is a role-based issue tracker and project manager: a Spring Boot REST API plus a Flutter desktop (and web) client.

---

## 📁 Project Structure

```
Issue-Tracker/
├── devtrack_backend/            # Java 17 + Spring Boot 3 REST API
│   ├── src/main/java/com/devtrack/
│   │   ├── controller/          # REST endpoints (auth, projects, issues, users, teams, notifications, audit)
│   │   ├── dto/                 # Request / response objects (validated, never bound directly to entities)
│   │   ├── exception/           # ApiException types + GlobalExceptionHandler (consistent JSON error responses)
│   │   ├── init/                # DataLoader: Super Admin bootstrap + demo data loader
│   │   ├── model/               # JPA entities and enums (IssueStatus workflow, RoleType)
│   │   ├── repository/          # Spring Data JPA repositories
│   │   ├── security/            # JWT filter, SecurityConfig, AccessService (permission rules), RolePermissions
│   │   └── service/             # Business logic
│   ├── src/main/resources/
│   │   ├── application.yml      # H2 (default) and PostgreSQL ("postgres") profiles
│   │   └── schema.sql           # Reference PostgreSQL DDL & seed data for DBeaver/psql
│   ├── src/test/java/...        # 24 integration tests for every role and permission rule
│   └── mvnw / mvnw.cmd          # Maven wrapper
│
├── devtrack_desktop/            # Flutter app (Linux, Windows, macOS, web)
│   ├── lib/models/              # Dart models (IssueModel, UserModel, ProjectModel, etc.)
│   ├── lib/services/            # ApiService (HTTP + error handling) and AuthState (session)
│   ├── lib/screens/             # Login, dashboard, projects, issues, teams, users, audit logs, notifications
│   └── lib/utils/               # Session storage (cross-platform desktop & web storage)
│
├── setup_teammate.sql           # 1-Click PostgreSQL DDL + Seed data for teammate onboarding
├── run_backend.bat              # 1-Click Windows batch launcher for backend
├── run_desktop.bat              # 1-Click Windows batch launcher for desktop app
├── run_web.bat                  # 1-Click Windows batch launcher for web frontend (port 3000)
├── .env.example                 # Configuration template (copy to .env, which is git-ignored)
└── README.md
```

---

## 👥 Teammate Quick Setup Guide

Follow these steps to set up DevTrack on your local machine:

### Step 1: Database Setup (PostgreSQL)

You can run PostgreSQL either locally or using Docker:

#### Option A: Docker (Recommended)

```bash
docker run -d --name devtrack-postgres \
  -e POSTGRES_PASSWORD=admin@123 \
  -e POSTGRES_DB=issuetracker \
  -p 5432:5432 \
  postgres:15-alpine
```

#### Option B: Local PostgreSQL / DBeaver

1. Open DBeaver or psql and create the database:
   ```sql
   CREATE DATABASE issuetracker;
   ```
2. Execute the onboarding script [`setup_teammate.sql`](file:///home/vkannantech/zo/Issue-Tracker/setup_teammate.sql) in DBeaver or via command line:
   ```bash
   psql -h localhost -U postgres -d issuetracker -f setup_teammate.sql
   ```

---

### Step 2: Environment Configuration

Copy the `.env.example` file to `.env`:

```bash
cp .env.example .env        # Windows: copy .env.example .env
```

Ensure the database settings match your local PostgreSQL configuration:

```env
SPRING_PROFILES_ACTIVE=postgres
DB_HOST=localhost
DB_PORT=5432
DB_NAME=issuetracker
DB_USERNAME=postgres
DB_PASSWORD=admin@123
JWT_SECRET=404E635266556A586E3272357538782F413F4428472B4B6250645367566B5970
API_BASE_URL=http://localhost:8080/api/v1
```

---

### Step 3: Run the Backend (Spring Boot 3 + Java 17+)

```bash
cd devtrack_backend
./mvnw spring-boot:run          # Windows: mvnw.cmd spring-boot:run
```

Or double-click `run_backend.bat` on Windows.

Run tests to verify access control & permission rules:

```bash
./mvnw test
```

---

### Step 4: Run the Flutter Client (Desktop / Web)

```bash
cd devtrack_desktop
flutter run -d linux            # Linux desktop
flutter run -d windows          # Windows desktop (or run run_desktop.bat)
flutter run -d chrome --web-port=3000  # Web client (or run run_web.bat)
```

Run frontend tests:

```bash
flutter test
```

---

## 🔑 Teammate Test Accounts & Credentials

**Password for ALL accounts:** `qwerty123`

| Role            | Email                       | Password    | Access Level                                                 |
| --------------- | --------------------------- | ----------- | ------------------------------------------------------------ |
| **Super Admin** | `superadmin@devtrack.com`   | `qwerty123` | System management, manage admins, audit logs                 |
| **Admin**       | `admin@devtrack.com`        | `qwerty123` | Department management, all teams, manage users up to Manager |
| **Manager**     | `arun.manager@devtrack.com` | `qwerty123` | Project creator/owner, manage project members & teams        |
| **Team Lead**   | `suresh.lead@devtrack.com`  | `qwerty123` | Assign and review issues in assigned projects                |
| **QA / Tester** | `vijay.qa@devtrack.com`     | `qwerty123` | Test and report issues, verify fixes                         |
| **Developer 1** | `karthi.dev@devtrack.com`   | `qwerty123` | Work on assigned issues, log time, comment                   |
| **Developer 2** | `priya.dev@devtrack.com`    | `qwerty123` | Work on assigned issues, log time, comment                   |

---

## 🛠️ Helpful SQL Queries for Teammates

Execute these in DBeaver or psql connected to `issuetracker`:

### 1. Reset ALL Users' Password to `qwerty123`

```sql
UPDATE users SET password = '$2a$10$QWp5.GktNP3yVOzLHKQPvujiCPw.4zUiprUfZe0xjQc2ZQ085F27m';
```

### 2. View All Users and Their Roles

```sql
SELECT id, full_name, email, role, department, active FROM users ORDER BY id;
```

### 3. Unlock / Activate All Accounts

```sql
UPDATE users SET active = true;
```

### 4. Promote a User to SUPER_ADMIN

```sql
UPDATE users SET role = 'SUPER_ADMIN' WHERE email = 'your.email@devtrack.com';
```

---

## 🔐 Roles and Permissions

All rules are enforced by the API in `security/AccessService.java`. The app only hides what you cannot do; it never relies on UI hiding for security.

| Role            | What they can do                                                                                                                                    |
| --------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Super Admin** | Everything, including managing Admins and other Super Admins.                                                                                       |
| **Admin**       | See all projects/issues; manage departments, all teams, and users up to **Manager**; enable/disable accounts; audit logs.                           |
| **Manager**     | Create projects (as owner); manage members of projects they own/PM; create and manage **their own** teams; promote/demote Team Leads and Employees. |
| **Team Lead**   | See the staff directory and teams; assign and review issues in projects they belong to.                                                             |
| **Employee**    | See only projects they belong to; report issues; work on and log time against issues assigned to them; comment.                                     |

### Issue workflow

```
OPEN ──► ASSIGNED ──► IN_PROGRESS ──► IN_REVIEW ──► RESOLVED ──► CLOSED
            │             │   ▲            │            │           │
            └──► BLOCKED ◄┘   └────────────┘            └──► REOPENED ◄┘
```

- The **assignee** (or a team lead / project manager) moves work along: start, block, submit for review.
- **Review decisions** (resolve, close, reopen, send back from review) are made by team leads, project managers, admins, or the **reporter**. Assignees cannot approve their own work.
- Unassigning an issue moves it back to `OPEN`. Reopening clears its resolved date.
- The API returns `allowedTransitions` for every issue, so the app only offers valid moves.
- Issue keys (e.g. `WEB-104`) come from a per-project counter and are unique even under concurrent creation.

---

## 🧭 API Notes

- Authentication is **bearer token only**: `Authorization: Bearer <jwt>` from `POST /api/v1/auth/login`. No auth cookies are issued.
- `GET /api/v1/auth/me` returns the current user and their permission list.
- Errors are JSON: `{"status": 403, "error": "Forbidden", "message": "...", "path": "..."}`. 401 = not signed in / token invalid, 403 = not allowed, 404 = not found, 409 = conflict.
- Public endpoints: login, register (always creates an **Employee**, password ≥ 8 characters) and the department list.

---

## 🔒 Security Notes

- Local `.env` files are ignored by git to protect credentials. Use `.env.example` as the configuration template.

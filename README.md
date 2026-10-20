# DEVTRACK 🚀
### Hierarchy-Based Issue Tracking & Project Management Desktop Application

DevTrack is a role-based, hierarchy-driven issue tracking and project management desktop application designed for modern software teams and enterprises.

---

## 📁 Project Architecture & Clean Folder Separation

The application is strictly separated into two distinct, standalone directories:

```
issuetracker/
├── devtrack_backend/        # Java 17 + Spring Boot REST API
│   ├── src/main/java/com/devtrack/
│   │   ├── config/          # Security, JWT & CORS configurations
│   │   ├── controller/      # REST API endpoints (Auth, Projects, Issues, Teams, Users, Audit)
│   │   ├── dto/             # Data Transfer Objects (Requests & Responses)
│   │   ├── init/            # DataLoader with realistic seed data
│   │   ├── model/           # JPA Entities (Users, Roles, Projects, Issues, Comments, History, Audit)
│   │   ├── repository/      # Spring Data JPA Repositories
│   │   ├── security/        # JWT Authentication Filter & Token Utils
│   │   └── service/         # Business logic & permission enforcement
│   ├── src/main/resources/
│   │   ├── application.yml  # Dual H2 (zero-config dev) & PostgreSQL (production) profiles
│   │   └── schema.sql       # Pure PostgreSQL 18 DDL schema script (for DBeaver)
│   ├── mvnw.cmd             # Maven Wrapper (no separate Maven install required)
│   └── pom.xml              # Minimal, clean dependencies (Spring Web, Data JPA, Security, H2, Postgres)
│
├── devtrack_desktop/        # Flutter Windows Desktop Application
│   ├── lib/
│   │   ├── main.dart        # Desktop app entry point
│   │   ├── models/          # Dart data models (User, Project, Issue, Comment, AuditLog, Metrics)
│   │   ├── services/        # ApiService (REST API + offline fallback) & AuthState
│   │   └── screens/
│   │       ├── main_layout.dart      # NavigationRail sidebar + Top Bar with Role Switcher
│   │       ├── dashboard_screen.dart # Role-specific dashboard (Super Admin, Admin, Manager, Employee)
│   │       ├── projects_screen.dart  # Project cards, progress indicators, creation dialog
│   │       ├── issues_screen.dart    # Issue list, filters (Project, Status, Priority), details dialog
│   │       ├── teams_screen.dart     # Departments and Teams hierarchy
│   │       ├── users_screen.dart     # User management & active toggle
│   │       └── audit_logs_screen.dart# Security and audit log trail
│   └── pubspec.yaml         # Lightweight dependencies: only standard `http` package
│
└── README.md                # Project documentation & run guide
```

---

## 🔐 Real Authentication & Role-Based Flow

DevTrack enforces real authentication and role-based access control directly against the Spring Boot REST API (`POST /api/v1/auth/login`).

1. **Dedicated Login Screen**:
   - The application launches with a clean Sign-In interface.
   - Users enter their email and password credentials.
   - On authentication, the backend validates passwords with `BCrypt`, issues a signed JWT token, and returns user details with authorized role permissions.

2. **Strict Role-Based Flow & Navigation**:
   - **Super Admin**: Access to Dashboard, Projects, Issues, Teams, Users management, and System Audit Logs.
   - **Admin**: Access to Dashboard, Company Projects, Issues, Departments & Teams, and User accounts.
   - **Manager**: Access to Dashboard, Assigned Projects, Team Issues, and Task assignments.
   - **Employee**: Focused view of My Assigned Work, My Open Bugs, Task status transitions, and Work Comments.
   - **Sign Out**: The top navigation bar includes an explicit "Sign Out" button which terminates the session and returns to the login screen.

---

## ⚡ Quick Start Guide

### 1. Environment Configuration (.env)

DevTrack reads `.env` configuration files automatically. A template `.env.example` is provided:

```bash
# In the project root or devtrack_backend:
copy .env.example .env
```

Key `.env` parameters:
- `SPRING_PROFILES_ACTIVE`: `postgres` (for PostgreSQL 18) or `default` (for zero-config local H2)
- `DB_HOST`, `DB_PORT`, `DB_NAME`: Host, port, and database name (defaults: `localhost:5432/devtrack`)
- `DB_USERNAME`, `DB_PASSWORD`: Your local database credentials
- `SERVER_PORT`: `8080` (API port)
- `JWT_SECRET`: 256-bit token signing secret

### 2. Running the Spring Boot Backend

The backend includes a standalone Maven wrapper (`mvnw.cmd`) and runs with zero external tools needed beyond Java 17.

```bash
cd devtrack_backend
.\mvnw.cmd spring-boot:run
```

- **PostgreSQL Database**: With `SPRING_PROFILES_ACTIVE=postgres` in `.env`, Spring Boot connects to PostgreSQL and automatically verifies/updates all tables.
- **DBeaver Inspection**: The full DDL schema is provided in `devtrack_backend/src/main/resources/schema.sql`.

### 3. Running with 1-Click Launch Scripts (Windows)

Convenient one-click `.bat` scripts are provided in the project root:

- **`run_backend.bat`**: Launches the Spring Boot backend service on port 8080 using Maven Wrapper.
- **`run_web.bat`**: Launches the Flutter Web application locked to fixed port `3000` (`flutter run -d chrome --web-port=3000`). Using a fixed port preserves browser `localStorage` credentials and session cache permanently across restarts.
- **`run_desktop.bat`**: Launches the Flutter Windows native desktop application.

### 4. Running via VS Code / IDE

A ready-to-use `.vscode/launch.json` is configured with:
- **DevTrack Web (Fixed Port 3000)**: Launches Chrome on `http://localhost:3000`.
- **DevTrack Desktop (Windows)**: Launches Windows desktop binary.
- **DevTrack Backend (Spring Boot)**: Debugs Java backend in IDE.

### 5. Demo Accounts & Credentials

Reference credentials for each role hierarchy level:
- **Super Admin**: `superadmin@devtrack.com` / `admin123`
- **Admin**: `admin@devtrack.com` / `admin123`
- **Manager (Karthisan)**: `vskarthisan@gmail.com` / `password123`
- **Manager (Arun)**: `arun.manager@devtrack.com` / `password123`
- **Team Lead (Suresh)**: `suresh.lead@devtrack.com` / `password123`
- **Developer (Karthi)**: `karthi.dev@devtrack.com` / `password123`

---

## 💡 Simple & Explainable Design Decisions

1. **Fixed Web Port (3000) for Stable Sessions**:
   - Web browsers isolate `localStorage` by origin (host + port). By locking Flutter Web to port 3000, user sessions never reset or disappear between app launches.
2. **Robust Desktop Cache**:
   - Desktop sessions are persistently stored in `%LOCALAPPDATA%/DevTrack/session_cache.json` and resilient against backend restarts.
3. **No Complicated Heavy Libraries**:
   - Backend uses pure, standard Spring Boot starters (Spring Web, Spring Security, Spring Data JPA).
   - Frontend uses standard Flutter widgets and pure `http` without complex reactive frameworks.
4. **Clean Normal UI**:
   - Clean, professional desktop layout with a standard left navigation rail, readable typography, clear status chips, and intuitive dialogs.
5. **100% Verified**:
   - Backend compiled with `release 17` with zero errors.
   - Flutter desktop app analyzed with `flutter analyze` with 0 issues.


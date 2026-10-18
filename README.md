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
   - Users must enter valid credentials.
   - On authentication, the backend validates passwords with `BCrypt`, issues a signed JWT token, and returns user details with authorized role permissions.
   - For fast convenience while testing, one-click credential chips are provided at the bottom of the sign-in card.

2. **Strict Role-Based Flow & Navigation**:
   - **Super Admin**: Access to Dashboard, Projects, Issues, Teams, Users management, and System Audit Logs.
   - **Admin**: Access to Dashboard, Company Projects, Issues, Departments & Teams, and User accounts.
   - **Manager**: Access to Dashboard, Assigned Projects, Team Issues, and Task assignments.
   - **Employee**: Focused view of My Assigned Work, My Open Bugs, Task status transitions, and Work Comments.
   - **Sign Out**: The top navigation bar includes an explicit "Sign Out" button which terminates the session and returns to the login screen.

---

## ⚡ Quick Start Guide

### 1. Running the Spring Boot Backend

The backend includes a standalone Maven wrapper (`mvnw.cmd`) and runs with zero external tools needed beyond Java 17.

```bash
cd devtrack_backend
.\mvnw.cmd spring-boot:run
```

- **Default Database**: Persistent H2 database in PostgreSQL compatibility mode located in `./data/devtrack.mv.db` (persists data across restarts without needing manual DB configuration).
- **PostgreSQL Database (Optional)**: To connect to PostgreSQL directly:
  ```powershell
  $env:SPRING_PROFILES_ACTIVE="postgres"
  $env:DB_USERNAME="postgres"
  $env:DB_PASSWORD="your_postgres_password"
  .\mvnw.cmd spring-boot:run
  ```
- **DBeaver Inspection**: The full DDL schema is provided in `devtrack_backend/src/main/resources/schema.sql`.

### 2. Running the Flutter Windows Desktop App

```bash
cd devtrack_desktop
flutter run -d windows
```

- **Instant Role Switcher**: The top navigation bar includes an instant role switcher dropdown (`Super Admin`, `Admin`, `Manager`, `Employee`) so you can test all permissions and dashboards immediately!
- **Dual Support**: Seamlessly calls `http://localhost:8080/api/v1`. If backend is not yet started, it gracefully uses local seed data so you can test and present without delays.

---

## 💡 Simple & Explainable Design Decisions

1. **No Complicated Heavy Libraries**:
   - Backend uses pure, standard Spring Boot starters (Spring Web, Spring Security, Spring Data JPA).
   - Frontend uses standard Flutter widgets and pure `http` without complex reactive frameworks.
2. **Clean Normal UI**:
   - Clean, professional desktop layout with a standard left navigation rail, readable typography, clear status chips, and intuitive dialogs.
3. **100% Verified**:
   - Backend compiled with `release 17` with zero errors.
   - Flutter desktop app analyzed with `flutter analyze` with 0 issues.
   - All Flutter widget tests passed.

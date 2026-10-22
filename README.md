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
│   │   ├── dto/                 # Request / response objects (requests are validated, never bound to entities)
│   │   ├── exception/           # ApiException types + GlobalExceptionHandler (JSON errors with "message")
│   │   ├── init/                # DataLoader: Super Admin bootstrap + optional demo data
│   │   ├── model/               # JPA entities and enums (IssueStatus holds the workflow)
│   │   ├── repository/          # Spring Data JPA repositories
│   │   ├── security/            # JWT filter, SecurityConfig, AccessService (all permission rules), RolePermissions
│   │   └── service/             # Business logic
│   ├── src/main/resources/
│   │   ├── application.yml      # H2 (default) and PostgreSQL ("postgres") profiles
│   │   └── schema.sql           # Reference PostgreSQL DDL for DBeaver (not executed; Hibernate manages tables)
│   ├── src/test/java/...        # Integration tests for every role rule
│   └── mvnw / mvnw.cmd          # Maven wrapper
│
├── devtrack_desktop/            # Flutter app (Windows, Linux, macOS, web)
│   ├── lib/models/              # Dart models
│   ├── lib/services/            # ApiService (all HTTP + error handling) and AuthState (session)
│   ├── lib/screens/             # Login, dashboard, projects, issues, teams, users, audit logs, notifications
│   └── lib/utils/               # Session storage (file on desktop, localStorage on web), clipboard
│
├── .env.example                 # Configuration template (copy to .env, which is git-ignored)
└── README.md
```

---

## 🔐 Roles and Permissions

All rules are enforced by the API in `security/AccessService.java`. The app only hides what you cannot do; it never relies on hiding for security.

| Role | What they can do |
|---|---|
| **Super Admin** | Everything, including managing Admins and other Super Admins. |
| **Admin** | See all projects/issues; manage departments, all teams, and users up to **Manager**; enable/disable accounts; audit logs. |
| **Manager** | Create projects (as owner); manage members of projects they own/PM; create and manage **their own** teams; promote/demote Team Leads and Employees. |
| **Team Lead** | See the staff directory and teams; assign and review issues in projects they belong to. |
| **Employee** | See only projects they belong to; report issues; work on and log time against issues assigned to them; comment. |

Additional rules:

- **Project visibility**: non-admins only see projects they own or are a member of (and only those projects' issues, comments, history and time logs).
- **Project roles**: a `PROJECT_MANAGER` member can manage that project's members; a `TECH_LEAD` member can assign issues in it.
- **Nobody can change their own role or disable their own account**, so the system always keeps at least one Super Admin.
- **Assignees** must be active members of the issue's project. Team leads must have the Team Lead or Manager role; team managers must be Manager or above.

### Issue workflow

```
OPEN ──► ASSIGNED ──► IN_PROGRESS ──► IN_REVIEW ──► RESOLVED ──► CLOSED
            │             │   ▲            │            │           │
            └──► BLOCKED ◄┘   └────────────┘            └─► REOPENED ◄┘
```

- The **assignee** (or a team lead / project manager) moves work along: start, block, submit for review.
- **Review decisions** (resolve, close, reopen, send back from review) are made by team leads, project managers, admins, or the **reporter**. Assignees cannot approve their own work.
- Unassigning an issue moves it back to `OPEN`. Reopening clears its resolved date.
- The API returns `allowedTransitions` for every issue, so the app only offers valid moves.
- Issue keys (e.g. `WEB-104`) come from a per-project counter and are unique even under concurrent creation.

---

## ⚡ Quick Start

### 1. Configuration (.env)

```bash
cp .env.example .env        # Windows: copy .env.example .env
```

Important settings (see `.env.example` for all of them):

| Variable | Purpose |
|---|---|
| `SPRING_PROFILES_ACTIVE` | `default` = zero-config H2 file database, `postgres` = PostgreSQL |
| `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USERNAME`, `DB_PASSWORD` | PostgreSQL connection |
| `JWT_SECRET` | Token signing key, **at least 32 characters** (`openssl rand -hex 32`). If empty, a random key is used and users must sign in again after each restart. |
| `BOOTSTRAP_ADMIN_EMAIL` / `BOOTSTRAP_ADMIN_PASSWORD` | First Super Admin, created only when no active Super Admin exists. Empty password = generated and printed once in the log. |
| `SEED_DEMO_DATA` | `true` loads demo data into an **empty** database. Use `false` for real deployments. |
| `CORS_ALLOWED_ORIGINS` | Browser origins allowed to call the API (Flutter web only). |
| `H2_CONSOLE_ENABLED` | H2 web console for local debugging (default `false`). |

### 2. Run the backend (Java 17+)

```bash
cd devtrack_backend
./mvnw spring-boot:run          # Windows: mvnw.cmd spring-boot:run
./mvnw test                     # role/permission integration tests
```

### 3. Run the Flutter app

```bash
cd devtrack_desktop
flutter run -d linux            # or: -d windows, -d macos, -d chrome
flutter run -d windows --dart-define=API_BASE_URL=http://server:8080/api/v1   # remote backend
flutter test
```

On desktop the session is remembered in `~/.config/devtrack/session.json` (Linux), `%APPDATA%\DevTrack\session.json` (Windows) or `~/Library/Application Support/DevTrack` (macOS). Signing out deletes it.

### Demo accounts (only when `SEED_DEMO_DATA=true` on an empty database)

| Role | Email | Password |
|---|---|---|
| Super Admin | superadmin@devtrack.com | admin123 (or `BOOTSTRAP_ADMIN_PASSWORD`) |
| Admin | admin@devtrack.com | admin123 |
| Manager | arun.manager@devtrack.com | password123 |
| Team Lead | suresh.lead@devtrack.com | password123 |
| Team Lead (QA) | vijay.qa@devtrack.com | password123 |
| Employee | karthi.dev@devtrack.com | password123 |
| Employee | priya.dev@devtrack.com | password123 |

Change or disable these accounts before sharing an installation.

---

## 🧭 API Notes

- Authentication is **bearer token only**: `Authorization: Bearer <jwt>` from `POST /api/v1/auth/login`. No auth cookies are issued.
- `GET /api/v1/auth/me` returns the current user and their permission list.
- Errors are JSON: `{"status": 403, "error": "Forbidden", "message": "...", "path": "..."}`. 401 = not signed in / token invalid, 403 = not allowed, 404 = not found, 409 = conflict.
- Public endpoints: login, register (always creates an **Employee**, password ≥ 8 characters) and the department list.

## 🔒 Security Notes

- Older versions of this repository committed `.env` files and used a public default JWT secret. If you used those values anywhere, **change your database password and set a new `JWT_SECRET`**; the old values are still in git history.

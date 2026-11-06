-- ====================================================================
-- DEVTRACK - COMPLETE POSTGRESQL DATABASE SETUP & SEED SCRIPT
-- Database: PostgreSQL 14 / 15 / 16 / 17 / 18
-- Compatible with: psql CLI, DBeaver, pgAdmin, and IntelliJ Database Tools
--
-- Quick Instructions:
-- 1. Ensure PostgreSQL service is running (default port: 5432).
-- 2. Create the database if it doesn't exist:
--      CREATE DATABASE issuetracker;
-- 3. Execute this file in the `issuetracker` database:
--      psql -h localhost -U postgres -d issuetracker -f setup_teammate.sql
--    Or open this file in DBeaver / pgAdmin and run it (Alt+X / Execute Script).
--
-- Password for ALL default accounts: qwerty123
-- BCrypt Hash: $2a$10$QWp5.GktNP3yVOzLHKQPvujiCPw.4zUiprUfZe0xjQc2ZQ085F27m
-- ====================================================================

-- --------------------------------------------------------------------
-- 1. DEPARTMENTS TABLE
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS departments (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    code VARCHAR(20) NOT NULL UNIQUE,
    description VARCHAR(500),
    active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- --------------------------------------------------------------------
-- 2. USERS TABLE
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
    id BIGSERIAL PRIMARY KEY,
    full_name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL, -- SUPER_ADMIN, ADMIN, MANAGER, TEAM_LEAD, EMPLOYEE
    department VARCHAR(100),
    department_id BIGINT REFERENCES departments(id) ON DELETE SET NULL,
    job_title VARCHAR(100),
    avatar_url VARCHAR(500),
    active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- --------------------------------------------------------------------
-- 3. TEAMS TABLE
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS teams (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    department_id BIGINT REFERENCES departments(id) ON DELETE SET NULL,
    manager_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
    team_lead_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
    description VARCHAR(500),
    active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- --------------------------------------------------------------------
-- 4. TEAM MEMBERS TABLE
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS team_members (
    id BIGSERIAL PRIMARY KEY,
    team_id BIGINT NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_team_user UNIQUE (team_id, user_id)
);

-- --------------------------------------------------------------------
-- 5. PROJECTS TABLE
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS projects (
    id BIGSERIAL PRIMARY KEY,
    project_key VARCHAR(20) NOT NULL UNIQUE, -- e.g. WEB, MOB, PAY
    name VARCHAR(255) NOT NULL,
    description TEXT,
    status VARCHAR(50) DEFAULT 'ACTIVE' NOT NULL, -- ACTIVE, PLANNING, COMPLETED, ON_HOLD
    owner_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
    start_date DATE,
    target_end_date DATE,
    next_issue_number INT DEFAULT 101,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- --------------------------------------------------------------------
-- 6. PROJECT MEMBERS TABLE (Flexible role-per-project)
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS project_members (
    id BIGSERIAL PRIMARY KEY,
    project_id BIGINT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    project_role VARCHAR(50) DEFAULT 'DEVELOPER' NOT NULL, -- PROJECT_MANAGER, TECH_LEAD, DEVELOPER, TESTER, DESIGNER
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_project_user UNIQUE (project_id, user_id)
);

-- --------------------------------------------------------------------
-- 7. ISSUES TABLE
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS issues (
    id BIGSERIAL PRIMARY KEY,
    issue_key VARCHAR(50) NOT NULL UNIQUE, -- e.g. WEB-101
    project_id BIGINT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    parent_issue_id BIGINT REFERENCES issues(id) ON DELETE SET NULL,
    title VARCHAR(500) NOT NULL,
    description TEXT,
    type VARCHAR(50) NOT NULL, -- BUG, TASK, FEATURE, INCIDENT, SUPPORT_REQUEST
    priority VARCHAR(50) NOT NULL, -- CRITICAL, HIGH, MEDIUM, LOW
    status VARCHAR(50) NOT NULL, -- OPEN, ASSIGNED, IN_PROGRESS, IN_REVIEW, RESOLVED, CLOSED, REOPENED, BLOCKED
    reporter_id BIGINT NOT NULL REFERENCES users(id),
    assignee_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
    due_date DATE,
    estimated_minutes INT DEFAULT 0,
    actual_minutes INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP
);

-- --------------------------------------------------------------------
-- 8. ISSUE COMMENTS TABLE
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS issue_comments (
    id BIGSERIAL PRIMARY KEY,
    issue_id BIGINT NOT NULL REFERENCES issues(id) ON DELETE CASCADE,
    author_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    author_name VARCHAR(255),
    comment_text TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- --------------------------------------------------------------------
-- 9. ISSUE HISTORY (Activity Audit Trail)
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS issue_history (
    id BIGSERIAL PRIMARY KEY,
    issue_id BIGINT NOT NULL REFERENCES issues(id) ON DELETE CASCADE,
    actor_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
    actor_name VARCHAR(255),
    field_name VARCHAR(100) NOT NULL, -- STATUS, ASSIGNEE, PRIORITY, etc.
    old_value VARCHAR(500),
    new_value VARCHAR(500),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- --------------------------------------------------------------------
-- 10. TIME ENTRIES TABLE
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS time_entries (
    id BIGSERIAL PRIMARY KEY,
    issue_id BIGINT NOT NULL REFERENCES issues(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    user_name VARCHAR(255),
    duration_minutes INT NOT NULL,
    work_description VARCHAR(500),
    logged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- --------------------------------------------------------------------
-- 11. NOTIFICATIONS TABLE
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS notifications (
    id BIGSERIAL PRIMARY KEY,
    recipient_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    message VARCHAR(1000) NOT NULL,
    related_issue_id BIGINT REFERENCES issues(id) ON DELETE SET NULL,
    related_project_key VARCHAR(50),
    type VARCHAR(50) NOT NULL,
    is_read BOOLEAN DEFAULT FALSE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- --------------------------------------------------------------------
-- 12. AUDIT LOGS (Security & Administrative History)
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS audit_logs (
    id BIGSERIAL PRIMARY KEY,
    actor_id BIGINT,
    actor_name VARCHAR(255),
    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(100),
    entity_id VARCHAR(100),
    details TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- --------------------------------------------------------------------
-- 13. ISSUE ATTACHMENTS TABLE
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS issue_attachments (
    id BIGSERIAL PRIMARY KEY,
    issue_id BIGINT NOT NULL REFERENCES issues(id) ON DELETE CASCADE,
    file_name VARCHAR(255) NOT NULL,
    file_type VARCHAR(100),
    file_size BIGINT,
    file_data TEXT,
    uploader_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
    uploader_name VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_attachments_issue ON issue_attachments(issue_id);

-- --------------------------------------------------------------------
-- SCHEMA MIGRATIONS (Ensure columns and FKs exist if tables pre-dated departments)
-- --------------------------------------------------------------------
ALTER TABLE users ADD COLUMN IF NOT EXISTS department_id BIGINT;
ALTER TABLE teams ADD COLUMN IF NOT EXISTS department_id BIGINT;
ALTER TABLE projects ADD COLUMN IF NOT EXISTS next_issue_number INT DEFAULT 101;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_users_department'
    ) THEN
        ALTER TABLE users ADD CONSTRAINT fk_users_department 
        FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE SET NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_teams_department'
    ) THEN
        ALTER TABLE teams ADD CONSTRAINT fk_teams_department 
        FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE SET NULL;
    END IF;
END $$;

-- --------------------------------------------------------------------
-- PERFORMANCE INDEXES
-- --------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_issues_project_id ON issues(project_id);
CREATE INDEX IF NOT EXISTS idx_issues_assignee_id ON issues(assignee_id);
CREATE INDEX IF NOT EXISTS idx_issues_reporter_id ON issues(reporter_id);
CREATE INDEX IF NOT EXISTS idx_issues_status ON issues(status);
CREATE INDEX IF NOT EXISTS idx_issues_priority ON issues(priority);
CREATE INDEX IF NOT EXISTS idx_issues_parent ON issues(parent_issue_id);
CREATE INDEX IF NOT EXISTS idx_team_members_user ON team_members(user_id);
CREATE INDEX IF NOT EXISTS idx_project_members_user ON project_members(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_recipient ON notifications(recipient_id);
CREATE INDEX IF NOT EXISTS idx_users_department ON users(department_id);
CREATE INDEX IF NOT EXISTS idx_comments_issue ON issue_comments(issue_id);
CREATE INDEX IF NOT EXISTS idx_history_issue ON issue_history(issue_id);
CREATE INDEX IF NOT EXISTS idx_time_issue ON time_entries(issue_id);

-- ====================================================================
-- SEED DATA (Idempotent - safe to run multiple times)
-- ====================================================================

-- 1. Departments
INSERT INTO departments (id, name, code, description, active) VALUES
(1, 'Engineering', 'ENG', 'Software engineering and development', true),
(2, 'Quality Assurance', 'QA', 'Software quality and testing', true),
(3, 'Operations & Support', 'OPS', 'Production operations and support', true),
(4, 'Executive', 'EXEC', 'Leadership and administration', true)
ON CONFLICT DO NOTHING;

-- 2. Users (Default password: qwerty123)
INSERT INTO users (id, full_name, email, password, role, department, department_id, job_title, active) VALUES
(1, 'Super Admin', 'superadmin@devtrack.com', '$2a$10$QWp5.GktNP3yVOzLHKQPvujiCPw.4zUiprUfZe0xjQc2ZQ085F27m', 'SUPER_ADMIN', 'Executive', 4, 'System Super Admin', true),
(2, 'Suresh Lead', 'suresh.lead@devtrack.com', '$2a$10$QWp5.GktNP3yVOzLHKQPvujiCPw.4zUiprUfZe0xjQc2ZQ085F27m', 'TEAM_LEAD', 'Engineering', 1, 'Senior Tech Lead', true),
(3, 'Divya Admin', 'admin@devtrack.com', '$2a$10$QWp5.GktNP3yVOzLHKQPvujiCPw.4zUiprUfZe0xjQc2ZQ085F27m', 'ADMIN', 'Operations & Support', 3, 'Organization Admin', true),
(4, 'Arun Kumar', 'arun.manager@devtrack.com', '$2a$10$QWp5.GktNP3yVOzLHKQPvujiCPw.4zUiprUfZe0xjQc2ZQ085F27m', 'MANAGER', 'Engineering', 1, 'Engineering Manager', true),
(5, 'Karthi Raman', 'karthi.dev@devtrack.com', '$2a$10$QWp5.GktNP3yVOzLHKQPvujiCPw.4zUiprUfZe0xjQc2ZQ085F27m', 'EMPLOYEE', 'Engineering', 1, 'Full Stack Engineer', true),
(6, 'Priya Sharma', 'priya.dev@devtrack.com', '$2a$10$QWp5.GktNP3yVOzLHKQPvujiCPw.4zUiprUfZe0xjQc2ZQ085F27m', 'EMPLOYEE', 'Engineering', 1, 'Backend Engineer', true),
(7, 'Vijay Tester', 'vijay.qa@devtrack.com', '$2a$10$QWp5.GktNP3yVOzLHKQPvujiCPw.4zUiprUfZe0xjQc2ZQ085F27m', 'EMPLOYEE', 'Quality Assurance', 2, 'QA Automation Engineer', true)
ON CONFLICT (email) DO UPDATE SET 
    password = EXCLUDED.password,
    full_name = EXCLUDED.full_name,
    role = EXCLUDED.role,
    department = EXCLUDED.department,
    department_id = EXCLUDED.department_id,
    job_title = EXCLUDED.job_title,
    active = true;

-- 3. Teams
INSERT INTO teams (id, name, department_id, manager_id, team_lead_id, description, active) VALUES
(1, 'Web Development Team', 1, 4, 2, 'Fullstack web application engineering', true),
(2, 'Mobile & Cloud Team', 1, 4, 2, 'Mobile app and cloud infrastructure solutions', true),
(3, 'Core QA Team', 2, 4, 7, 'Automated regression and functional testing', true)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    manager_id = EXCLUDED.manager_id,
    team_lead_id = EXCLUDED.team_lead_id,
    department_id = EXCLUDED.department_id,
    description = EXCLUDED.description;

-- 4. Team Members
INSERT INTO team_members (team_id, user_id) VALUES
(1, 4), -- Arun Kumar (Manager)
(1, 2), -- Suresh Lead (Team Lead)
(1, 5), -- Karthi Raman (Developer)
(1, 6), -- Priya Sharma (Developer)
(2, 4), -- Arun Kumar
(2, 2), -- Suresh Lead
(2, 5), -- Karthi Raman
(3, 4), -- Arun Kumar
(3, 7)  -- Vijay Tester (QA)
ON CONFLICT (team_id, user_id) DO NOTHING;

-- 5. Projects
INSERT INTO projects (id, project_key, name, description, status, owner_id, start_date, target_end_date, next_issue_number) VALUES
(1, 'WEB', 'Website Development', 'Company client web portal and internal tools', 'ACTIVE', 4, CURRENT_DATE - 15, CURRENT_DATE + 45, 104),
(2, 'MOB', 'Mobile Application', 'Android and iOS customer mobile app', 'ACTIVE', 4, CURRENT_DATE - 30, CURRENT_DATE + 60, 102),
(3, 'PAY', 'Payment System Integration', 'Razorpay, Stripe and UPI payment gateways', 'ACTIVE', 4, CURRENT_DATE - 10, CURRENT_DATE + 30, 102)
ON CONFLICT (project_key) DO UPDATE SET
    owner_id = EXCLUDED.owner_id,
    status = EXCLUDED.status,
    next_issue_number = EXCLUDED.next_issue_number;

-- 6. Project Members
INSERT INTO project_members (project_id, user_id, project_role) VALUES
(1, 4, 'PROJECT_MANAGER'),
(1, 2, 'TECH_LEAD'),
(1, 5, 'DEVELOPER'),
(1, 6, 'DEVELOPER'),
(1, 7, 'TESTER'),
(2, 4, 'PROJECT_MANAGER'),
(2, 2, 'TECH_LEAD'),
(2, 5, 'DEVELOPER'),
(2, 7, 'TESTER'),
(3, 4, 'PROJECT_MANAGER'),
(3, 6, 'DEVELOPER')
ON CONFLICT (project_id, user_id) DO UPDATE SET
    project_role = EXCLUDED.project_role;

-- 7. Demo Issues
INSERT INTO issues (issue_key, project_id, title, description, type, priority, status, reporter_id, assignee_id, due_date, estimated_minutes, actual_minutes, resolved_at) VALUES
('WEB-101', 1, 'Login button not working', 'Clicking login button does not trigger validation or form submission on Chrome and Edge.', 'BUG', 'CRITICAL', 'ASSIGNED', 4, 5, CURRENT_DATE + 3, 180, 0, NULL),
('WEB-102', 1, 'Build login API', 'Implement JWT authentication endpoint POST /api/v1/auth/login with BCrypt password hashing.', 'TASK', 'HIGH', 'IN_PROGRESS', 4, 6, CURRENT_DATE + 5, 360, 120, NULL),
('WEB-103', 1, 'Test registration form', 'Perform cross-browser validation and automated test execution for customer registration page.', 'TASK', 'MEDIUM', 'RESOLVED', 4, 7, CURRENT_DATE - 1, 240, 240, CURRENT_TIMESTAMP - INTERVAL '4 hours'),
('MOB-101', 2, 'Push notification crash on Android 14', 'App closes unexpectedly when receiving push notification payload while in background state.', 'BUG', 'HIGH', 'IN_REVIEW', 4, 5, CURRENT_DATE + 2, 300, 280, NULL),
('PAY-101', 3, 'Stripe Webhook Handler', 'Build idempotent webhook listener for Stripe payment success and failure events.', 'FEATURE', 'HIGH', 'ASSIGNED', 4, 6, CURRENT_DATE + 8, 480, 0, NULL)
ON CONFLICT (issue_key) DO UPDATE SET
    status = EXCLUDED.status,
    priority = EXCLUDED.priority,
    assignee_id = EXCLUDED.assignee_id;

-- 8. Issue Comments
INSERT INTO issue_comments (id, issue_id, author_id, author_name, comment_text) VALUES
(1, 1, 4, 'Arun Kumar', 'Critical priority issue. Please investigate the onClick event handler and form submission logic.'),
(2, 3, 7, 'Vijay Tester', 'Test suite executed. All 24 test cases passed on Chrome, Firefox, and Edge. Fix verified.')
ON CONFLICT (id) DO NOTHING;

-- 9. Issue History
INSERT INTO issue_history (id, issue_id, actor_id, actor_name, field_name, old_value, new_value) VALUES
(1, 1, 4, 'Arun Kumar', 'CREATED', NULL, 'ASSIGNED'),
(2, 2, 4, 'Arun Kumar', 'CREATED', NULL, 'ASSIGNED'),
(3, 2, 6, 'Priya Sharma', 'STATUS', 'ASSIGNED', 'IN_PROGRESS'),
(4, 3, 4, 'Arun Kumar', 'STATUS', 'IN_REVIEW', 'RESOLVED')
ON CONFLICT (id) DO NOTHING;

-- 10. Time Entries
INSERT INTO time_entries (id, issue_id, user_id, user_name, duration_minutes, work_description) VALUES
(1, 2, 6, 'Priya Sharma', 120, 'Implemented JWT token creation and security filter chains')
ON CONFLICT (id) DO NOTHING;

-- 11. Notifications
INSERT INTO notifications (id, recipient_id, title, message, related_issue_id, related_project_key, type, is_read) VALUES
(1, 5, 'Urgent Bug Assignment', 'WEB-101 Login button not working was assigned to you by Arun Kumar', 1, 'WEB', 'ASSIGNMENT', false),
(2, 4, 'Fix Submitted for Review', 'MOB-101 Push notification crash fix was submitted by Karthi Raman', 4, 'MOB', 'REVIEW_REQUEST', false)
ON CONFLICT (id) DO NOTHING;

-- 12. Audit Logs
INSERT INTO audit_logs (id, actor_id, actor_name, action, entity_type, entity_id, details) VALUES
(1, 1, 'Super Admin', 'SYSTEM_INITIALIZATION', 'SYSTEM', '0', 'DevTrack demo organization initialized'),
(2, 3, 'Divya Admin', 'PROJECT_CREATED', 'PROJECT', '1', 'Admin created project Website Development')
ON CONFLICT (id) DO NOTHING;

-- --------------------------------------------------------------------
-- SYNCHRONIZE ALL SERIAL SEQUENCES
-- Ensures subsequent API / Spring Boot INSERTs do not collide with seed IDs
-- --------------------------------------------------------------------
SELECT setval('departments_id_seq', (SELECT COALESCE(MAX(id), 1) FROM departments));
SELECT setval('users_id_seq', (SELECT COALESCE(MAX(id), 1) FROM users));
SELECT setval('teams_id_seq', (SELECT COALESCE(MAX(id), 1) FROM teams));
SELECT setval('team_members_id_seq', (SELECT COALESCE(MAX(id), 1) FROM team_members));
SELECT setval('projects_id_seq', (SELECT COALESCE(MAX(id), 1) FROM projects));
SELECT setval('project_members_id_seq', (SELECT COALESCE(MAX(id), 1) FROM project_members));
SELECT setval('issues_id_seq', (SELECT COALESCE(MAX(id), 1) FROM issues));
SELECT setval('issue_comments_id_seq', (SELECT COALESCE(MAX(id), 1) FROM issue_comments));
SELECT setval('issue_history_id_seq', (SELECT COALESCE(MAX(id), 1) FROM issue_history));
SELECT setval('time_entries_id_seq', (SELECT COALESCE(MAX(id), 1) FROM time_entries));
SELECT setval('notifications_id_seq', (SELECT COALESCE(MAX(id), 1) FROM notifications));
SELECT setval('audit_logs_id_seq', (SELECT COALESCE(MAX(id), 1) FROM audit_logs));

-- ====================================================================
-- CHEAT SHEET QUERIES FOR POSTGRESQL / DBeaver / pgAdmin
-- ====================================================================
-- 1. Reset ALL users to password 'qwerty123':
--    UPDATE users SET password = '$2a$10$QWp5.GktNP3yVOzLHKQPvujiCPw.4zUiprUfZe0xjQc2ZQ085F27m';
--
-- 2. Unlock or activate all accounts:
--    UPDATE users SET active = true;
--
-- 3. View all users and roles:
--    SELECT id, full_name, email, role, department, active FROM users ORDER BY id;
--
-- 4. View all projects, owners, and next issue keys:
--    SELECT id, project_key, name, status, owner_id, next_issue_number FROM projects ORDER BY id;
-- ====================================================================

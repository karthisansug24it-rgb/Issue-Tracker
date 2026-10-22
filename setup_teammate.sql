-- ====================================================================
-- DEVTRACK - TEAMMATE QUICK DATABASE SETUP SCRIPT
-- Database: PostgreSQL 14 / 15 / 16 / 17 / 18
--
-- Instructions:
-- 1. Ensure PostgreSQL is running (default port: 5432).
-- 2. Create the database if it doesn't exist:
--      CREATE DATABASE issuetracker;
-- 3. Run this script in the `issuetracker` database:
--      psql -h localhost -U postgres -d issuetracker -f setup_teammate.sql
--    Or execute this entire file in DBeaver / pgAdmin connected to `issuetracker`.
--
-- All accounts below have password: qwerty123
-- ====================================================================

-- 1. USERS TABLE
CREATE TABLE IF NOT EXISTS users (
    id BIGSERIAL PRIMARY KEY,
    full_name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL,
    department VARCHAR(100),
    department_id BIGINT,
    job_title VARCHAR(100),
    avatar_url VARCHAR(500),
    active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. DEPARTMENTS TABLE
CREATE TABLE IF NOT EXISTS departments (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    code VARCHAR(20) NOT NULL UNIQUE,
    description VARCHAR(500),
    active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. TEAMS TABLE
CREATE TABLE IF NOT EXISTS teams (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    department_id BIGINT REFERENCES departments(id),
    manager_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
    team_lead_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
    description VARCHAR(500),
    active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4. TEAM MEMBERS TABLE
CREATE TABLE IF NOT EXISTS team_members (
    id BIGSERIAL PRIMARY KEY,
    team_id BIGINT NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_team_user UNIQUE (team_id, user_id)
);

-- 5. PROJECTS TABLE
CREATE TABLE IF NOT EXISTS projects (
    id BIGSERIAL PRIMARY KEY,
    project_key VARCHAR(20) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    status VARCHAR(50) DEFAULT 'ACTIVE' NOT NULL,
    owner_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
    start_date DATE,
    target_end_date DATE,
    next_issue_number INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 6. PROJECT MEMBERS TABLE
CREATE TABLE IF NOT EXISTS project_members (
    id BIGSERIAL PRIMARY KEY,
    project_id BIGINT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    project_role VARCHAR(50) DEFAULT 'DEVELOPER' NOT NULL,
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_project_user UNIQUE (project_id, user_id)
);

-- 7. ISSUES TABLE
CREATE TABLE IF NOT EXISTS issues (
    id BIGSERIAL PRIMARY KEY,
    issue_key VARCHAR(50) NOT NULL UNIQUE,
    project_id BIGINT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    parent_issue_id BIGINT REFERENCES issues(id) ON DELETE SET NULL,
    title VARCHAR(500) NOT NULL,
    description TEXT,
    type VARCHAR(50) NOT NULL,
    priority VARCHAR(50) NOT NULL,
    status VARCHAR(50) NOT NULL,
    reporter_id BIGINT NOT NULL REFERENCES users(id),
    assignee_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
    due_date DATE,
    estimated_minutes INT DEFAULT 0,
    actual_minutes INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP
);

-- 8. ISSUE COMMENTS TABLE
CREATE TABLE IF NOT EXISTS issue_comments (
    id BIGSERIAL PRIMARY KEY,
    issue_id BIGINT NOT NULL REFERENCES issues(id) ON DELETE CASCADE,
    author_id BIGINT NOT NULL REFERENCES users(id),
    author_name VARCHAR(255),
    comment_text TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 9. ISSUE HISTORY TABLE
CREATE TABLE IF NOT EXISTS issue_history (
    id BIGSERIAL PRIMARY KEY,
    issue_id BIGINT NOT NULL REFERENCES issues(id) ON DELETE CASCADE,
    actor_id BIGINT REFERENCES users(id),
    actor_name VARCHAR(255),
    field_name VARCHAR(100) NOT NULL,
    old_value VARCHAR(500),
    new_value VARCHAR(500),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 10. TIME ENTRIES TABLE
CREATE TABLE IF NOT EXISTS time_entries (
    id BIGSERIAL PRIMARY KEY,
    issue_id BIGINT NOT NULL REFERENCES issues(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(id),
    user_name VARCHAR(255),
    duration_minutes INT NOT NULL,
    work_description VARCHAR(500),
    logged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 11. NOTIFICATIONS TABLE
CREATE TABLE IF NOT EXISTS notifications (
    id BIGSERIAL PRIMARY KEY,
    recipient_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    message VARCHAR(1000) NOT NULL,
    related_issue_id BIGINT,
    related_project_key VARCHAR(50),
    type VARCHAR(50) NOT NULL,
    is_read BOOLEAN DEFAULT FALSE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 12. AUDIT LOGS TABLE
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

-- INDEXES
CREATE INDEX IF NOT EXISTS idx_issues_project_id ON issues(project_id);
CREATE INDEX IF NOT EXISTS idx_issues_assignee_id ON issues(assignee_id);
CREATE INDEX IF NOT EXISTS idx_issues_status ON issues(status);
CREATE INDEX IF NOT EXISTS idx_issues_priority ON issues(priority);
CREATE INDEX IF NOT EXISTS idx_project_members_user ON project_members(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_recipient ON notifications(recipient_id);
CREATE INDEX IF NOT EXISTS idx_users_department ON users(department_id);

-- Foreign key for user department
ALTER TABLE users DROP CONSTRAINT IF EXISTS fk_users_department;
ALTER TABLE users ADD CONSTRAINT fk_users_department FOREIGN KEY (department_id) REFERENCES departments(id);

-- --------------------------------------------------------------------
-- SEED DATA: Departments
-- --------------------------------------------------------------------
INSERT INTO departments (id, name, code, description, active) VALUES
(1, 'Engineering', 'ENG', 'Software engineering and development', true),
(2, 'Quality Assurance', 'QA', 'Software quality and testing', true),
(3, 'Operations & Support', 'OPS', 'Production operations and support', true)
ON CONFLICT (code) DO NOTHING;

-- --------------------------------------------------------------------
-- SEED DATA: Teammate Users
-- Default password: qwerty123 (BCrypt: $2a$10$QWp5.GktNP3yVOzLHKQPvujiCPw.4zUiprUfZe0xjQc2ZQ085F27m)
-- --------------------------------------------------------------------
INSERT INTO users (id, full_name, email, password, role, department, department_id, job_title, active) VALUES
(1, 'Super Admin', 'superadmin@devtrack.com', '$2a$10$QWp5.GktNP3yVOzLHKQPvujiCPw.4zUiprUfZe0xjQc2ZQ085F27m', 'SUPER_ADMIN', 'Executive', NULL, 'System Super Admin', true),
(2, 'Suresh Lead', 'suresh.lead@devtrack.com', '$2a$10$QWp5.GktNP3yVOzLHKQPvujiCPw.4zUiprUfZe0xjQc2ZQ085F27m', 'TEAM_LEAD', 'Engineering', 1, 'Senior Tech Lead', true),
(3, 'Divya Admin', 'admin@devtrack.com', '$2a$10$QWp5.GktNP3yVOzLHKQPvujiCPw.4zUiprUfZe0xjQc2ZQ085F27m', 'ADMIN', 'Operations', 3, 'Organization Admin', true),
(4, 'Arun Kumar', 'arun.manager@devtrack.com', '$2a$10$QWp5.GktNP3yVOzLHKQPvujiCPw.4zUiprUfZe0xjQc2ZQ085F27m', 'MANAGER', 'Engineering', 1, 'Engineering Manager', true),
(5, 'Karthi Raman', 'karthi.dev@devtrack.com', '$2a$10$QWp5.GktNP3yVOzLHKQPvujiCPw.4zUiprUfZe0xjQc2ZQ085F27m', 'EMPLOYEE', 'Engineering', 1, 'Full Stack Engineer', true),
(6, 'Priya Sharma', 'priya.dev@devtrack.com', '$2a$10$QWp5.GktNP3yVOzLHKQPvujiCPw.4zUiprUfZe0xjQc2ZQ085F27m', 'EMPLOYEE', 'Engineering', 1, 'Backend Engineer', true),
(7, 'Vijay Tester', 'vijay.qa@devtrack.com', '$2a$10$QWp5.GktNP3yVOzLHKQPvujiCPw.4zUiprUfZe0xjQc2ZQ085F27m', 'EMPLOYEE', 'Quality Assurance', 2, 'QA Automation Engineer', true)
ON CONFLICT (email) DO UPDATE SET password = '$2a$10$QWp5.GktNP3yVOzLHKQPvujiCPw.4zUiprUfZe0xjQc2ZQ085F27m';

-- Reset sequences
SELECT setval('departments_id_seq', (SELECT COALESCE(MAX(id), 1) FROM departments));
SELECT setval('users_id_seq', (SELECT COALESCE(MAX(id), 1) FROM users));

-- --------------------------------------------------------------------
-- PASSWORD RESET / CHEAT SHEET QUERIES:
--
-- Set ALL users to 'qwerty123':
--   UPDATE users SET password = '$2a$10$QWp5.GktNP3yVOzLHKQPvujiCPw.4zUiprUfZe0xjQc2ZQ085F27m';
--
-- Activate all accounts:
--   UPDATE users SET active = true;
--
-- View all users and their roles:
--   SELECT id, full_name, email, role, department, active FROM users ORDER BY id;
-- --------------------------------------------------------------------

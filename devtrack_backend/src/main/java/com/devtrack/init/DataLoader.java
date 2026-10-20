package com.devtrack.init;

import com.devtrack.model.*;
import com.devtrack.repository.*;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

import java.time.LocalDate;
import java.time.LocalDateTime;

@Component
public class DataLoader implements CommandLineRunner {

    private final UserRepository userRepository;
    private final DepartmentRepository departmentRepository;
    private final TeamRepository teamRepository;
    private final TeamMemberRepository teamMemberRepository;
    private final ProjectRepository projectRepository;
    private final ProjectMemberRepository projectMemberRepository;
    private final IssueRepository issueRepository;
    private final IssueCommentRepository commentRepository;
    private final IssueHistoryRepository historyRepository;
    private final TimeEntryRepository timeEntryRepository;
    private final NotificationRepository notificationRepository;
    private final AuditLogRepository auditLogRepository;
    private final PasswordEncoder passwordEncoder;

    public DataLoader(UserRepository userRepository,
                      DepartmentRepository departmentRepository,
                      TeamRepository teamRepository,
                      TeamMemberRepository teamMemberRepository,
                      ProjectRepository projectRepository,
                      ProjectMemberRepository projectMemberRepository,
                      IssueRepository issueRepository,
                      IssueCommentRepository commentRepository,
                      IssueHistoryRepository historyRepository,
                      TimeEntryRepository timeEntryRepository,
                      NotificationRepository notificationRepository,
                      AuditLogRepository auditLogRepository,
                      PasswordEncoder passwordEncoder) {
        this.userRepository = userRepository;
        this.departmentRepository = departmentRepository;
        this.teamRepository = teamRepository;
        this.teamMemberRepository = teamMemberRepository;
        this.projectRepository = projectRepository;
        this.projectMemberRepository = projectMemberRepository;
        this.issueRepository = issueRepository;
        this.commentRepository = commentRepository;
        this.historyRepository = historyRepository;
        this.timeEntryRepository = timeEntryRepository;
        this.notificationRepository = notificationRepository;
        this.auditLogRepository = auditLogRepository;
        this.passwordEncoder = passwordEncoder;
    }

    @Override
    public void run(String... args) {
        // Always ensure the Super Admin account exists and is ready for use
        User superAdmin = userRepository.findByEmail("superadmin@devtrack.com").orElse(null);
        if (superAdmin == null) {
            superAdmin = new User(null, "Super Admin", "superadmin@devtrack.com",
                    passwordEncoder.encode("admin123"), RoleType.SUPER_ADMIN, "Executive", "System Super Admin");
            superAdmin = userRepository.save(superAdmin);
            System.out.println("Super Admin verified/created: superadmin@devtrack.com / admin123");
        }

        // Always ensure Team Lead account exists
        User leadSuresh = userRepository.findByEmail("suresh.lead@devtrack.com").orElse(null);
        if (leadSuresh == null) {
            leadSuresh = new User(null, "Suresh Lead", "suresh.lead@devtrack.com",
                    passwordEncoder.encode("password123"), RoleType.TEAM_LEAD, "Engineering", "Technical Team Lead");
            leadSuresh = userRepository.save(leadSuresh);
            System.out.println("Team Lead verified/created: suresh.lead@devtrack.com / password123");
        }

        // Backfill managerId and teamLeadId for any existing teams
        User managerArun = userRepository.findByEmail("arun.manager@devtrack.com").orElse(null);
        if (managerArun != null && leadSuresh != null) {
            for (Team t : teamRepository.findAll()) {
                boolean modified = false;
                if (t.getManagerId() == null) {
                    t.setManagerId(managerArun.getId());
                    modified = true;
                }
                if (t.getTeamLeadId() == null) {
                    t.setTeamLeadId(leadSuresh.getId());
                    modified = true;
                }
                if (modified) {
                    teamRepository.save(t);
                    if (teamMemberRepository.findByTeamIdAndUserId(t.getId(), managerArun.getId()).isEmpty()) {
                        teamMemberRepository.save(new TeamMember(t.getId(), managerArun.getId()));
                    }
                    if (teamMemberRepository.findByTeamIdAndUserId(t.getId(), leadSuresh.getId()).isEmpty()) {
                        teamMemberRepository.save(new TeamMember(t.getId(), leadSuresh.getId()));
                    }
                }
            }
        }

        if (departmentRepository.count() > 0 || projectRepository.count() > 0) {
            return; // Remainder of seed data already initialized
        }

        System.out.println("Initializing DevTrack with realistic sample data...");

        // 1. Seed Users (All 4 hierarchy levels)
        User admin = userRepository.findByEmail("admin@devtrack.com").orElse(null);
        if (admin == null) {
            admin = new User(null, "Divya Admin", "admin@devtrack.com",
                    passwordEncoder.encode("admin123"), RoleType.ADMIN, "Operations", "Organization Admin");
            admin = userRepository.save(admin);
        }

        if (managerArun == null) {
            managerArun = new User(null, "Arun Kumar", "arun.manager@devtrack.com",
                    passwordEncoder.encode("password123"), RoleType.MANAGER, "Engineering", "Engineering Manager");
            managerArun = userRepository.save(managerArun);
        }

        User empKarthi = userRepository.findByEmail("karthi.dev@devtrack.com").orElse(null);
        if (empKarthi == null) {
            empKarthi = new User(null, "Karthi Raman", "karthi.dev@devtrack.com",
                    passwordEncoder.encode("password123"), RoleType.EMPLOYEE, "Engineering", "Frontend Developer");
            empKarthi = userRepository.save(empKarthi);
        }

        User empPriya = userRepository.findByEmail("priya.dev@devtrack.com").orElse(null);
        if (empPriya == null) {
            empPriya = new User(null, "Priya Sharma", "priya.dev@devtrack.com",
                    passwordEncoder.encode("password123"), RoleType.EMPLOYEE, "Engineering", "Backend API Developer");
            empPriya = userRepository.save(empPriya);
        }

        User testerVijay = userRepository.findByEmail("vijay.qa@devtrack.com").orElse(null);
        if (testerVijay == null) {
            testerVijay = new User(null, "Vijay Tester", "vijay.qa@devtrack.com",
                    passwordEncoder.encode("password123"), RoleType.EMPLOYEE, "Quality Assurance", "QA Automation Tester");
            testerVijay = userRepository.save(testerVijay);
        }

        // 2. Seed Departments
        Department deptEng = departmentRepository.save(new Department("Engineering", "ENG", "Software engineering and development"));
        Department deptQA = departmentRepository.save(new Department("Quality Assurance", "QA", "Software quality and testing"));
        Department deptOps = departmentRepository.save(new Department("Operations & Support", "OPS", "Production operations and support"));

        // 3. Seed Teams (Explicit Department + Manager + Team Lead)
        Team teamWeb = teamRepository.save(new Team("Web Development Team", deptEng.getId(), managerArun.getId(), leadSuresh.getId(), "Fullstack web apps"));
        Team teamMob = teamRepository.save(new Team("Mobile & Cloud Team", deptEng.getId(), managerArun.getId(), leadSuresh.getId(), "Mobile app solutions"));
        Team teamQA = teamRepository.save(new Team("Core QA Team", deptQA.getId(), managerArun.getId(), testerVijay.getId(), "Regression and test automation"));

        teamMemberRepository.save(new TeamMember(teamWeb.getId(), managerArun.getId()));
        teamMemberRepository.save(new TeamMember(teamWeb.getId(), leadSuresh.getId()));
        teamMemberRepository.save(new TeamMember(teamWeb.getId(), empKarthi.getId()));
        teamMemberRepository.save(new TeamMember(teamWeb.getId(), empPriya.getId()));
        teamMemberRepository.save(new TeamMember(teamMob.getId(), managerArun.getId()));
        teamMemberRepository.save(new TeamMember(teamMob.getId(), leadSuresh.getId()));
        teamMemberRepository.save(new TeamMember(teamMob.getId(), empKarthi.getId()));
        teamMemberRepository.save(new TeamMember(teamQA.getId(), managerArun.getId()));
        teamMemberRepository.save(new TeamMember(teamQA.getId(), testerVijay.getId()));

        // 4. Seed Projects
        Project projWeb = projectRepository.save(new Project(
                "WEB", "Website Development", "Company client web portal and internal tools",
                managerArun.getId(), LocalDate.now().minusDays(15), LocalDate.now().plusDays(45)));

        Project projMob = projectRepository.save(new Project(
                "MOB", "Mobile Application", "Android and iOS customer mobile app",
                managerArun.getId(), LocalDate.now().minusDays(30), LocalDate.now().plusDays(60)));

        Project projPay = projectRepository.save(new Project(
                "PAY", "Payment System Integration", "Razorpay, Stripe and UPI payment gateways",
                managerArun.getId(), LocalDate.now().minusDays(10), LocalDate.now().plusDays(30)));

        // Project memberships
        projectMemberRepository.save(new ProjectMember(projWeb.getId(), managerArun.getId(), ProjectRole.PROJECT_MANAGER));
        projectMemberRepository.save(new ProjectMember(projWeb.getId(), empKarthi.getId(), ProjectRole.DEVELOPER));
        projectMemberRepository.save(new ProjectMember(projWeb.getId(), empPriya.getId(), ProjectRole.DEVELOPER));
        projectMemberRepository.save(new ProjectMember(projWeb.getId(), testerVijay.getId(), ProjectRole.TESTER));

        projectMemberRepository.save(new ProjectMember(projMob.getId(), managerArun.getId(), ProjectRole.PROJECT_MANAGER));
        projectMemberRepository.save(new ProjectMember(projMob.getId(), empKarthi.getId(), ProjectRole.DEVELOPER));
        projectMemberRepository.save(new ProjectMember(projMob.getId(), testerVijay.getId(), ProjectRole.TESTER));

        projectMemberRepository.save(new ProjectMember(projPay.getId(), managerArun.getId(), ProjectRole.PROJECT_MANAGER));
        projectMemberRepository.save(new ProjectMember(projPay.getId(), empPriya.getId(), ProjectRole.DEVELOPER));

        // 5. Seed Issues (From User's Real Scenario)
        // BUG-101: Login button not working (Critical, Karthi, Open)
        Issue bug101 = new Issue("WEB-101", projWeb.getId(), "Login button not working",
                "Clicking login button does not trigger validation or form submission on Chrome and Edge.",
                IssueType.BUG, IssuePriority.CRITICAL, IssueStatus.OPEN, managerArun.getId(), empKarthi.getId(),
                LocalDate.now().plusDays(3), 180);
        bug101 = issueRepository.save(bug101);

        historyRepository.save(new IssueHistory(bug101.getId(), managerArun.getId(), managerArun.getFullName(),
                "CREATED", null, "OPEN"));
        historyRepository.save(new IssueHistory(bug101.getId(), managerArun.getId(), managerArun.getFullName(),
                "ASSIGNEE", "Unassigned", empKarthi.getFullName()));

        commentRepository.save(new IssueComment(bug101.getId(), managerArun.getId(), managerArun.getFullName(),
                "Critical priority issue. Please investigate the onClick event handler and form submission logic."));

        // TASK-102: Build login API (In Progress, Priya)
        Issue task102 = new Issue("WEB-102", projWeb.getId(), "Build login API",
                "Implement JWT authentication endpoint POST /api/v1/auth/login with BCrypt password hashing.",
                IssueType.TASK, IssuePriority.HIGH, IssueStatus.IN_PROGRESS, managerArun.getId(), empPriya.getId(),
                LocalDate.now().plusDays(5), 360);
        task102.setActualMinutes(120);
        task102 = issueRepository.save(task102);

        historyRepository.save(new IssueHistory(task102.getId(), managerArun.getId(), managerArun.getFullName(),
                "CREATED", null, "OPEN"));
        historyRepository.save(new IssueHistory(task102.getId(), empPriya.getId(), empPriya.getFullName(),
                "STATUS", "ASSIGNED", "IN_PROGRESS"));

        timeEntryRepository.save(new TimeEntry(task102.getId(), empPriya.getId(), empPriya.getFullName(),
                120, "Implemented JWT token creation and security filter chains"));

        // TASK-103: Test registration form (Resolved, Vijay)
        Issue task103 = new Issue("WEB-103", projWeb.getId(), "Test registration form",
                "Perform cross-browser validation and automated test execution for customer registration page.",
                IssueType.TASK, IssuePriority.MEDIUM, IssueStatus.RESOLVED, managerArun.getId(), testerVijay.getId(),
                LocalDate.now().minusDays(1), 240);
        task103.setActualMinutes(240);
        task103.setResolvedAt(LocalDateTime.now().minusHours(4));
        task103 = issueRepository.save(task103);

        historyRepository.save(new IssueHistory(task103.getId(), testerVijay.getId(), testerVijay.getFullName(),
                "STATUS", "IN_PROGRESS", "RESOLVED"));
        commentRepository.save(new IssueComment(task103.getId(), testerVijay.getId(), testerVijay.getFullName(),
                "Test suite executed. All 24 test cases passed on Chrome, Firefox, and Edge. Fix verified."));

        // Additional issues for MOB and PAY
        Issue bug201 = new Issue("MOB-201", projMob.getId(), "Push notification crash on Android 14",
                "App closes unexpectedly when receiving push notification payload while in background state.",
                IssueType.BUG, IssuePriority.HIGH, IssueStatus.IN_REVIEW, managerArun.getId(), empKarthi.getId(),
                LocalDate.now().plusDays(2), 300);
        bug201.setActualMinutes(280);
        issueRepository.save(bug201);

        Issue task301 = new Issue("PAY-301", projPay.getId(), "Stripe Webhook Handler",
                "Build idempotent webhook listener for Stripe payment success and failure events.",
                IssueType.FEATURE, IssuePriority.HIGH, IssueStatus.OPEN, managerArun.getId(), empPriya.getId(),
                LocalDate.now().plusDays(8), 480);
        issueRepository.save(task301);

        // 6. Notifications
        notificationRepository.save(new Notification(empKarthi.getId(), "Urgent Bug Assignment",
                "WEB-101 Login button not working was assigned to you by Arun Kumar", bug101.getId(), "WEB", "ASSIGNMENT"));
        notificationRepository.save(new Notification(managerArun.getId(), "Fix Submitted for Review",
                "MOB-201 Push notification crash fix was submitted by Karthi Raman", bug201.getId(), "MOB", "REVIEW_REQUEST"));

        // 7. Audit Logs
        auditLogRepository.save(new AuditLog(superAdmin.getId(), superAdmin.getFullName(),
                "SYSTEM_INITIALIZATION", "SYSTEM", "0", "DevTrack organizational hierarchy initialized"));
        auditLogRepository.save(new AuditLog(admin.getId(), admin.getFullName(),
                "PROJECT_CREATED", "PROJECT", projWeb.getId().toString(), "Admin created project Website Development"));

        System.out.println("DevTrack initialization complete! Ready for Admin, Manager, and Employee.");
    }
}

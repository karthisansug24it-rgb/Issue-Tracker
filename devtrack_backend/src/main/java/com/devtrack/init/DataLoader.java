package com.devtrack.init;

import com.devtrack.model.*;
import com.devtrack.repository.*;
import com.devtrack.service.OrganizationService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

/**
 * Startup tasks, all idempotent:
 *  1. Make sure at least one active Super Admin exists (bootstrap account).
 *  2. On an empty database, optionally load demo data (devtrack.seed.demo-data).
 *  3. Link users whose department is only free text to the matching Department row.
 *
 * It never rewrites existing teams, projects or issues.
 */
@Component
public class DataLoader implements CommandLineRunner {

    private static final Logger log = LoggerFactory.getLogger(DataLoader.class);

    // Demo accounts (documented in README). Only created when demo data is enabled.
    private static final String DEMO_PASSWORD = "qwerty123";
    private static final String DEMO_ADMIN_PASSWORD = "qwerty123";

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
    private final OrganizationService organizationService;

    @Value("${devtrack.seed.demo-data:true}")
    private boolean seedDemoData;

    @Value("${devtrack.bootstrap.admin-email:superadmin@devtrack.com}")
    private String bootstrapAdminEmail;

    @Value("${devtrack.bootstrap.admin-password:}")
    private String bootstrapAdminPassword;

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
                      PasswordEncoder passwordEncoder,
                      OrganizationService organizationService) {
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
        this.organizationService = organizationService;
    }

    @Override
    @Transactional
    public void run(String... args) {
        if (seedDemoData && departmentRepository.count() == 0 && projectRepository.count() == 0) {
            seedDemoData();
        }
        ensureSuperAdmin();
        linkUserDepartments();
    }

    // ------------------------------------------------------------ bootstrap

    private void ensureSuperAdmin() {
        if (userRepository.countByRoleAndActiveTrue(RoleType.SUPER_ADMIN) > 0) {
            return;
        }

        String email = bootstrapAdminEmail.trim().toLowerCase();
        User existing = userRepository.findByEmail(email).orElse(null);
        if (existing != null) {
            // Recovery path: no active Super Admin is left, so restore the bootstrap account
            existing.setRole(RoleType.SUPER_ADMIN);
            existing.setActive(true);
            userRepository.save(existing);
            log.warn("No active Super Admin found. Restored Super Admin access for {}", email);
            return;
        }

        String password = bootstrapAdminPassword;
        boolean generated = false;
        if (password == null || password.isBlank()) {
            if (seedDemoData) {
                password = DEMO_ADMIN_PASSWORD;
            } else {
                password = randomPassword();
                generated = true;
            }
        }

        User admin = new User(null, "Super Admin", email, passwordEncoder.encode(password),
                RoleType.SUPER_ADMIN, "Executive", "System Super Admin");
        userRepository.save(admin);
        auditLogRepository.save(new AuditLog(null, "SYSTEM", "SUPER_ADMIN_BOOTSTRAPPED", "USER",
                String.valueOf(admin.getId()), "Initial Super Admin account created: " + email));

        if (generated) {
            log.warn("Created initial Super Admin {} with generated password: {}  (change it after first sign-in)",
                    email, password);
        } else {
            log.info("Created initial Super Admin {}", email);
        }
    }

    private static String randomPassword() {
        String alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789";
        SecureRandom random = new SecureRandom();
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < 16; i++) {
            sb.append(alphabet.charAt(random.nextInt(alphabet.length())));
        }
        return sb.toString();
    }

    /** Links free-text departments (e.g. from older data or registration) to real departments. */
    private void linkUserDepartments() {
        List<User> unlinked = userRepository.findByDepartmentIdIsNull();
        for (User u : unlinked) {
            organizationService.findDepartment(u.getDepartment()).ifPresent(d -> {
                u.setDepartmentId(d.getId());
                u.setDepartment(d.getName());
                userRepository.save(u);
            });
        }
    }

    // ------------------------------------------------------------- demo data

    private User demoUser(String name, String email, String password, RoleType role, Department dept, String title) {
        return userRepository.findByEmail(email).orElseGet(() -> {
            User u = new User(null, name, email, passwordEncoder.encode(password), role,
                    dept != null ? dept.getName() : null, title);
            u.setDepartmentId(dept != null ? dept.getId() : null);
            return userRepository.save(u);
        });
    }

    private void seedDemoData() {
        log.info("Initializing DevTrack with demo data (set SEED_DEMO_DATA=false to disable)...");

        // 1. Departments
        Department deptEng = departmentRepository.save(new Department("Engineering", "ENG", "Software engineering and development"));
        Department deptQA = departmentRepository.save(new Department("Quality Assurance", "QA", "Software quality and testing"));
        Department deptOps = departmentRepository.save(new Department("Operations & Support", "OPS", "Production operations and support"));
        Department deptExec = departmentRepository.save(new Department("Executive", "EXEC", "Leadership and administration"));

        // 2. Users (every hierarchy level, each linked to a real department)
        User superAdmin = demoUser("Super Admin", bootstrapAdminEmail.trim().toLowerCase(),
                bootstrapAdminPassword != null && !bootstrapAdminPassword.isBlank() ? bootstrapAdminPassword : DEMO_ADMIN_PASSWORD,
                RoleType.SUPER_ADMIN, deptExec, "System Super Admin");
        User admin = demoUser("Divya Admin", "admin@devtrack.com", DEMO_ADMIN_PASSWORD, RoleType.ADMIN, deptOps, "Organization Admin");
        User managerArun = demoUser("Arun Kumar", "arun.manager@devtrack.com", DEMO_PASSWORD, RoleType.MANAGER, deptEng, "Engineering Manager");
        User leadSuresh = demoUser("Suresh Lead", "suresh.lead@devtrack.com", DEMO_PASSWORD, RoleType.TEAM_LEAD, deptEng, "Technical Team Lead");
        User empKarthi = demoUser("Karthi Raman", "karthi.dev@devtrack.com", DEMO_PASSWORD, RoleType.EMPLOYEE, deptEng, "Frontend Developer");
        User empPriya = demoUser("Priya Sharma", "priya.dev@devtrack.com", DEMO_PASSWORD, RoleType.EMPLOYEE, deptEng, "Backend API Developer");
        User leadVijay = demoUser("Vijay Tester", "vijay.qa@devtrack.com", DEMO_PASSWORD, RoleType.TEAM_LEAD, deptQA, "QA Automation Lead");

        // 3. Teams (manager is a MANAGER, lead is a TEAM_LEAD)
        Team teamWeb = teamRepository.save(new Team("Web Development Team", deptEng.getId(), managerArun.getId(), leadSuresh.getId(), "Fullstack web apps"));
        Team teamMob = teamRepository.save(new Team("Mobile & Cloud Team", deptEng.getId(), managerArun.getId(), leadSuresh.getId(), "Mobile app solutions"));
        Team teamQA = teamRepository.save(new Team("Core QA Team", deptQA.getId(), managerArun.getId(), leadVijay.getId(), "Regression and test automation"));

        for (User u : List.of(managerArun, leadSuresh, empKarthi, empPriya)) {
            teamMemberRepository.save(new TeamMember(teamWeb.getId(), u.getId()));
        }
        for (User u : List.of(managerArun, leadSuresh, empKarthi)) {
            teamMemberRepository.save(new TeamMember(teamMob.getId(), u.getId()));
        }
        for (User u : List.of(managerArun, leadVijay)) {
            teamMemberRepository.save(new TeamMember(teamQA.getId(), u.getId()));
        }

        // 4. Projects
        Project projWeb = newProject("WEB", "Website Development", "Company client web portal and internal tools",
                managerArun, 15, 45, 104);
        Project projMob = newProject("MOB", "Mobile Application", "Android and iOS customer mobile app",
                managerArun, 30, 60, 102);
        Project projPay = newProject("PAY", "Payment System Integration", "Razorpay, Stripe and UPI payment gateways",
                managerArun, 10, 30, 102);

        member(projWeb, managerArun, ProjectRole.PROJECT_MANAGER);
        member(projWeb, leadSuresh, ProjectRole.TECH_LEAD);
        member(projWeb, empKarthi, ProjectRole.DEVELOPER);
        member(projWeb, empPriya, ProjectRole.DEVELOPER);
        member(projWeb, leadVijay, ProjectRole.TESTER);

        member(projMob, managerArun, ProjectRole.PROJECT_MANAGER);
        member(projMob, leadSuresh, ProjectRole.TECH_LEAD);
        member(projMob, empKarthi, ProjectRole.DEVELOPER);
        member(projMob, leadVijay, ProjectRole.TESTER);

        member(projPay, managerArun, ProjectRole.PROJECT_MANAGER);
        member(projPay, empPriya, ProjectRole.DEVELOPER);

        // 5. Issues (statuses consistent with the workflow: assigned issues start as ASSIGNED)
        Issue bug101 = issueRepository.save(new Issue("WEB-101", projWeb.getId(), "Login button not working",
                "Clicking login button does not trigger validation or form submission on Chrome and Edge.",
                IssueType.BUG, IssuePriority.CRITICAL, IssueStatus.ASSIGNED, managerArun.getId(), empKarthi.getId(),
                LocalDate.now().plusDays(3), 180));
        historyRepository.save(new IssueHistory(bug101.getId(), managerArun.getId(), managerArun.getFullName(),
                "CREATED", null, "ASSIGNED"));
        commentRepository.save(new IssueComment(bug101.getId(), managerArun.getId(), managerArun.getFullName(),
                "Critical priority issue. Please investigate the onClick event handler and form submission logic."));

        Issue task102 = new Issue("WEB-102", projWeb.getId(), "Build login API",
                "Implement JWT authentication endpoint POST /api/v1/auth/login with BCrypt password hashing.",
                IssueType.TASK, IssuePriority.HIGH, IssueStatus.IN_PROGRESS, managerArun.getId(), empPriya.getId(),
                LocalDate.now().plusDays(5), 360);
        task102.setActualMinutes(120);
        task102 = issueRepository.save(task102);
        historyRepository.save(new IssueHistory(task102.getId(), managerArun.getId(), managerArun.getFullName(),
                "CREATED", null, "ASSIGNED"));
        historyRepository.save(new IssueHistory(task102.getId(), empPriya.getId(), empPriya.getFullName(),
                "STATUS", "ASSIGNED", "IN_PROGRESS"));
        timeEntryRepository.save(new TimeEntry(task102.getId(), empPriya.getId(), empPriya.getFullName(),
                120, "Implemented JWT token creation and security filter chains"));

        Issue task103 = new Issue("WEB-103", projWeb.getId(), "Test registration form",
                "Perform cross-browser validation and automated test execution for customer registration page.",
                IssueType.TASK, IssuePriority.MEDIUM, IssueStatus.RESOLVED, managerArun.getId(), leadVijay.getId(),
                LocalDate.now().minusDays(1), 240);
        task103.setActualMinutes(240);
        task103.setResolvedAt(LocalDateTime.now().minusHours(4));
        task103 = issueRepository.save(task103);
        historyRepository.save(new IssueHistory(task103.getId(), managerArun.getId(), managerArun.getFullName(),
                "STATUS", "IN_REVIEW", "RESOLVED"));
        commentRepository.save(new IssueComment(task103.getId(), leadVijay.getId(), leadVijay.getFullName(),
                "Test suite executed. All 24 test cases passed on Chrome, Firefox, and Edge. Fix verified."));

        Issue bug201 = new Issue("MOB-101", projMob.getId(), "Push notification crash on Android 14",
                "App closes unexpectedly when receiving push notification payload while in background state.",
                IssueType.BUG, IssuePriority.HIGH, IssueStatus.IN_REVIEW, managerArun.getId(), empKarthi.getId(),
                LocalDate.now().plusDays(2), 300);
        bug201.setActualMinutes(280);
        bug201 = issueRepository.save(bug201);

        issueRepository.save(new Issue("PAY-101", projPay.getId(), "Stripe Webhook Handler",
                "Build idempotent webhook listener for Stripe payment success and failure events.",
                IssueType.FEATURE, IssuePriority.HIGH, IssueStatus.ASSIGNED, managerArun.getId(), empPriya.getId(),
                LocalDate.now().plusDays(8), 480));

        // 6. Notifications
        notificationRepository.save(new Notification(empKarthi.getId(), "Urgent Bug Assignment",
                "WEB-101 Login button not working was assigned to you by Arun Kumar", bug101.getId(), "WEB", "ASSIGNMENT"));
        notificationRepository.save(new Notification(managerArun.getId(), "Fix Submitted for Review",
                "MOB-101 Push notification crash fix was submitted by Karthi Raman", bug201.getId(), "MOB", "REVIEW_REQUEST"));

        // 7. Audit Logs
        auditLogRepository.save(new AuditLog(superAdmin.getId(), superAdmin.getFullName(),
                "SYSTEM_INITIALIZATION", "SYSTEM", "0", "DevTrack demo organization initialized"));
        auditLogRepository.save(new AuditLog(admin.getId(), admin.getFullName(),
                "PROJECT_CREATED", "PROJECT", projWeb.getId().toString(), "Admin created project Website Development"));

        log.info("Demo data loaded. Demo accounts are listed in README.md (change their passwords for shared use).");
    }

    private Project newProject(String key, String name, String description, User owner,
                               int startedDaysAgo, int endsInDays, int nextIssueNumber) {
        Project p = new Project(key, name, description, owner.getId(),
                LocalDate.now().minusDays(startedDaysAgo), LocalDate.now().plusDays(endsInDays));
        p.setNextIssueNumber(nextIssueNumber);
        return projectRepository.save(p);
    }

    private void member(Project project, User user, ProjectRole role) {
        projectMemberRepository.save(new ProjectMember(project.getId(), user.getId(), role));
    }
}

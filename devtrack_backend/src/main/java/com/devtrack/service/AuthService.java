package com.devtrack.service;

import com.devtrack.dto.AuthRequest;
import com.devtrack.dto.AuthResponse;
import com.devtrack.dto.RegisterRequest;
import com.devtrack.dto.UserDto;
import com.devtrack.model.AuditLog;
import com.devtrack.model.RoleType;
import com.devtrack.model.User;
import com.devtrack.repository.AuditLogRepository;
import com.devtrack.repository.UserRepository;
import com.devtrack.security.JwtUtils;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;

@Service
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtUtils jwtUtils;
    private final AuditLogRepository auditLogRepository;

    public AuthService(UserRepository userRepository, PasswordEncoder passwordEncoder,
                       JwtUtils jwtUtils, AuditLogRepository auditLogRepository) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtUtils = jwtUtils;
        this.auditLogRepository = auditLogRepository;
    }

    public AuthResponse login(AuthRequest request) {
        User user = userRepository.findByEmail(request.getEmail().trim().toLowerCase())
                .orElseThrow(() -> new RuntimeException("Invalid email or password"));

        if (!user.isActive()) {
            throw new RuntimeException("Account is disabled. Contact your administrator.");
        }

        if (!passwordEncoder.matches(request.getPassword(), user.getPassword())) {
            throw new RuntimeException("Invalid email or password");
        }

        String token = jwtUtils.generateToken(user.getEmail(), user.getRole().name());

        List<String> permissions = getPermissionsForRole(user.getRole());

        auditLogRepository.save(new AuditLog(user.getId(), user.getFullName(), "USER_LOGIN", "USER",
                user.getId().toString(), "User logged in with role: " + user.getRole()));

        return new AuthResponse(token, user.getId(), user.getFullName(), user.getEmail(),
                user.getRole(), user.getDepartment(), user.getJobTitle(), user.getAvatarUrl(), permissions);
    }

    public UserDto register(RegisterRequest request) {
        String email = request.getEmail().trim().toLowerCase();
        if (userRepository.existsByEmail(email)) {
            throw new RuntimeException("Email already registered: " + email);
        }

        // Rule: All new accounts created publicly start with the basic user role (EMPLOYEE).
        // If this is the very first account created in an empty database, it becomes SUPER_ADMIN.
        // Subsequent role upgrades (Manager, Admin, Super Admin) are performed by administrators.
        RoleType assignedRole = RoleType.EMPLOYEE;
        if (userRepository.count() == 0) {
            assignedRole = RoleType.SUPER_ADMIN;
        }

        User user = new User();
        user.setFullName(request.getFullName().trim());
        user.setEmail(email);
        user.setPassword(passwordEncoder.encode(request.getPassword()));
        user.setRole(assignedRole);
        user.setDepartment(request.getDepartment() != null && !request.getDepartment().isBlank()
                ? request.getDepartment().trim() : "Engineering");
        user.setJobTitle(request.getJobTitle() != null && !request.getJobTitle().isBlank()
                ? request.getJobTitle().trim() : "Employee");
        user.setActive(true);

        User saved = userRepository.save(user);

        auditLogRepository.save(new AuditLog(null, "SYSTEM", "USER_REGISTERED", "USER",
                saved.getId().toString(), "New user created: " + saved.getFullName() + " (" + saved.getRole() + ")"));

        return UserDto.fromEntity(saved);
    }

    private List<String> getPermissionsForRole(RoleType role) {
        List<String> perms = new ArrayList<>();
        switch (role) {
            case SUPER_ADMIN:
                perms.add("SYSTEM_MANAGE");
                perms.add("ADMIN_MANAGE");
                perms.add("ALL_PROJECTS_VIEW");
                perms.add("AUDIT_LOG_VIEW");
                perms.add("GLOBAL_SETTINGS");
                // fall through
            case ADMIN:
                perms.add("DEPARTMENT_MANAGE");
                perms.add("TEAM_MANAGE");
                perms.add("USER_MANAGE");
                perms.add("PROJECT_CREATE");
                perms.add("PROJECT_ASSIGN");
                perms.add("REPORTS_VIEW");
                // fall through
            case MANAGER:
                perms.add("TEAM_LEAD_ASSIGN");
                perms.add("PROJECT_MANAGE");
                perms.add("TEAM_REPORTS_VIEW");
                // fall through
            case TEAM_LEAD:
                perms.add("ISSUE_CREATE");
                perms.add("ISSUE_ASSIGN");
                perms.add("ISSUE_REVIEW");
                perms.add("TEAM_SPRINT_MANAGE");
                // fall through
            case EMPLOYEE:
                perms.add("MY_ISSUES_VIEW");
                perms.add("ISSUE_UPDATE_STATUS");
                perms.add("COMMENT_ADD");
                perms.add("TIME_LOG");
                break;
        }
        return perms;
    }
}

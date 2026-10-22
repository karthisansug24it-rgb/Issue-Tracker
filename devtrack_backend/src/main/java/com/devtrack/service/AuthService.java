package com.devtrack.service;

import com.devtrack.dto.AuthRequest;
import com.devtrack.dto.AuthResponse;
import com.devtrack.dto.RegisterRequest;
import com.devtrack.dto.UserDto;
import com.devtrack.exception.ConflictException;
import com.devtrack.exception.ForbiddenException;
import com.devtrack.exception.UnauthorizedException;
import com.devtrack.model.AuditLog;
import com.devtrack.model.RoleType;
import com.devtrack.model.User;
import com.devtrack.repository.AuditLogRepository;
import com.devtrack.repository.UserRepository;
import com.devtrack.security.JwtUtils;
import com.devtrack.security.RolePermissions;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtUtils jwtUtils;
    private final AuditLogRepository auditLogRepository;
    private final OrganizationService organizationService;

    public AuthService(UserRepository userRepository, PasswordEncoder passwordEncoder,
                       JwtUtils jwtUtils, AuditLogRepository auditLogRepository,
                       OrganizationService organizationService) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtUtils = jwtUtils;
        this.auditLogRepository = auditLogRepository;
        this.organizationService = organizationService;
    }

    public AuthResponse login(AuthRequest request) {
        User user = userRepository.findByEmail(request.getEmail().trim().toLowerCase())
                .orElseThrow(() -> new UnauthorizedException("Invalid email or password"));

        // Check the password before revealing whether the account is disabled
        if (!passwordEncoder.matches(request.getPassword(), user.getPassword())) {
            throw new UnauthorizedException("Invalid email or password");
        }

        if (!user.isActive()) {
            throw new ForbiddenException("Account is disabled. Contact your administrator.");
        }

        String token = jwtUtils.generateToken(user.getEmail(), user.getRole().name());

        auditLogRepository.save(new AuditLog(user.getId(), user.getFullName(), "USER_LOGIN", "USER",
                user.getId().toString(), "User logged in with role: " + user.getRole()));

        return AuthResponse.of(token, user, RolePermissions.forRole(user.getRole()));
    }

    public AuthResponse currentUser(User user) {
        return AuthResponse.of(null, user, RolePermissions.forRole(user.getRole()));
    }

    @Transactional
    public UserDto register(RegisterRequest request) {
        String email = request.getEmail().trim().toLowerCase();
        if (userRepository.existsByEmail(email)) {
            throw new ConflictException("Email already registered: " + email);
        }

        // Every publicly created account starts as EMPLOYEE. Promotions are done by
        // administrators; the first Super Admin is bootstrapped by DataLoader.
        User user = new User();
        user.setFullName(request.getFullName().trim());
        user.setEmail(email);
        user.setPassword(passwordEncoder.encode(request.getPassword()));
        user.setRole(RoleType.EMPLOYEE);
        user.setJobTitle(request.getJobTitle() != null && !request.getJobTitle().isBlank()
                ? request.getJobTitle().trim() : "Employee");
        user.setActive(true);
        organizationService.applyDepartment(user, request.getDepartment());

        User saved = userRepository.save(user);

        auditLogRepository.save(new AuditLog(null, "SYSTEM", "USER_REGISTERED", "USER",
                saved.getId().toString(), "New user created: " + saved.getFullName() + " (" + saved.getRole() + ")"));

        return UserDto.fromEntity(saved);
    }
}

package com.devtrack.service;

import com.devtrack.dto.UserDto;
import com.devtrack.model.AuditLog;
import com.devtrack.model.RoleType;
import com.devtrack.model.User;
import com.devtrack.repository.AuditLogRepository;
import com.devtrack.repository.UserRepository;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.stream.Collectors;

@Service
public class UserService {

    private final UserRepository userRepository;
    private final AuditLogRepository auditLogRepository;

    public UserService(UserRepository userRepository, AuditLogRepository auditLogRepository) {
        this.userRepository = userRepository;
        this.auditLogRepository = auditLogRepository;
    }

    public List<UserDto> getAllUsers() {
        return userRepository.findAll().stream()
                .map(UserDto::fromEntity)
                .collect(Collectors.toList());
    }

    public List<UserDto> getActiveUsers() {
        return userRepository.findByActiveTrue().stream()
                .map(UserDto::fromEntity)
                .collect(Collectors.toList());
    }

    public UserDto getUserById(Long id) {
        User user = userRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("User not found with id: " + id));
        return UserDto.fromEntity(user);
    }

    private int getRoleRank(RoleType role) {
        if (role == null) return 0;
        return switch (role) {
            case SUPER_ADMIN -> 5;
            case ADMIN -> 4;
            case MANAGER -> 3;
            case TEAM_LEAD -> 2;
            case EMPLOYEE -> 1;
        };
    }

    public UserDto updateUserRole(Long id, RoleType newRole, User actor) {
        User user = userRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("User not found: " + id));

        int actorRank = getRoleRank(actor.getRole());
        int targetCurrentRank = getRoleRank(user.getRole());
        int newRoleRank = getRoleRank(newRole);

        // Security check: actor must be at least MANAGER
        if (actorRank < 3) {
            throw new SecurityException("Unauthorized: Only Managers, Admins, and Super Admins can update roles.");
        }

        // Actor cannot modify someone of higher or equal rank (unless actor is SUPER_ADMIN)
        if (actor.getRole() != RoleType.SUPER_ADMIN && targetCurrentRank >= actorRank) {
            throw new SecurityException("Access Denied: You cannot modify a user with an equal or higher role (" + user.getRole() + ").");
        }

        // Manager can only assign TEAM_LEAD or EMPLOYEE
        if (actor.getRole() == RoleType.MANAGER && newRoleRank > 2) {
            throw new SecurityException("Access Denied: Managers can only assign Team Lead or Employee roles.");
        }

        // Admin cannot grant Super Admin privileges
        if (actor.getRole() == RoleType.ADMIN && newRole == RoleType.SUPER_ADMIN) {
            throw new SecurityException("Access Denied: Admins cannot grant Super Admin privileges.");
        }

        RoleType oldRole = user.getRole();
        user.setRole(newRole);
        User saved = userRepository.save(user);

        auditLogRepository.save(new AuditLog(actor.getId(), actor.getFullName(), "ROLE_UPDATED",
                "USER", id.toString(), "Changed role of " + user.getFullName() + " from " + oldRole + " to " + newRole));

        return UserDto.fromEntity(saved);
    }

    public UserDto toggleUserStatus(Long id, User actor) {
        User user = userRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("User not found: " + id));

        user.setActive(!user.isActive());
        User saved = userRepository.save(user);

        auditLogRepository.save(new AuditLog(actor.getId(), actor.getFullName(),
                user.isActive() ? "USER_ENABLED" : "USER_DISABLED",
                "USER", id.toString(), "Toggled active state to: " + user.isActive()));

        return UserDto.fromEntity(saved);
    }
}

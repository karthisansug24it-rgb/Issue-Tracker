package com.devtrack.service;

import com.devtrack.dto.UserDto;
import com.devtrack.exception.ForbiddenException;
import com.devtrack.exception.NotFoundException;
import com.devtrack.model.AuditLog;
import com.devtrack.model.RoleType;
import com.devtrack.model.User;
import com.devtrack.repository.AuditLogRepository;
import com.devtrack.repository.UserRepository;
import com.devtrack.security.AccessService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

@Service
public class UserService {

    private final UserRepository userRepository;
    private final AuditLogRepository auditLogRepository;
    private final AccessService accessService;

    public UserService(UserRepository userRepository, AuditLogRepository auditLogRepository,
                       AccessService accessService) {
        this.userRepository = userRepository;
        this.auditLogRepository = auditLogRepository;
        this.accessService = accessService;
    }

    private UserDto toDto(User user, User viewer) {
        UserDto dto = UserDto.fromEntity(user);
        dto.setCanModify(accessService.canModifyUser(viewer, user));
        return dto;
    }

    public List<UserDto> getAllUsers(User viewer) {
        return userRepository.findAll().stream()
                .map(u -> toDto(u, viewer))
                .collect(Collectors.toList());
    }

    public List<UserDto> getActiveUsers(User viewer) {
        return userRepository.findByActiveTrue().stream()
                .map(u -> toDto(u, viewer))
                .collect(Collectors.toList());
    }

    public UserDto getUserById(Long id, User viewer) {
        // Employees may only look up their own profile
        if (!viewer.getId().equals(id) && !viewer.getRole().isAtLeast(RoleType.TEAM_LEAD)) {
            throw new ForbiddenException("You can only view your own profile.");
        }
        return toDto(findUser(id), viewer);
    }

    private User findUser(Long id) {
        return userRepository.findById(id)
                .orElseThrow(() -> new NotFoundException("User not found: " + id));
    }

    @Transactional
    public UserDto updateUserRole(Long id, RoleType newRole, User actor) {
        User user = findUser(id);

        // Covers: no self-changes, target must be within the actor's authority
        accessService.checkCanModifyUser(actor, user);

        RoleType max = accessService.maxAssignableRole(actor);
        if (newRole.getRank() > max.getRank()) {
            throw new ForbiddenException("You can assign roles up to " + max + " only.");
        }

        RoleType oldRole = user.getRole();
        if (oldRole == newRole) {
            return toDto(user, actor);
        }
        user.setRole(newRole);
        User saved = userRepository.save(user);

        auditLogRepository.save(new AuditLog(actor.getId(), actor.getFullName(), "ROLE_UPDATED",
                "USER", id.toString(), "Changed role of " + user.getFullName() + " from " + oldRole + " to " + newRole));

        return toDto(saved, actor);
    }

    @Transactional
    public UserDto toggleUserStatus(Long id, User actor) {
        User user = findUser(id);

        // Same authority rules as role changes. Because nobody can disable themselves,
        // the acting Super Admin always remains, so the system never loses its last one.
        accessService.checkCanModifyUser(actor, user);

        user.setActive(!user.isActive());
        User saved = userRepository.save(user);

        auditLogRepository.save(new AuditLog(actor.getId(), actor.getFullName(),
                user.isActive() ? "USER_ENABLED" : "USER_DISABLED",
                "USER", id.toString(), (user.isActive() ? "Enabled " : "Disabled ") + user.getFullName()));

        return toDto(saved, actor);
    }
}

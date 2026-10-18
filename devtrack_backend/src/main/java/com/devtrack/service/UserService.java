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

    public UserDto updateUserRole(Long id, RoleType newRole, User actor) {
        User user = userRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("User not found: " + id));

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

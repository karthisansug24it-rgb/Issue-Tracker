package com.devtrack.controller;

import com.devtrack.dto.UserDto;
import com.devtrack.model.RoleType;
import com.devtrack.model.User;
import com.devtrack.service.UserService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/users")
public class UserController {

    private final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    @GetMapping
    public ResponseEntity<List<UserDto>> getAllUsers() {
        return ResponseEntity.ok(userService.getAllUsers());
    }

    @GetMapping("/active")
    public ResponseEntity<List<UserDto>> getActiveUsers() {
        return ResponseEntity.ok(userService.getActiveUsers());
    }

    @GetMapping("/{id}")
    public ResponseEntity<UserDto> getUserById(@PathVariable Long id) {
        return ResponseEntity.ok(userService.getUserById(id));
    }

    @PatchMapping("/{id}/role")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN')")
    public ResponseEntity<UserDto> updateRole(@PathVariable Long id,
                                             @RequestBody Map<String, String> body,
                                             @AuthenticationPrincipal User actor) {
        RoleType role = RoleType.valueOf(body.get("role"));
        return ResponseEntity.ok(userService.updateUserRole(id, role, actor));
    }

    @PatchMapping("/{id}/status")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN')")
    public ResponseEntity<UserDto> toggleStatus(@PathVariable Long id,
                                                @AuthenticationPrincipal User actor) {
        return ResponseEntity.ok(userService.toggleUserStatus(id, actor));
    }
}

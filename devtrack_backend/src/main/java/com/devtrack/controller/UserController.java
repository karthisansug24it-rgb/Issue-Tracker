package com.devtrack.controller;

import com.devtrack.dto.UpdateRoleRequest;
import com.devtrack.dto.UserDto;
import com.devtrack.model.User;
import com.devtrack.service.UserService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/users")
public class UserController {

    private final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    // The staff directory (with emails) is for Team Lead and above.
    // Employees pick assignees from GET /projects/{id}/members instead.
    @GetMapping
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN', 'MANAGER', 'TEAM_LEAD')")
    public ResponseEntity<List<UserDto>> getAllUsers(@AuthenticationPrincipal User viewer) {
        return ResponseEntity.ok(userService.getAllUsers(viewer));
    }

    @GetMapping("/active")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN', 'MANAGER', 'TEAM_LEAD')")
    public ResponseEntity<List<UserDto>> getActiveUsers(@AuthenticationPrincipal User viewer) {
        return ResponseEntity.ok(userService.getActiveUsers(viewer));
    }

    @GetMapping("/{id}")
    public ResponseEntity<UserDto> getUserById(@PathVariable Long id, @AuthenticationPrincipal User viewer) {
        return ResponseEntity.ok(userService.getUserById(id, viewer));
    }

    @PatchMapping("/{id}/role")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN', 'MANAGER')")
    public ResponseEntity<UserDto> updateRole(@PathVariable Long id,
                                             @Valid @RequestBody UpdateRoleRequest request,
                                             @AuthenticationPrincipal User actor) {
        return ResponseEntity.ok(userService.updateUserRole(id, request.getRole(), actor));
    }

    @PatchMapping("/{id}/status")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN')")
    public ResponseEntity<UserDto> toggleStatus(@PathVariable Long id,
                                                @AuthenticationPrincipal User actor) {
        return ResponseEntity.ok(userService.toggleUserStatus(id, actor));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN')")
    public ResponseEntity<Void> deleteUser(@PathVariable Long id,
                                           @AuthenticationPrincipal User actor) {
        userService.deleteUser(id, actor);
        return ResponseEntity.ok().build();
    }
}

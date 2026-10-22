package com.devtrack.controller;

import com.devtrack.dto.AuthRequest;
import com.devtrack.dto.AuthResponse;
import com.devtrack.dto.RegisterRequest;
import com.devtrack.dto.UserDto;
import com.devtrack.model.User;
import com.devtrack.service.AuthService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

/**
 * Authentication is bearer-token only (Authorization: Bearer <jwt>). No auth cookie is
 * issued, so cross-site requests cannot ride on a browser session (no CSRF exposure).
 */
@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    @PostMapping("/login")
    public ResponseEntity<AuthResponse> login(@Valid @RequestBody AuthRequest request) {
        return ResponseEntity.ok(authService.login(request));
    }

    @PostMapping("/logout")
    public ResponseEntity<Map<String, String>> logout() {
        // Tokens are stateless; the client discards its token. Kept for API compatibility.
        return ResponseEntity.ok(Map.of("message", "Logged out successfully"));
    }

    @PostMapping("/register")
    public ResponseEntity<UserDto> register(@Valid @RequestBody RegisterRequest request) {
        return ResponseEntity.ok(authService.register(request));
    }

    /** Current user plus their permission list (so a restored session has permissions too). */
    @GetMapping("/me")
    public ResponseEntity<AuthResponse> getCurrentUser(@AuthenticationPrincipal User user) {
        return ResponseEntity.ok(authService.currentUser(user));
    }
}

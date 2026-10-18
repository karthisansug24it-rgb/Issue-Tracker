package com.devtrack.dto;

import com.devtrack.model.RoleType;

import java.util.List;

public class AuthResponse {
    private String token;
    private Long id;
    private String fullName;
    private String email;
    private RoleType role;
    private String department;
    private String jobTitle;
    private String avatarUrl;
    private List<String> permissions;

    public AuthResponse() {}

    public AuthResponse(String token, Long id, String fullName, String email, RoleType role, String department, String jobTitle, String avatarUrl, List<String> permissions) {
        this.token = token;
        this.id = id;
        this.fullName = fullName;
        this.email = email;
        this.role = role;
        this.department = department;
        this.jobTitle = jobTitle;
        this.avatarUrl = avatarUrl;
        this.permissions = permissions;
    }

    public String getToken() { return token; }
    public void setToken(String token) { this.token = token; }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getFullName() { return fullName; }
    public void setFullName(String fullName) { this.fullName = fullName; }

    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }

    public RoleType getRole() { return role; }
    public void setRole(RoleType role) { this.role = role; }

    public String getDepartment() { return department; }
    public void setDepartment(String department) { this.department = department; }

    public String getJobTitle() { return jobTitle; }
    public void setJobTitle(String jobTitle) { this.jobTitle = jobTitle; }

    public String getAvatarUrl() { return avatarUrl; }
    public void setAvatarUrl(String avatarUrl) { this.avatarUrl = avatarUrl; }

    public List<String> getPermissions() { return permissions; }
    public void setPermissions(List<String> permissions) { this.permissions = permissions; }
}

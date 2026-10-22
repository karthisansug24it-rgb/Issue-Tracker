package com.devtrack.dto;

import com.devtrack.model.RoleType;
import jakarta.validation.constraints.NotNull;

public class UpdateRoleRequest {
    @NotNull(message = "Role is required")
    private RoleType role;

    public UpdateRoleRequest() {}

    public RoleType getRole() { return role; }
    public void setRole(RoleType role) { this.role = role; }
}

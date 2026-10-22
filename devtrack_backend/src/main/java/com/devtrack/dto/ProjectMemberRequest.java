package com.devtrack.dto;

import com.devtrack.model.ProjectRole;
import jakarta.validation.constraints.NotNull;

public class ProjectMemberRequest {
    @NotNull(message = "User is required")
    private Long userId;

    private ProjectRole projectRole = ProjectRole.DEVELOPER;

    public ProjectMemberRequest() {}

    public Long getUserId() { return userId; }
    public void setUserId(Long userId) { this.userId = userId; }

    public ProjectRole getProjectRole() { return projectRole; }
    public void setProjectRole(ProjectRole projectRole) { this.projectRole = projectRole; }
}

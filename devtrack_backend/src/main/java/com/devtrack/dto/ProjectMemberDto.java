package com.devtrack.dto;

import com.devtrack.model.ProjectRole;
import com.devtrack.model.RoleType;
import com.devtrack.model.User;

public class ProjectMemberDto {
    private Long id;
    private String fullName;
    private String email;
    private RoleType role;
    private String jobTitle;
    private boolean active;
    private ProjectRole projectRole;
    private boolean owner;

    public ProjectMemberDto() {}

    public static ProjectMemberDto of(User user, ProjectRole projectRole, boolean owner) {
        ProjectMemberDto dto = new ProjectMemberDto();
        dto.setId(user.getId());
        dto.setFullName(user.getFullName());
        dto.setEmail(user.getEmail());
        dto.setRole(user.getRole());
        dto.setJobTitle(user.getJobTitle());
        dto.setActive(user.isActive());
        dto.setProjectRole(projectRole);
        dto.setOwner(owner);
        return dto;
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getFullName() { return fullName; }
    public void setFullName(String fullName) { this.fullName = fullName; }

    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }

    public RoleType getRole() { return role; }
    public void setRole(RoleType role) { this.role = role; }

    public String getJobTitle() { return jobTitle; }
    public void setJobTitle(String jobTitle) { this.jobTitle = jobTitle; }

    public boolean isActive() { return active; }
    public void setActive(boolean active) { this.active = active; }

    public ProjectRole getProjectRole() { return projectRole; }
    public void setProjectRole(ProjectRole projectRole) { this.projectRole = projectRole; }

    public boolean isOwner() { return owner; }
    public void setOwner(boolean owner) { this.owner = owner; }
}

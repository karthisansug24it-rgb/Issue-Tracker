package com.devtrack.dto;

import com.devtrack.model.Project;
import java.time.LocalDate;
import java.time.LocalDateTime;

public class ProjectDto {
    private Long id;
    private String projectKey;
    private String name;
    private String description;
    private String status;
    private Long ownerId;
    private String ownerName;
    private LocalDate startDate;
    private LocalDate targetEndDate;
    private long totalIssues;
    private long openIssues;
    private LocalDateTime createdAt;

    public ProjectDto() {}

    public static ProjectDto fromEntity(Project project) {
        ProjectDto dto = new ProjectDto();
        dto.setId(project.getId());
        dto.setProjectKey(project.getProjectKey());
        dto.setName(project.getName());
        dto.setDescription(project.getDescription());
        dto.setStatus(project.getStatus());
        dto.setOwnerId(project.getOwnerId());
        dto.setStartDate(project.getStartDate());
        dto.setTargetEndDate(project.getTargetEndDate());
        dto.setCreatedAt(project.getCreatedAt());
        return dto;
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getProjectKey() { return projectKey; }
    public void setProjectKey(String projectKey) { this.projectKey = projectKey; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public Long getOwnerId() { return ownerId; }
    public void setOwnerId(Long ownerId) { this.ownerId = ownerId; }

    public String getOwnerName() { return ownerName; }
    public void setOwnerName(String ownerName) { this.ownerName = ownerName; }

    public LocalDate getStartDate() { return startDate; }
    public void setStartDate(LocalDate startDate) { this.startDate = startDate; }

    public LocalDate getTargetEndDate() { return targetEndDate; }
    public void setTargetEndDate(LocalDate targetEndDate) { this.targetEndDate = targetEndDate; }

    public long getTotalIssues() { return totalIssues; }
    public void setTotalIssues(long totalIssues) { this.totalIssues = totalIssues; }

    public long getOpenIssues() { return openIssues; }
    public void setOpenIssues(long openIssues) { this.openIssues = openIssues; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }

    // Per-user capabilities for this project
    private boolean canManage;
    private boolean canAssign;

    public boolean isCanManage() { return canManage; }
    public void setCanManage(boolean canManage) { this.canManage = canManage; }

    public boolean isCanAssign() { return canAssign; }
    public void setCanAssign(boolean canAssign) { this.canAssign = canAssign; }
}

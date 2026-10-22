package com.devtrack.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import java.time.LocalDate;

public class CreateProjectRequest {
    @NotBlank(message = "Project key is required")
    @Pattern(regexp = "^[A-Za-z][A-Za-z0-9]{1,9}$",
            message = "Project key must be 2-10 letters or digits and start with a letter")
    private String projectKey;

    @NotBlank(message = "Project name is required")
    @Size(max = 150, message = "Project name must be at most 150 characters")
    private String name;

    @Size(max = 2000, message = "Description must be at most 2000 characters")
    private String description;

    @Pattern(regexp = "^(ACTIVE|PLANNING|COMPLETED|ON_HOLD)$", message = "Status must be ACTIVE, PLANNING, COMPLETED or ON_HOLD")
    private String status;

    // Optional: only admins may create a project on behalf of another owner
    private Long ownerId;

    private LocalDate startDate;
    private LocalDate targetEndDate;

    public CreateProjectRequest() {}

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

    public LocalDate getStartDate() { return startDate; }
    public void setStartDate(LocalDate startDate) { this.startDate = startDate; }

    public LocalDate getTargetEndDate() { return targetEndDate; }
    public void setTargetEndDate(LocalDate targetEndDate) { this.targetEndDate = targetEndDate; }
}

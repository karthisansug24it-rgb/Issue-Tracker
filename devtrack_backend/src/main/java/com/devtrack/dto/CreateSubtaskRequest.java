package com.devtrack.dto;

import com.devtrack.model.IssuePriority;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public class CreateSubtaskRequest {
    @NotBlank(message = "Sub-task title is required")
    @Size(max = 200, message = "Sub-task title must be at most 200 characters")
    private String title;

    private Long assigneeId;
    private IssuePriority priority = IssuePriority.MEDIUM;
    private Integer estimatedMinutes;

    public CreateSubtaskRequest() {}

    public CreateSubtaskRequest(String title, Long assigneeId, IssuePriority priority, Integer estimatedMinutes) {
        this.title = title;
        this.assigneeId = assigneeId;
        this.priority = priority != null ? priority : IssuePriority.MEDIUM;
        this.estimatedMinutes = estimatedMinutes;
    }

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    public Long getAssigneeId() { return assigneeId; }
    public void setAssigneeId(Long assigneeId) { this.assigneeId = assigneeId; }

    public IssuePriority getPriority() { return priority; }
    public void setPriority(IssuePriority priority) { this.priority = priority; }

    public Integer getEstimatedMinutes() { return estimatedMinutes; }
    public void setEstimatedMinutes(Integer estimatedMinutes) { this.estimatedMinutes = estimatedMinutes; }
}

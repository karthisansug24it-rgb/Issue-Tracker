package com.devtrack.dto;

import com.devtrack.model.IssuePriority;
import com.devtrack.model.IssueType;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

public class CreateIssueRequest {
    @NotNull(message = "Project ID is required")
    private Long projectId;

    private Long parentIssueId;

    @NotBlank(message = "Title is required")
    @Size(max = 200, message = "Title must be at most 200 characters")
    private String title;

    @Size(max = 5000, message = "Description must be at most 5000 characters")
    private String description;

    @NotNull(message = "Issue type is required")
    private IssueType type = IssueType.BUG;

    @NotNull(message = "Priority is required")
    private IssuePriority priority = IssuePriority.MEDIUM;

    private Long assigneeId;
    private LocalDate dueDate;
    @Min(value = 0, message = "Estimate cannot be negative")
    @Max(value = 100000, message = "Estimate is too large")
    private Integer estimatedMinutes;

    private List<CreateAttachmentRequest> attachments = new ArrayList<>();
    private List<CreateSubtaskRequest> subtasks = new ArrayList<>();

    public CreateIssueRequest() {}

    public Long getProjectId() { return projectId; }
    public void setProjectId(Long projectId) { this.projectId = projectId; }

    public Long getParentIssueId() { return parentIssueId; }
    public void setParentIssueId(Long parentIssueId) { this.parentIssueId = parentIssueId; }

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public IssueType getType() { return type; }
    public void setType(IssueType type) { this.type = type; }

    public IssuePriority getPriority() { return priority; }
    public void setPriority(IssuePriority priority) { this.priority = priority; }

    public Long getAssigneeId() { return assigneeId; }
    public void setAssigneeId(Long assigneeId) { this.assigneeId = assigneeId; }

    public LocalDate getDueDate() { return dueDate; }
    public void setDueDate(LocalDate dueDate) { this.dueDate = dueDate; }

    public Integer getEstimatedMinutes() { return estimatedMinutes; }
    public void setEstimatedMinutes(Integer estimatedMinutes) { this.estimatedMinutes = estimatedMinutes; }

    public List<CreateAttachmentRequest> getAttachments() { return attachments; }
    public void setAttachments(List<CreateAttachmentRequest> attachments) { this.attachments = attachments != null ? attachments : new ArrayList<>(); }

    public List<CreateSubtaskRequest> getSubtasks() { return subtasks; }
    public void setSubtasks(List<CreateSubtaskRequest> subtasks) { this.subtasks = subtasks != null ? subtasks : new ArrayList<>(); }
}

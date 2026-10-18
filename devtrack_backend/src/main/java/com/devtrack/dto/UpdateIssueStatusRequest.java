package com.devtrack.dto;

import com.devtrack.model.IssueStatus;
import jakarta.validation.constraints.NotNull;

public class UpdateIssueStatusRequest {
    @NotNull(message = "Status is required")
    private IssueStatus status;

    private String comment;

    public UpdateIssueStatusRequest() {}

    public IssueStatus getStatus() { return status; }
    public void setStatus(IssueStatus status) { this.status = status; }

    public String getComment() { return comment; }
    public void setComment(String comment) { this.comment = comment; }
}

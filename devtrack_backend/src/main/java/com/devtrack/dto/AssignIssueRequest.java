package com.devtrack.dto;

/** A null assigneeId unassigns the issue. */
public class AssignIssueRequest {
    private Long assigneeId;

    public AssignIssueRequest() {}

    public Long getAssigneeId() { return assigneeId; }
    public void setAssigneeId(Long assigneeId) { this.assigneeId = assigneeId; }
}

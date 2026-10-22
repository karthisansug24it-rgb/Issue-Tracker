package com.devtrack.model;

import java.util.EnumSet;
import java.util.Map;
import java.util.Set;

public enum IssueStatus {
    OPEN,
    ASSIGNED,
    IN_PROGRESS,
    IN_REVIEW,
    RESOLVED,
    CLOSED,
    REOPENED,
    BLOCKED;

    /** Workflow: which statuses each status may move to. */
    private static final Map<IssueStatus, Set<IssueStatus>> TRANSITIONS = Map.of(
            OPEN, EnumSet.of(ASSIGNED, IN_PROGRESS, BLOCKED, CLOSED),
            ASSIGNED, EnumSet.of(OPEN, IN_PROGRESS, BLOCKED, CLOSED),
            IN_PROGRESS, EnumSet.of(ASSIGNED, IN_REVIEW, BLOCKED),
            BLOCKED, EnumSet.of(OPEN, ASSIGNED, IN_PROGRESS),
            IN_REVIEW, EnumSet.of(IN_PROGRESS, RESOLVED),
            RESOLVED, EnumSet.of(CLOSED, REOPENED),
            CLOSED, EnumSet.of(REOPENED),
            REOPENED, EnumSet.of(ASSIGNED, IN_PROGRESS, BLOCKED)
    );

    /** Statuses that count as "finished" work. Everything else is unresolved. */
    public boolean isDone() {
        return this == RESOLVED || this == CLOSED;
    }

    /** Statuses that count as "open / not started" on dashboards. */
    public boolean isOpen() {
        return this == OPEN || this == ASSIGNED || this == REOPENED;
    }

    public Set<IssueStatus> nextStatuses() {
        return TRANSITIONS.getOrDefault(this, EnumSet.noneOf(IssueStatus.class));
    }

    public boolean canMoveTo(IssueStatus target) {
        return nextStatuses().contains(target);
    }

    /**
     * Review decisions (approve, close, reopen, send back from review) are
     * reserved for reviewers rather than the assignee.
     */
    public static boolean isReviewDecision(IssueStatus from, IssueStatus to) {
        return to == RESOLVED || to == CLOSED || to == REOPENED || (from == IN_REVIEW && to == IN_PROGRESS);
    }

    /** Statuses that only make sense when the issue has an assignee. */
    public boolean requiresAssignee() {
        return this == ASSIGNED || this == IN_PROGRESS || this == IN_REVIEW;
    }

    /** OPEN means "nobody owns it"; use unassign (which moves it to OPEN) instead. */
    public boolean requiresNoAssignee() {
        return this == OPEN;
    }
}

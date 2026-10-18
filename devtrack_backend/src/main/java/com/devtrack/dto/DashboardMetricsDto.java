package com.devtrack.dto;

import java.util.List;
import java.util.Map;

public class DashboardMetricsDto {
    private String role;
    private long totalUsers;
    private long totalProjects;
    private long totalTeams;
    private long totalIssues;
    private long openIssues;
    private long inProgressIssues;
    private long inReviewIssues;
    private long resolvedIssues;
    private long closedIssues;
    private long criticalIssues;
    private long overdueIssues;
    private long myAssignedIssues;
    private long myBugs;
    private long myTasks;
    private Map<String, Long> statusDistribution;
    private Map<String, Long> priorityDistribution;
    private List<Map<String, Object>> myTeams;

    public DashboardMetricsDto() {}

    public String getRole() { return role; }
    public void setRole(String role) { this.role = role; }

    public long getTotalUsers() { return totalUsers; }
    public void setTotalUsers(long totalUsers) { this.totalUsers = totalUsers; }

    public long getTotalProjects() { return totalProjects; }
    public void setTotalProjects(long totalProjects) { this.totalProjects = totalProjects; }

    public long getTotalIssues() { return totalIssues; }
    public void setTotalIssues(long totalIssues) { this.totalIssues = totalIssues; }

    public long getOpenIssues() { return openIssues; }
    public void setOpenIssues(long openIssues) { this.openIssues = openIssues; }

    public long getInProgressIssues() { return inProgressIssues; }
    public void setInProgressIssues(long inProgressIssues) { this.inProgressIssues = inProgressIssues; }

    public long getInReviewIssues() { return inReviewIssues; }
    public void setInReviewIssues(long inReviewIssues) { this.inReviewIssues = inReviewIssues; }

    public long getResolvedIssues() { return resolvedIssues; }
    public void setResolvedIssues(long resolvedIssues) { this.resolvedIssues = resolvedIssues; }

    public long getClosedIssues() { return closedIssues; }
    public void setClosedIssues(long closedIssues) { this.closedIssues = closedIssues; }

    public long getCriticalIssues() { return criticalIssues; }
    public void setCriticalIssues(long criticalIssues) { this.criticalIssues = criticalIssues; }

    public long getOverdueIssues() { return overdueIssues; }
    public void setOverdueIssues(long overdueIssues) { this.overdueIssues = overdueIssues; }

    public long getMyAssignedIssues() { return myAssignedIssues; }
    public void setMyAssignedIssues(long myAssignedIssues) { this.myAssignedIssues = myAssignedIssues; }

    public long getMyBugs() { return myBugs; }
    public void setMyBugs(long myBugs) { this.myBugs = myBugs; }

    public long getMyTasks() { return myTasks; }
    public void setMyTasks(long myTasks) { this.myTasks = myTasks; }

    public Map<String, Long> getStatusDistribution() { return statusDistribution; }
    public void setStatusDistribution(Map<String, Long> statusDistribution) { this.statusDistribution = statusDistribution; }

    public long getTotalTeams() { return totalTeams; }
    public void setTotalTeams(long totalTeams) { this.totalTeams = totalTeams; }

    public List<Map<String, Object>> getMyTeams() { return myTeams; }
    public void setMyTeams(List<Map<String, Object>> myTeams) { this.myTeams = myTeams; }

    public Map<String, Long> getPriorityDistribution() { return priorityDistribution; }
    public void setPriorityDistribution(Map<String, Long> priorityDistribution) { this.priorityDistribution = priorityDistribution; }
}

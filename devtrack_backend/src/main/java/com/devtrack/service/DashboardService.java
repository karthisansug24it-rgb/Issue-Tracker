package com.devtrack.service;

import com.devtrack.dto.DashboardMetricsDto;
import com.devtrack.model.*;
import com.devtrack.repository.*;
import com.devtrack.security.AccessService;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.util.*;
import java.util.stream.Collectors;

/**
 * Dashboard numbers are scoped to what the user can see: admins get organisation-wide
 * figures, everyone else only the projects they belong to.
 *
 * Definitions used everywhere:
 *  - open      = OPEN, ASSIGNED or REOPENED (not started)
 *  - unresolved = anything except RESOLVED / CLOSED
 *  - critical / overdue only count unresolved issues
 */
@Service
public class DashboardService {

    private final UserRepository userRepository;
    private final ProjectRepository projectRepository;
    private final IssueRepository issueRepository;
    private final TeamRepository teamRepository;
    private final TeamMemberRepository teamMemberRepository;
    private final DepartmentRepository departmentRepository;
    private final ProjectMemberRepository projectMemberRepository;
    private final AccessService accessService;

    public DashboardService(UserRepository userRepository,
                            ProjectRepository projectRepository,
                            IssueRepository issueRepository,
                            TeamRepository teamRepository,
                            TeamMemberRepository teamMemberRepository,
                            DepartmentRepository departmentRepository,
                            ProjectMemberRepository projectMemberRepository,
                            AccessService accessService) {
        this.userRepository = userRepository;
        this.projectRepository = projectRepository;
        this.issueRepository = issueRepository;
        this.teamRepository = teamRepository;
        this.teamMemberRepository = teamMemberRepository;
        this.departmentRepository = departmentRepository;
        this.projectMemberRepository = projectMemberRepository;
        this.accessService = accessService;
    }

    public DashboardMetricsDto getMetrics(User user) {
        DashboardMetricsDto dto = new DashboardMetricsDto();
        dto.setRole(user.getRole().name());

        Set<Long> visibleProjects = accessService.accessibleProjectIds(user);
        List<Issue> issues;
        if (visibleProjects == null) {
            issues = issueRepository.findAll();
            dto.setTotalProjects(projectRepository.count());
            dto.setTotalUsers(userRepository.countByActiveTrue());
        } else {
            issues = visibleProjects.isEmpty() ? List.of() : issueRepository.findByProjectIdIn(visibleProjects);
            dto.setTotalProjects(visibleProjects.size());
            // People the user works with: distinct members of their projects
            dto.setTotalUsers(visibleProjects.isEmpty() ? 0 : projectMemberRepository.findByProjectIdIn(visibleProjects).stream()
                    .map(ProjectMember::getUserId).distinct().count());
        }

        LocalDate today = LocalDate.now();
        dto.setTotalIssues(issues.size());
        dto.setOpenIssues(count(issues, i -> i.getStatus().isOpen()));
        dto.setInProgressIssues(count(issues, i -> i.getStatus() == IssueStatus.IN_PROGRESS));
        dto.setInReviewIssues(count(issues, i -> i.getStatus() == IssueStatus.IN_REVIEW));
        dto.setResolvedIssues(count(issues, i -> i.getStatus() == IssueStatus.RESOLVED));
        dto.setClosedIssues(count(issues, i -> i.getStatus() == IssueStatus.CLOSED));
        dto.setCriticalIssues(count(issues, i -> i.getPriority() == IssuePriority.CRITICAL && !i.getStatus().isDone()));
        dto.setOverdueIssues(count(issues, i -> i.getDueDate() != null && i.getDueDate().isBefore(today) && !i.getStatus().isDone()));

        // Personal metrics: only unresolved work counts as "on my plate"
        List<Issue> myActive = issueRepository.findByAssigneeId(user.getId()).stream()
                .filter(i -> !i.getStatus().isDone())
                .toList();
        dto.setMyAssignedIssues(myActive.size());
        dto.setMyBugs(count(myActive, i -> i.getType() == IssueType.BUG));
        dto.setMyTasks(count(myActive, i -> i.getType() == IssueType.TASK));

        Map<String, Long> statusDist = new LinkedHashMap<>();
        for (IssueStatus s : IssueStatus.values()) {
            statusDist.put(s.name(), count(issues, i -> i.getStatus() == s));
        }
        dto.setStatusDistribution(statusDist);

        Map<String, Long> priorityDist = new LinkedHashMap<>();
        for (IssuePriority p : IssuePriority.values()) {
            priorityDist.put(p.name(), count(issues, i -> i.getPriority() == p));
        }
        dto.setPriorityDistribution(priorityDist);

        List<Map<String, Object>> teamSummaries = buildTeamSummaries(user);
        dto.setMyTeams(teamSummaries);
        dto.setTotalTeams(accessService.isAdmin(user) ? teamRepository.count() : teamSummaries.size());

        return dto;
    }

    private static long count(List<Issue> issues, java.util.function.Predicate<Issue> filter) {
        return issues.stream().filter(filter).count();
    }

    private List<Map<String, Object>> buildTeamSummaries(User user) {
        boolean admin = accessService.isAdmin(user);
        Set<Long> memberTeamIds = teamMemberRepository.findByUserId(user.getId()).stream()
                .map(TeamMember::getTeamId).collect(Collectors.toSet());

        List<Map<String, Object>> summaries = new ArrayList<>();
        for (Team t : teamRepository.findAll()) {
            boolean isManager = user.getId().equals(t.getManagerId());
            boolean isLead = user.getId().equals(t.getTeamLeadId());
            boolean isMember = memberTeamIds.contains(t.getId());
            if (!(isManager || isLead || isMember || admin)) {
                continue;
            }

            Map<String, Object> summary = new HashMap<>();
            summary.put("id", t.getId());
            summary.put("name", t.getName());
            summary.put("description", t.getDescription());
            summary.put("active", t.isActive());

            if (t.getDepartmentId() != null) {
                departmentRepository.findById(t.getDepartmentId())
                        .ifPresent(d -> summary.put("departmentName", d.getName()));
            }
            if (t.getManagerId() != null) {
                summary.put("managerId", t.getManagerId());
                userRepository.findById(t.getManagerId())
                        .ifPresent(u -> summary.put("managerName", u.getFullName()));
            }
            if (t.getTeamLeadId() != null) {
                summary.put("teamLeadId", t.getTeamLeadId());
                userRepository.findById(t.getTeamLeadId())
                        .ifPresent(u -> summary.put("teamLeadName", u.getFullName()));
            }
            summary.put("memberCount", (long) teamMemberRepository.findByTeamId(t.getId()).size());

            String roleInTeam;
            if (isManager) roleInTeam = "Team Manager";
            else if (isLead) roleInTeam = "Team Lead";
            else if (isMember) roleInTeam = "Member";
            else roleInTeam = "Admin Oversight";
            summary.put("userRoleInTeam", roleInTeam);

            summaries.add(summary);
        }
        return summaries;
    }
}

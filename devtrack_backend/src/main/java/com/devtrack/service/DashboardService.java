package com.devtrack.service;

import com.devtrack.dto.DashboardMetricsDto;
import com.devtrack.model.Issue;
import com.devtrack.model.IssuePriority;
import com.devtrack.model.IssueStatus;
import com.devtrack.model.IssueType;
import com.devtrack.model.User;
import com.devtrack.repository.*;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
public class DashboardService {

    private final UserRepository userRepository;
    private final ProjectRepository projectRepository;
    private final IssueRepository issueRepository;
    private final TeamRepository teamRepository;
    private final TeamMemberRepository teamMemberRepository;
    private final DepartmentRepository departmentRepository;

    public DashboardService(UserRepository userRepository,
                            ProjectRepository projectRepository,
                            IssueRepository issueRepository,
                            TeamRepository teamRepository,
                            TeamMemberRepository teamMemberRepository,
                            DepartmentRepository departmentRepository) {
        this.userRepository = userRepository;
        this.projectRepository = projectRepository;
        this.issueRepository = issueRepository;
        this.teamRepository = teamRepository;
        this.teamMemberRepository = teamMemberRepository;
        this.departmentRepository = departmentRepository;
    }

    public DashboardMetricsDto getMetrics(User user) {
        DashboardMetricsDto dto = new DashboardMetricsDto();
        dto.setRole(user.getRole().name());

        dto.setTotalUsers(userRepository.countByActiveTrue());
        dto.setTotalProjects(projectRepository.count());
        dto.setTotalIssues(issueRepository.count());

        dto.setOpenIssues(issueRepository.countByStatus(IssueStatus.OPEN) + issueRepository.countByStatus(IssueStatus.ASSIGNED));
        dto.setInProgressIssues(issueRepository.countByStatus(IssueStatus.IN_PROGRESS));
        dto.setInReviewIssues(issueRepository.countByStatus(IssueStatus.IN_REVIEW));
        dto.setResolvedIssues(issueRepository.countByStatus(IssueStatus.RESOLVED));
        dto.setClosedIssues(issueRepository.countByStatus(IssueStatus.CLOSED));
        dto.setCriticalIssues(issueRepository.countByPriority(IssuePriority.CRITICAL));

        List<Issue> overdueList = issueRepository.findByDueDateBeforeAndStatusNotIn(
                LocalDate.now(), List.of(IssueStatus.RESOLVED, IssueStatus.CLOSED));
        dto.setOverdueIssues(overdueList.size());

        // Personal metrics for logged-in user
        List<Issue> myAssigned = issueRepository.findByAssigneeId(user.getId());
        dto.setMyAssignedIssues(myAssigned.stream().filter(i -> i.getStatus() != IssueStatus.CLOSED).count());
        dto.setMyBugs(myAssigned.stream().filter(i -> i.getType() == IssueType.BUG && i.getStatus() != IssueStatus.CLOSED).count());
        dto.setMyTasks(myAssigned.stream().filter(i -> i.getType() == IssueType.TASK && i.getStatus() != IssueStatus.CLOSED).count());

        dto.setTotalTeams(teamRepository.count());

        Map<String, Long> statusDist = new HashMap<>();
        for (IssueStatus s : IssueStatus.values()) {
            statusDist.put(s.name(), issueRepository.countByStatus(s));
        }
        dto.setStatusDistribution(statusDist);

        Map<String, Long> priorityDist = new HashMap<>();
        for (IssuePriority p : IssuePriority.values()) {
            priorityDist.put(p.name(), issueRepository.countByPriority(p));
        }
        dto.setPriorityDistribution(priorityDist);

        // Teams & Works assignment overview
        List<com.devtrack.model.Team> allTeams = teamRepository.findAll();
        List<Map<String, Object>> teamSummaries = new java.util.ArrayList<>();

        for (com.devtrack.model.Team t : allTeams) {
            boolean isManager = user.getId().equals(t.getManagerId());
            boolean isLead = user.getId().equals(t.getTeamLeadId());
            boolean isMember = teamMemberRepository.findByTeamIdAndUserId(t.getId(), user.getId()).isPresent();

            // Include if user is assigned to the team OR if user is Super Admin / Admin / Manager
            boolean isManagementRole = user.getRole() == com.devtrack.model.RoleType.SUPER_ADMIN
                    || user.getRole() == com.devtrack.model.RoleType.ADMIN
                    || user.getRole() == com.devtrack.model.RoleType.MANAGER;

            if (isManager || isLead || isMember || isManagementRole) {
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

                long memberCount = teamMemberRepository.findByTeamId(t.getId()).size();
                summary.put("memberCount", memberCount);

                String roleInTeam = "Observer";
                if (isManager) roleInTeam = "Team Manager";
                else if (isLead) roleInTeam = "Team Lead";
                else if (isMember) roleInTeam = "Member";
                else if (user.getRole() == com.devtrack.model.RoleType.MANAGER) roleInTeam = "Manager Oversight";
                else if (user.getRole() == com.devtrack.model.RoleType.SUPER_ADMIN || user.getRole() == com.devtrack.model.RoleType.ADMIN) roleInTeam = "Admin Oversight";
                summary.put("userRoleInTeam", roleInTeam);

                teamSummaries.add(summary);
            }
        }
        dto.setMyTeams(teamSummaries);

        return dto;
    }
}

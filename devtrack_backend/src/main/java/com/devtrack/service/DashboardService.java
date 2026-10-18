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

    public DashboardService(UserRepository userRepository,
                            ProjectRepository projectRepository,
                            IssueRepository issueRepository) {
        this.userRepository = userRepository;
        this.projectRepository = projectRepository;
        this.issueRepository = issueRepository;
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

        return dto;
    }
}

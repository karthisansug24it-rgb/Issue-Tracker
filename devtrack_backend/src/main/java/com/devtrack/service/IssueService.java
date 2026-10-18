package com.devtrack.service;

import com.devtrack.dto.CreateIssueRequest;
import com.devtrack.dto.IssueDto;
import com.devtrack.model.*;
import com.devtrack.repository.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

@Service
public class IssueService {

    private final IssueRepository issueRepository;
    private final ProjectRepository projectRepository;
    private final UserRepository userRepository;
    private final IssueHistoryRepository historyRepository;
    private final IssueCommentRepository commentRepository;
    private final TimeEntryRepository timeEntryRepository;
    private final NotificationRepository notificationRepository;

    public IssueService(IssueRepository issueRepository,
                        ProjectRepository projectRepository,
                        UserRepository userRepository,
                        IssueHistoryRepository historyRepository,
                        IssueCommentRepository commentRepository,
                        TimeEntryRepository timeEntryRepository,
                        NotificationRepository notificationRepository) {
        this.issueRepository = issueRepository;
        this.projectRepository = projectRepository;
        this.userRepository = userRepository;
        this.historyRepository = historyRepository;
        this.commentRepository = commentRepository;
        this.timeEntryRepository = timeEntryRepository;
        this.notificationRepository = notificationRepository;
    }

    public List<IssueDto> getIssues(Long projectId, Long assigneeId, IssueStatus status,
                                    IssuePriority priority, IssueType type, String search, User currentUser) {
        List<Issue> issues = issueRepository.findAll();

        return issues.stream()
                .filter(i -> projectId == null || i.getProjectId().equals(projectId))
                .filter(i -> assigneeId == null || (i.getAssigneeId() != null && i.getAssigneeId().equals(assigneeId)))
                .filter(i -> status == null || i.getStatus() == status)
                .filter(i -> priority == null || i.getPriority() == priority)
                .filter(i -> type == null || i.getType() == type)
                .filter(i -> {
                    if (search == null || search.trim().isEmpty()) return true;
                    String s = search.toLowerCase();
                    return i.getTitle().toLowerCase().contains(s)
                            || i.getIssueKey().toLowerCase().contains(s)
                            || (i.getDescription() != null && i.getDescription().toLowerCase().contains(s));
                })
                .map(this::mapToIssueDto)
                .collect(Collectors.toList());
    }

    public IssueDto getIssueById(Long id) {
        Issue issue = issueRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Issue not found: " + id));
        return mapToIssueDto(issue);
    }

    @Transactional
    public IssueDto createIssue(CreateIssueRequest request, User reporter) {
        Project project = projectRepository.findById(request.getProjectId())
                .orElseThrow(() -> new RuntimeException("Project not found: " + request.getProjectId()));

        long nextNum = issueRepository.countByProjectId(project.getId()) + 101;
        String issueKey = project.getProjectKey() + "-" + nextNum;

        Issue issue = new Issue(
                issueKey,
                project.getId(),
                request.getTitle().trim(),
                request.getDescription(),
                request.getType() != null ? request.getType() : IssueType.TASK,
                request.getPriority() != null ? request.getPriority() : IssuePriority.MEDIUM,
                request.getAssigneeId() != null ? IssueStatus.ASSIGNED : IssueStatus.OPEN,
                reporter.getId(),
                request.getAssigneeId(),
                request.getDueDate(),
                request.getEstimatedMinutes()
        );

        Issue saved = issueRepository.save(issue);

        // Record history
        historyRepository.save(new IssueHistory(saved.getId(), reporter.getId(), reporter.getFullName(),
                "CREATED", null, saved.getStatus().name()));

        // Notify assignee if assigned
        if (saved.getAssigneeId() != null) {
            notificationRepository.save(new Notification(
                    saved.getAssigneeId(),
                    "New Task Assigned: " + saved.getIssueKey(),
                    reporter.getFullName() + " assigned you " + saved.getTitle(),
                    saved.getId(),
                    project.getProjectKey(),
                    "ASSIGNMENT"
            ));
        }

        return mapToIssueDto(saved);
    }

    @Transactional
    public IssueDto updateStatus(Long issueId, IssueStatus newStatus, String comment, User actor) {
        Issue issue = issueRepository.findById(issueId)
                .orElseThrow(() -> new RuntimeException("Issue not found: " + issueId));

        IssueStatus oldStatus = issue.getStatus();
        if (oldStatus == newStatus) {
            return mapToIssueDto(issue);
        }

        issue.setStatus(newStatus);
        if (newStatus == IssueStatus.RESOLVED || newStatus == IssueStatus.CLOSED) {
            issue.setResolvedAt(LocalDateTime.now());
        }

        Issue saved = issueRepository.save(issue);

        // Save history
        historyRepository.save(new IssueHistory(saved.getId(), actor.getId(), actor.getFullName(),
                "STATUS", oldStatus.name(), newStatus.name()));

        // Save comment if provided
        if (comment != null && !comment.trim().isEmpty()) {
            commentRepository.save(new IssueComment(saved.getId(), actor.getId(), actor.getFullName(), comment.trim()));
        }

        // Notify reporter / assignee
        Long notifyUserId = (actor.getId().equals(saved.getAssigneeId())) ? saved.getReporterId() : saved.getAssigneeId();
        if (notifyUserId != null && !notifyUserId.equals(actor.getId())) {
            notificationRepository.save(new Notification(
                    notifyUserId,
                    "Status Update: " + saved.getIssueKey(),
                    actor.getFullName() + " changed status to " + newStatus.name(),
                    saved.getId(),
                    null,
                    "STATUS_UPDATE"
            ));
        }

        return mapToIssueDto(saved);
    }

    @Transactional
    public IssueDto assignIssue(Long issueId, Long newAssigneeId, User actor) {
        Issue issue = issueRepository.findById(issueId)
                .orElseThrow(() -> new RuntimeException("Issue not found: " + issueId));

        Long oldAssigneeId = issue.getAssigneeId();
        String oldName = oldAssigneeId != null ? userRepository.findById(oldAssigneeId).map(User::getFullName).orElse("Unassigned") : "Unassigned";

        issue.setAssigneeId(newAssigneeId);
        if (issue.getStatus() == IssueStatus.OPEN && newAssigneeId != null) {
            issue.setStatus(IssueStatus.ASSIGNED);
        }

        Issue saved = issueRepository.save(issue);

        String newName = newAssigneeId != null ? userRepository.findById(newAssigneeId).map(User::getFullName).orElse("Unassigned") : "Unassigned";

        historyRepository.save(new IssueHistory(saved.getId(), actor.getId(), actor.getFullName(),
                "ASSIGNEE", oldName, newName));

        if (newAssigneeId != null && !newAssigneeId.equals(actor.getId())) {
            notificationRepository.save(new Notification(
                    newAssigneeId,
                    "Work Assigned: " + saved.getIssueKey(),
                    actor.getFullName() + " assigned you " + saved.getTitle(),
                    saved.getId(),
                    null,
                    "ASSIGNMENT"
            ));
        }

        return mapToIssueDto(saved);
    }

    public List<IssueHistory> getIssueHistory(Long issueId) {
        return historyRepository.findByIssueIdOrderByChangedAtDesc(issueId);
    }

    public List<IssueComment> getIssueComments(Long issueId) {
        return commentRepository.findByIssueIdOrderByCreatedAtAsc(issueId);
    }

    @Transactional
    public IssueComment addComment(Long issueId, String text, User author) {
        IssueComment comment = new IssueComment(issueId, author.getId(), author.getFullName(), text.trim());
        return commentRepository.save(comment);
    }

    @Transactional
    public TimeEntry logTime(Long issueId, Integer minutes, String description, User user) {
        Issue issue = issueRepository.findById(issueId)
                .orElseThrow(() -> new RuntimeException("Issue not found: " + issueId));

        TimeEntry entry = new TimeEntry(issueId, user.getId(), user.getFullName(), minutes, description);
        TimeEntry saved = timeEntryRepository.save(entry);

        int current = issue.getActualMinutes() != null ? issue.getActualMinutes() : 0;
        issue.setActualMinutes(current + minutes);
        issueRepository.save(issue);

        return saved;
    }

    public List<TimeEntry> getTimeEntries(Long issueId) {
        return timeEntryRepository.findByIssueIdOrderByLoggedAtDesc(issueId);
    }

    private IssueDto mapToIssueDto(Issue issue) {
        IssueDto dto = IssueDto.fromEntity(issue);

        projectRepository.findById(issue.getProjectId()).ifPresent(p -> {
            dto.setProjectName(p.getName());
            dto.setProjectKey(p.getProjectKey());
        });

        userRepository.findById(issue.getReporterId()).ifPresent(u -> dto.setReporterName(u.getFullName()));

        if (issue.getAssigneeId() != null) {
            userRepository.findById(issue.getAssigneeId()).ifPresent(u -> dto.setAssigneeName(u.getFullName()));
        }

        return dto;
    }
}

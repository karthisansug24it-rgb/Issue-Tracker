package com.devtrack.service;

import com.devtrack.dto.CreateIssueRequest;
import com.devtrack.dto.IssueDto;
import com.devtrack.exception.BadRequestException;
import com.devtrack.exception.ForbiddenException;
import com.devtrack.exception.NotFoundException;
import com.devtrack.model.*;
import com.devtrack.repository.*;
import com.devtrack.security.AccessService;
import com.devtrack.security.AccessService.ProjectAccess;
import jakarta.persistence.criteria.Predicate;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.*;
import java.util.function.Function;
import java.util.stream.Collectors;

@Service
public class IssueService {

    private static final int FIRST_ISSUE_NUMBER = 101;

    private final IssueRepository issueRepository;
    private final ProjectRepository projectRepository;
    private final UserRepository userRepository;
    private final IssueHistoryRepository historyRepository;
    private final IssueCommentRepository commentRepository;
    private final TimeEntryRepository timeEntryRepository;
    private final NotificationRepository notificationRepository;
    private final AccessService accessService;

    public IssueService(IssueRepository issueRepository,
                        ProjectRepository projectRepository,
                        UserRepository userRepository,
                        IssueHistoryRepository historyRepository,
                        IssueCommentRepository commentRepository,
                        TimeEntryRepository timeEntryRepository,
                        NotificationRepository notificationRepository,
                        AccessService accessService) {
        this.issueRepository = issueRepository;
        this.projectRepository = projectRepository;
        this.userRepository = userRepository;
        this.historyRepository = historyRepository;
        this.commentRepository = commentRepository;
        this.timeEntryRepository = timeEntryRepository;
        this.notificationRepository = notificationRepository;
        this.accessService = accessService;
    }

    // ------------------------------------------------------------------ queries

    public List<IssueDto> getIssues(Long projectId, Long assigneeId, IssueStatus status,
                                    IssuePriority priority, IssueType type, String search, User currentUser) {
        Set<Long> visibleProjects = accessService.accessibleProjectIds(currentUser);
        if (visibleProjects != null && visibleProjects.isEmpty()) {
            return List.of();
        }

        // Filtering happens in the database rather than after loading every issue
        Specification<Issue> spec = (root, query, cb) -> {
            List<Predicate> predicates = new ArrayList<>();
            if (visibleProjects != null) predicates.add(root.get("projectId").in(visibleProjects));
            if (projectId != null) predicates.add(cb.equal(root.get("projectId"), projectId));
            if (assigneeId != null) predicates.add(cb.equal(root.get("assigneeId"), assigneeId));
            if (status != null) predicates.add(cb.equal(root.get("status"), status));
            if (priority != null) predicates.add(cb.equal(root.get("priority"), priority));
            if (type != null) predicates.add(cb.equal(root.get("type"), type));
            if (search != null && !search.isBlank()) {
                String like = "%" + search.trim().toLowerCase() + "%";
                predicates.add(cb.or(
                        cb.like(cb.lower(root.get("title")), like),
                        cb.like(cb.lower(root.get("issueKey")), like),
                        cb.like(cb.lower(root.get("description")), like)));
            }
            return cb.and(predicates.toArray(new Predicate[0]));
        };

        List<Issue> issues = issueRepository.findAll(spec, Sort.by(Sort.Direction.DESC, "updatedAt"));
        return mapAll(issues, currentUser);
    }

    public IssueDto getIssueById(Long id, User user) {
        Issue issue = requireIssue(id);
        Project project = accessService.requireViewableProject(user, issue.getProjectId());
        return mapToIssueDto(issue, project, user);
    }

    public List<IssueHistory> getIssueHistory(Long issueId, User user) {
        requireViewableIssue(issueId, user);
        return historyRepository.findByIssueIdOrderByChangedAtDesc(issueId);
    }

    public List<IssueComment> getIssueComments(Long issueId, User user) {
        requireViewableIssue(issueId, user);
        return commentRepository.findByIssueIdOrderByCreatedAtAsc(issueId);
    }

    public List<TimeEntry> getTimeEntries(Long issueId, User user) {
        requireViewableIssue(issueId, user);
        return timeEntryRepository.findByIssueIdOrderByLoggedAtDesc(issueId);
    }

    // ---------------------------------------------------------------- commands

    @Transactional
    public IssueDto createIssue(CreateIssueRequest request, User reporter) {
        // Any member of the project may report an issue
        accessService.requireViewableProject(reporter, request.getProjectId());
        Project project = projectRepository.findByIdForUpdate(request.getProjectId())
                .orElseThrow(() -> new NotFoundException("Project not found: " + request.getProjectId()));
        ProjectAccess access = accessService.projectAccess(reporter, project);

        Long assigneeId = request.getAssigneeId();
        if (assigneeId != null) {
            boolean selfAssign = assigneeId.equals(reporter.getId());
            if (!access.canAssign() && !selfAssign) {
                throw new ForbiddenException("You can only assign new issues to yourself in this project.");
            }
            requireAssignableUser(project, assigneeId);
        }

        Issue issue = new Issue(
                nextIssueKey(project),
                project.getId(),
                request.getTitle().trim(),
                request.getDescription() != null ? request.getDescription().trim() : null,
                request.getType() != null ? request.getType() : IssueType.TASK,
                request.getPriority() != null ? request.getPriority() : IssuePriority.MEDIUM,
                assigneeId != null ? IssueStatus.ASSIGNED : IssueStatus.OPEN,
                reporter.getId(),
                assigneeId,
                request.getDueDate(),
                request.getEstimatedMinutes()
        );

        Issue saved = issueRepository.save(issue);

        historyRepository.save(new IssueHistory(saved.getId(), reporter.getId(), reporter.getFullName(),
                "CREATED", null, saved.getStatus().name()));

        if (assigneeId != null && !assigneeId.equals(reporter.getId())) {
            notify(assigneeId, "New Task Assigned: " + saved.getIssueKey(),
                    reporter.getFullName() + " assigned you " + saved.getTitle(), saved, project, "ASSIGNMENT");
        }

        return mapToIssueDto(saved, project, reporter);
    }

    @Transactional
    public IssueDto updateStatus(Long issueId, IssueStatus newStatus, String comment, User actor) {
        Issue issue = requireIssue(issueId);
        Project project = accessService.requireViewableProject(actor, issue.getProjectId());
        ProjectAccess access = accessService.projectAccess(actor, project);

        IssueStatus oldStatus = issue.getStatus();
        if (oldStatus == newStatus) {
            return mapToIssueDto(issue, project, actor);
        }
        if (!oldStatus.canMoveTo(newStatus)) {
            throw new BadRequestException("An issue cannot move from " + oldStatus + " to " + newStatus + ".");
        }
        if (newStatus.requiresAssignee() && issue.getAssigneeId() == null) {
            throw new BadRequestException("Assign the issue before moving it to " + newStatus + ".");
        }
        if (newStatus.requiresNoAssignee() && issue.getAssigneeId() != null) {
            throw new BadRequestException("Unassign the issue to move it back to " + newStatus + ".");
        }
        if (!accessService.canTransition(actor, issue, access, newStatus)) {
            throw new ForbiddenException(IssueStatus.isReviewDecision(oldStatus, newStatus)
                    ? "Only reviewers (team lead, project manager or the reporter) can move an issue to " + newStatus + "."
                    : "Only the assignee or a team lead / project manager can update this issue.");
        }

        issue.setStatus(newStatus);
        if (newStatus.isDone()) {
            if (issue.getResolvedAt() == null) {
                issue.setResolvedAt(LocalDateTime.now());
            }
        } else {
            issue.setResolvedAt(null); // reopened or sent back: no longer resolved
        }

        Issue saved = issueRepository.save(issue);

        historyRepository.save(new IssueHistory(saved.getId(), actor.getId(), actor.getFullName(),
                "STATUS", oldStatus.name(), newStatus.name()));

        if (comment != null && !comment.trim().isEmpty()) {
            commentRepository.save(new IssueComment(saved.getId(), actor.getId(), actor.getFullName(), comment.trim()));
        }

        // Notify the "other side": the reporter when the assignee acts, otherwise the assignee
        Long notifyUserId = actor.getId().equals(saved.getAssigneeId()) ? saved.getReporterId() : saved.getAssigneeId();
        if (notifyUserId != null && !notifyUserId.equals(actor.getId())) {
            notify(notifyUserId, "Status Update: " + saved.getIssueKey(),
                    actor.getFullName() + " changed status to " + newStatus.name(), saved, project,
                    newStatus == IssueStatus.IN_REVIEW ? "REVIEW_REQUEST" : "STATUS_UPDATE");
        }

        return mapToIssueDto(saved, project, actor);
    }

    @Transactional
    public IssueDto assignIssue(Long issueId, Long newAssigneeId, User actor) {
        Issue issue = requireIssue(issueId);
        Project project = accessService.requireViewableProject(actor, issue.getProjectId());
        if (!accessService.projectAccess(actor, project).canAssign()) {
            throw new ForbiddenException("Only team leads, project managers or admins can assign issues.");
        }

        Long oldAssigneeId = issue.getAssigneeId();
        if (Objects.equals(oldAssigneeId, newAssigneeId)) {
            return mapToIssueDto(issue, project, actor);
        }

        String newName = "Unassigned";
        if (newAssigneeId != null) {
            newName = requireAssignableUser(project, newAssigneeId).getFullName();
        }
        String oldName = oldAssigneeId != null
                ? userRepository.findById(oldAssigneeId).map(User::getFullName).orElse("Unknown user")
                : "Unassigned";

        IssueStatus oldStatus = issue.getStatus();
        issue.setAssigneeId(newAssigneeId);
        if (newAssigneeId != null && (oldStatus == IssueStatus.OPEN || oldStatus == IssueStatus.REOPENED)) {
            issue.setStatus(IssueStatus.ASSIGNED);
        } else if (newAssigneeId == null && oldStatus.requiresAssignee()) {
            issue.setStatus(IssueStatus.OPEN); // nobody is working on it any more
        }

        Issue saved = issueRepository.save(issue);

        historyRepository.save(new IssueHistory(saved.getId(), actor.getId(), actor.getFullName(),
                "ASSIGNEE", oldName, newName));
        if (saved.getStatus() != oldStatus) {
            historyRepository.save(new IssueHistory(saved.getId(), actor.getId(), actor.getFullName(),
                    "STATUS", oldStatus.name(), saved.getStatus().name()));
        }

        if (newAssigneeId != null && !newAssigneeId.equals(actor.getId())) {
            notify(newAssigneeId, "Work Assigned: " + saved.getIssueKey(),
                    actor.getFullName() + " assigned you " + saved.getTitle(), saved, project, "ASSIGNMENT");
        }

        return mapToIssueDto(saved, project, actor);
    }

    @Transactional
    public IssueComment addComment(Long issueId, String text, User author) {
        Issue issue = requireIssue(issueId);
        Project project = accessService.requireViewableProject(author, issue.getProjectId());

        IssueComment saved = commentRepository.save(
                new IssueComment(issueId, author.getId(), author.getFullName(), text.trim()));

        Set<Long> recipients = new LinkedHashSet<>();
        if (issue.getAssigneeId() != null) recipients.add(issue.getAssigneeId());
        if (issue.getReporterId() != null) recipients.add(issue.getReporterId());
        recipients.remove(author.getId());
        for (Long recipient : recipients) {
            notify(recipient, "New Comment: " + issue.getIssueKey(),
                    author.getFullName() + " commented on " + issue.getTitle(), issue, project, "COMMENT");
        }
        return saved;
    }

    @Transactional
    public TimeEntry logTime(Long issueId, Integer minutes, String description, User user) {
        Issue issue = requireIssue(issueId);
        Project project = accessService.requireViewableProject(user, issue.getProjectId());
        if (!accessService.canWorkOn(user, issue, accessService.projectAccess(user, project))) {
            throw new ForbiddenException("Only the assignee or a team lead / project manager can log time on this issue.");
        }

        TimeEntry entry = new TimeEntry(issueId, user.getId(), user.getFullName(), minutes,
                description != null ? description.trim() : "");
        TimeEntry saved = timeEntryRepository.save(entry);

        int current = issue.getActualMinutes() != null ? issue.getActualMinutes() : 0;
        issue.setActualMinutes(current + minutes);
        issueRepository.save(issue);

        return saved;
    }

    // ----------------------------------------------------------------- helpers

    private Issue requireIssue(Long id) {
        return issueRepository.findById(id)
                .orElseThrow(() -> new NotFoundException("Issue not found: " + id));
    }

    private void requireViewableIssue(Long issueId, User user) {
        Issue issue = requireIssue(issueId);
        accessService.requireViewableProject(user, issue.getProjectId());
    }

    /** Assignees must be active and able to see the project (member, owner or admin). */
    private User requireAssignableUser(Project project, Long userId) {
        User assignee = userRepository.findById(userId)
                .orElseThrow(() -> new NotFoundException("Assignee not found: " + userId));
        if (!assignee.isActive()) {
            throw new BadRequestException("Cannot assign work to a disabled user.");
        }
        if (!accessService.projectAccess(assignee, project).canView()) {
            throw new BadRequestException(assignee.getFullName() + " is not a member of project "
                    + project.getProjectKey() + ". Add them to the project first.");
        }
        return assignee;
    }

    /**
     * Uses the per-project counter (project row is locked by the caller) so keys stay unique
     * even with concurrent requests. Projects created before the counter existed are
     * initialised from their highest existing key.
     */
    private String nextIssueKey(Project project) {
        int next = project.getNextIssueNumber() != null ? project.getNextIssueNumber() : highestIssueNumber(project) + 1;
        String key = project.getProjectKey() + "-" + next;
        while (issueRepository.findByIssueKey(key).isPresent()) {
            next++;
            key = project.getProjectKey() + "-" + next;
        }
        project.setNextIssueNumber(next + 1);
        projectRepository.save(project);
        return key;
    }

    private int highestIssueNumber(Project project) {
        String prefix = project.getProjectKey() + "-";
        return issueRepository.findByProjectId(project.getId()).stream()
                .map(Issue::getIssueKey)
                .filter(k -> k != null && k.startsWith(prefix))
                .map(k -> k.substring(prefix.length()))
                .filter(s -> s.matches("\\d+"))
                .mapToInt(Integer::parseInt)
                .max()
                .orElse(FIRST_ISSUE_NUMBER - 1);
    }

    private void notify(Long recipientId, String title, String message, Issue issue, Project project, String type) {
        notificationRepository.save(new Notification(recipientId, title, message, issue.getId(),
                project != null ? project.getProjectKey() : null, type));
    }

    private List<IssueDto> mapAll(List<Issue> issues, User viewer) {
        if (issues.isEmpty()) {
            return List.of();
        }
        Map<Long, Project> projects = projectRepository.findAllById(
                        issues.stream().map(Issue::getProjectId).collect(Collectors.toSet())).stream()
                .collect(Collectors.toMap(Project::getId, Function.identity()));
        Set<Long> userIds = new HashSet<>();
        issues.forEach(i -> {
            if (i.getReporterId() != null) userIds.add(i.getReporterId());
            if (i.getAssigneeId() != null) userIds.add(i.getAssigneeId());
        });
        Map<Long, String> names = userRepository.findAllById(userIds).stream()
                .collect(Collectors.toMap(User::getId, User::getFullName));
        Map<Long, ProjectAccess> accessCache = accessService.newAccessCache();

        return issues.stream()
                .map(i -> toDto(i, projects.get(i.getProjectId()), viewer, names, accessCache))
                .collect(Collectors.toList());
    }

    private IssueDto mapToIssueDto(Issue issue, Project project, User viewer) {
        Map<Long, String> names = new HashMap<>();
        userRepository.findById(issue.getReporterId()).ifPresent(u -> names.put(u.getId(), u.getFullName()));
        if (issue.getAssigneeId() != null) {
            userRepository.findById(issue.getAssigneeId()).ifPresent(u -> names.put(u.getId(), u.getFullName()));
        }
        return toDto(issue, project, viewer, names, accessService.newAccessCache());
    }

    private IssueDto toDto(Issue issue, Project project, User viewer, Map<Long, String> names,
                           Map<Long, ProjectAccess> accessCache) {
        IssueDto dto = IssueDto.fromEntity(issue);
        dto.setReporterName(names.get(issue.getReporterId()));
        if (issue.getAssigneeId() != null) {
            dto.setAssigneeName(names.get(issue.getAssigneeId()));
        }
        if (project != null) {
            dto.setProjectName(project.getName());
            dto.setProjectKey(project.getProjectKey());

            ProjectAccess access = accessService.projectAccess(viewer, project, accessCache);
            dto.setCanAssign(access.canAssign());
            dto.setCanLogTime(accessService.canWorkOn(viewer, issue, access));
            dto.setAllowedTransitions(issue.getStatus().nextStatuses().stream()
                    .filter(s -> accessService.canTransition(viewer, issue, access, s))
                    .sorted()
                    .collect(Collectors.toList()));
        }
        return dto;
    }

    @Transactional
    public void deleteIssue(Long id, User actor) {
        Issue issue = issueRepository.findById(id)
                .orElseThrow(() -> new NotFoundException("Issue not found: " + id));
        Project project = accessService.requireProject(issue.getProjectId());
        ProjectAccess access = accessService.projectAccess(actor, project);

        boolean canDelete = accessService.isAdmin(actor) || access.canManage() || accessService.isReporter(actor, issue)
                || (issue.getAssigneeId() != null && issue.getAssigneeId().equals(actor.getId()));
        if (!canDelete) {
            throw new ForbiddenException("You do not have permission to permanently delete this issue.");
        }

        List<Issue> childIssues = issueRepository.findByParentIssueId(id);
        for (Issue child : childIssues) {
            child.setParentIssueId(null);
            issueRepository.save(child);
        }

        commentRepository.deleteByIssueId(id);
        historyRepository.deleteByIssueId(id);
        timeEntryRepository.deleteByIssueId(id);
        notificationRepository.deleteByRelatedIssueId(id);

        issueRepository.delete(issue);
    }

    @Transactional
    public void deleteComment(Long issueId, Long commentId, User actor) {
        IssueComment comment = commentRepository.findById(commentId)
                .orElseThrow(() -> new NotFoundException("Comment not found: " + commentId));
        if (!comment.getIssueId().equals(issueId)) {
            throw new BadRequestException("Comment does not belong to issue " + issueId);
        }
        Issue issue = requireIssue(issueId);
        Project project = accessService.requireProject(issue.getProjectId());
        ProjectAccess access = accessService.projectAccess(actor, project);

        boolean canDelete = accessService.isAdmin(actor) || access.canManage() || comment.getAuthorId().equals(actor.getId());
        if (!canDelete) {
            throw new ForbiddenException("You can only delete your own comments or comments in projects you manage.");
        }
        commentRepository.delete(comment);
    }

    @Transactional
    public void deleteTimeEntry(Long issueId, Long entryId, User actor) {
        TimeEntry entry = timeEntryRepository.findById(entryId)
                .orElseThrow(() -> new NotFoundException("Time entry not found: " + entryId));
        if (!entry.getIssueId().equals(issueId)) {
            throw new BadRequestException("Time entry does not belong to issue " + issueId);
        }
        Issue issue = requireIssue(issueId);
        Project project = accessService.requireProject(issue.getProjectId());
        ProjectAccess access = accessService.projectAccess(actor, project);

        boolean canDelete = accessService.isAdmin(actor) || access.canManage() || entry.getUserId().equals(actor.getId());
        if (!canDelete) {
            throw new ForbiddenException("You do not have permission to delete this time entry.");
        }

        int current = issue.getActualMinutes() != null ? issue.getActualMinutes() : 0;
        issue.setActualMinutes(Math.max(0, current - entry.getDurationMinutes()));
        issueRepository.save(issue);

        timeEntryRepository.delete(entry);
    }
}

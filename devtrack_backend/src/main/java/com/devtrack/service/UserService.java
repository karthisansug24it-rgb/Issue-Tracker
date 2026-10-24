package com.devtrack.service;

import com.devtrack.dto.UserDto;
import com.devtrack.exception.ForbiddenException;
import com.devtrack.exception.NotFoundException;
import com.devtrack.model.AuditLog;
import com.devtrack.model.RoleType;
import com.devtrack.model.User;
import com.devtrack.repository.*;
import com.devtrack.security.AccessService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

@Service
public class UserService {

    private final UserRepository userRepository;
    private final TeamRepository teamRepository;
    private final TeamMemberRepository teamMemberRepository;
    private final ProjectRepository projectRepository;
    private final ProjectMemberRepository projectMemberRepository;
    private final IssueRepository issueRepository;
    private final NotificationRepository notificationRepository;
    private final TimeEntryRepository timeEntryRepository;
    private final IssueCommentRepository issueCommentRepository;
    private final AuditLogRepository auditLogRepository;
    private final AccessService accessService;

    public UserService(UserRepository userRepository,
                       TeamRepository teamRepository,
                       TeamMemberRepository teamMemberRepository,
                       ProjectRepository projectRepository,
                       ProjectMemberRepository projectMemberRepository,
                       IssueRepository issueRepository,
                       NotificationRepository notificationRepository,
                       TimeEntryRepository timeEntryRepository,
                       IssueCommentRepository issueCommentRepository,
                       AuditLogRepository auditLogRepository,
                       AccessService accessService) {
        this.userRepository = userRepository;
        this.teamRepository = teamRepository;
        this.teamMemberRepository = teamMemberRepository;
        this.projectRepository = projectRepository;
        this.projectMemberRepository = projectMemberRepository;
        this.issueRepository = issueRepository;
        this.notificationRepository = notificationRepository;
        this.timeEntryRepository = timeEntryRepository;
        this.issueCommentRepository = issueCommentRepository;
        this.auditLogRepository = auditLogRepository;
        this.accessService = accessService;
    }

    private UserDto toDto(User user, User viewer) {
        UserDto dto = UserDto.fromEntity(user);
        dto.setCanModify(accessService.canModifyUser(viewer, user));
        return dto;
    }

    public List<UserDto> getAllUsers(User viewer) {
        return userRepository.findAll().stream()
                .map(u -> toDto(u, viewer))
                .collect(Collectors.toList());
    }

    public List<UserDto> getActiveUsers(User viewer) {
        return userRepository.findByActiveTrue().stream()
                .map(u -> toDto(u, viewer))
                .collect(Collectors.toList());
    }

    public UserDto getUserById(Long id, User viewer) {
        // Employees may only look up their own profile
        if (!viewer.getId().equals(id) && !viewer.getRole().isAtLeast(RoleType.TEAM_LEAD)) {
            throw new ForbiddenException("You can only view your own profile.");
        }
        return toDto(findUser(id), viewer);
    }

    private User findUser(Long id) {
        return userRepository.findById(id)
                .orElseThrow(() -> new NotFoundException("User not found: " + id));
    }

    @Transactional
    public UserDto updateUserRole(Long id, RoleType newRole, User actor) {
        User user = findUser(id);

        // Covers: no self-changes, target must be within the actor's authority
        accessService.checkCanModifyUser(actor, user);

        RoleType max = accessService.maxAssignableRole(actor);
        if (newRole.getRank() > max.getRank()) {
            throw new ForbiddenException("You can assign roles up to " + max + " only.");
        }

        RoleType oldRole = user.getRole();
        if (oldRole == newRole) {
            return toDto(user, actor);
        }
        user.setRole(newRole);
        User saved = userRepository.save(user);

        auditLogRepository.save(new AuditLog(actor.getId(), actor.getFullName(), "ROLE_UPDATED",
                "USER", id.toString(), "Changed role of " + user.getFullName() + " from " + oldRole + " to " + newRole));

        return toDto(saved, actor);
    }

    @Transactional
    public UserDto toggleUserStatus(Long id, User actor) {
        User user = findUser(id);

        // Same authority rules as role changes. Because nobody can disable themselves,
        // the acting Super Admin always remains, so the system never loses its last one.
        accessService.checkCanModifyUser(actor, user);

        user.setActive(!user.isActive());
        User saved = userRepository.save(user);

        auditLogRepository.save(new AuditLog(actor.getId(), actor.getFullName(),
                user.isActive() ? "USER_ENABLED" : "USER_DISABLED",
                "USER", id.toString(), (user.isActive() ? "Enabled " : "Disabled ") + user.getFullName()));

        return toDto(saved, actor);
    }

    @Transactional
    public void deleteUser(Long id, User actor) {
        User user = findUser(id);
        accessService.checkCanModifyUser(actor, user);

        // 1. Detach from teams as manager or team lead
        teamRepository.findAll().forEach(team -> {
            boolean changed = false;
            if (id.equals(team.getManagerId())) {
                team.setManagerId(null);
                changed = true;
            }
            if (id.equals(team.getTeamLeadId())) {
                team.setTeamLeadId(null);
                changed = true;
            }
            if (changed) {
                teamRepository.save(team);
            }
        });

        // 2. Remove team and project memberships
        teamMemberRepository.deleteByUserId(id);
        projectMemberRepository.deleteByUserId(id);

        // 3. Detach project ownership
        projectRepository.findByOwnerId(id).forEach(project -> {
            project.setOwnerId(null);
            projectRepository.save(project);
        });

        // 4. Detach issue assignees & reassign reporter to actor
        issueRepository.findByAssigneeId(id).forEach(issue -> {
            issue.setAssigneeId(null);
            issueRepository.save(issue);
        });
        issueRepository.findByReporterId(id).forEach(issue -> {
            issue.setReporterId(actor.getId());
            issueRepository.save(issue);
        });

        // 5. Delete notifications, time entries, and comments
        notificationRepository.deleteByRecipientId(id);
        timeEntryRepository.deleteByUserId(id);
        issueCommentRepository.deleteByAuthorId(id);

        // 6. Delete user permanently
        userRepository.delete(user);

        auditLogRepository.save(new AuditLog(actor.getId(), actor.getFullName(), "USER_DELETED",
                "USER", id.toString(), "Permanently deleted user: " + user.getFullName() + " (" + user.getEmail() + ")"));
    }
}

package com.devtrack.security;

import com.devtrack.exception.ForbiddenException;
import com.devtrack.exception.NotFoundException;
import com.devtrack.model.*;
import com.devtrack.repository.ProjectMemberRepository;
import com.devtrack.repository.ProjectRepository;
import org.springframework.stereotype.Service;

import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Optional;
import java.util.Set;

/**
 * Single source of truth for "who may do what". Every service calls into this class
 * instead of re-implementing role checks, so the API and the client permission list
 * (see RolePermissions) stay consistent.
 *
 * Rules:
 *  - SUPER_ADMIN / ADMIN see and manage every project.
 *  - Everyone else sees only projects they own or are a member of.
 *  - Managing a project (members, ownership) = admin, owner, or PROJECT_MANAGER member.
 *  - Assigning issues = project manager, or TEAM_LEAD+ / TECH_LEAD member of that project.
 *  - Review decisions (resolve, close, reopen, reject) = assigners or the issue reporter.
 *  - Working an issue (start, block, submit for review, log time) = assignee or assigners.
 */
@Service
public class AccessService {

    private final ProjectRepository projectRepository;
    private final ProjectMemberRepository projectMemberRepository;

    public AccessService(ProjectRepository projectRepository, ProjectMemberRepository projectMemberRepository) {
        this.projectRepository = projectRepository;
        this.projectMemberRepository = projectMemberRepository;
    }

    // ---------------------------------------------------------------- roles

    public boolean isAdmin(User user) {
        return user != null && user.getRole().isAtLeast(RoleType.ADMIN);
    }

    public boolean isSuperAdmin(User user) {
        return user != null && user.getRole() == RoleType.SUPER_ADMIN;
    }

    /** Highest role the actor may hand out. Admins manage up to Manager; only Super Admins manage Admins. */
    public RoleType maxAssignableRole(User actor) {
        return switch (actor.getRole()) {
            case SUPER_ADMIN -> RoleType.SUPER_ADMIN;
            case ADMIN -> RoleType.MANAGER;
            case MANAGER -> RoleType.TEAM_LEAD;
            default -> null;
        };
    }

    /** Whether the actor may change the role or active state of the target account. */
    public boolean canModifyUser(User actor, User target) {
        if (actor == null || target == null || actor.getId().equals(target.getId())) {
            return false; // nobody changes their own role or disables themselves
        }
        RoleType max = maxAssignableRole(actor);
        return max != null && target.getRole().getRank() <= max.getRank();
    }

    public void checkCanModifyUser(User actor, User target) {
        if (actor.getId().equals(target.getId())) {
            throw new ForbiddenException("You cannot change your own role or account status.");
        }
        if (!canModifyUser(actor, target)) {
            throw new ForbiddenException("You cannot modify a user with role " + target.getRole() + ".");
        }
    }

    // ------------------------------------------------------------- projects

    /** Project ids the user can see, or null when the user can see every project. */
    public Set<Long> accessibleProjectIds(User user) {
        if (isAdmin(user)) {
            return null;
        }
        Set<Long> ids = new HashSet<>();
        projectMemberRepository.findByUserId(user.getId()).forEach(pm -> ids.add(pm.getProjectId()));
        projectRepository.findByOwnerId(user.getId()).forEach(p -> ids.add(p.getId()));
        return ids;
    }

    public Project requireProject(Long projectId) {
        if (projectId == null) {
            throw new NotFoundException("Project not found");
        }
        return projectRepository.findById(projectId)
                .orElseThrow(() -> new NotFoundException("Project not found: " + projectId));
    }

    public Project requireViewableProject(User user, Long projectId) {
        Project project = requireProject(projectId);
        if (!projectAccess(user, project).canView()) {
            throw new ForbiddenException("You are not a member of project " + project.getProjectKey() + ".");
        }
        return project;
    }

    public ProjectAccess projectAccess(User user, Project project) {
        boolean admin = isAdmin(user);
        boolean owner = project.getOwnerId() != null && project.getOwnerId().equals(user.getId());
        Optional<ProjectRole> memberRole = projectMemberRepository
                .findByProjectIdAndUserId(project.getId(), user.getId())
                .map(ProjectMember::getProjectRole);

        boolean canView = admin || owner || memberRole.isPresent();
        boolean canManage = admin || owner || memberRole.filter(r -> r == ProjectRole.PROJECT_MANAGER).isPresent();
        boolean canAssign = canManage || (canView && (user.getRole().isAtLeast(RoleType.TEAM_LEAD)
                || memberRole.filter(r -> r == ProjectRole.TECH_LEAD).isPresent()));
        return new ProjectAccess(canView, canManage, canAssign);
    }

    /** Small per-request cache so list endpoints do not repeat the same membership lookups. */
    public Map<Long, ProjectAccess> newAccessCache() {
        return new HashMap<>();
    }

    public ProjectAccess projectAccess(User user, Project project, Map<Long, ProjectAccess> cache) {
        return cache.computeIfAbsent(project.getId(), id -> projectAccess(user, project));
    }

    // --------------------------------------------------------------- issues

    public boolean isAssignee(User user, Issue issue) {
        return issue.getAssigneeId() != null && issue.getAssigneeId().equals(user.getId());
    }

    public boolean isReporter(User user, Issue issue) {
        return issue.getReporterId() != null && issue.getReporterId().equals(user.getId());
    }

    public boolean canWorkOn(User user, Issue issue, ProjectAccess access) {
        return access.canView() && (isAssignee(user, issue) || access.canAssign());
    }

    public boolean canReview(User user, Issue issue, ProjectAccess access) {
        return access.canView() && (access.canAssign() || isReporter(user, issue));
    }

    /** Whether the user may move the issue from its current status to the target status. */
    public boolean canTransition(User user, Issue issue, ProjectAccess access, IssueStatus target) {
        IssueStatus from = issue.getStatus();
        if (!from.canMoveTo(target)) {
            return false;
        }
        if (target.requiresAssignee() && issue.getAssigneeId() == null) {
            return false;
        }
        if (target.requiresNoAssignee() && issue.getAssigneeId() != null) {
            return false;
        }
        if (IssueStatus.isReviewDecision(from, target)) {
            return canReview(user, issue, access);
        }
        return canWorkOn(user, issue, access);
    }

    // ---------------------------------------------------------------- teams

    public boolean canManageTeam(User user, Team team) {
        if (isAdmin(user)) {
            return true;
        }
        return user.getRole() == RoleType.MANAGER && team.getManagerId() != null
                && team.getManagerId().equals(user.getId());
    }

    public record ProjectAccess(boolean canView, boolean canManage, boolean canAssign) {}
}

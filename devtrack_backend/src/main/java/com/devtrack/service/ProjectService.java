package com.devtrack.service;

import com.devtrack.dto.CreateProjectRequest;
import com.devtrack.dto.ProjectDto;
import com.devtrack.dto.ProjectMemberDto;
import com.devtrack.exception.BadRequestException;
import com.devtrack.exception.ConflictException;
import com.devtrack.exception.ForbiddenException;
import com.devtrack.exception.NotFoundException;
import com.devtrack.model.*;
import com.devtrack.repository.*;
import com.devtrack.security.AccessService;
import com.devtrack.security.AccessService.ProjectAccess;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;
import java.util.function.Function;
import java.util.stream.Collectors;

@Service
public class ProjectService {

    private final ProjectRepository projectRepository;
    private final ProjectMemberRepository projectMemberRepository;
    private final UserRepository userRepository;
    private final IssueRepository issueRepository;
    private final AuditLogRepository auditLogRepository;
    private final AccessService accessService;

    public ProjectService(ProjectRepository projectRepository,
                          ProjectMemberRepository projectMemberRepository,
                          UserRepository userRepository,
                          IssueRepository issueRepository,
                          AuditLogRepository auditLogRepository,
                          AccessService accessService) {
        this.projectRepository = projectRepository;
        this.projectMemberRepository = projectMemberRepository;
        this.userRepository = userRepository;
        this.issueRepository = issueRepository;
        this.auditLogRepository = auditLogRepository;
        this.accessService = accessService;
    }

    public List<ProjectDto> getProjectsForUser(User user) {
        Set<Long> visible = accessService.accessibleProjectIds(user);
        List<Project> projects = visible == null ? projectRepository.findAll() : projectRepository.findAllById(visible);
        projects.sort(Comparator.comparing(Project::getProjectKey));
        if (projects.isEmpty()) {
            return List.of();
        }

        // Load issue counts and owner names in bulk instead of per project
        List<Long> ids = projects.stream().map(Project::getId).toList();
        Map<Long, List<Issue>> issuesByProject = issueRepository.findByProjectIdIn(ids).stream()
                .collect(Collectors.groupingBy(Issue::getProjectId));
        Set<Long> ownerIds = projects.stream().map(Project::getOwnerId).filter(Objects::nonNull).collect(Collectors.toSet());
        Map<Long, String> ownerNames = userRepository.findAllById(ownerIds).stream()
                .collect(Collectors.toMap(User::getId, User::getFullName));

        return projects.stream()
                .map(p -> toDto(p, user, issuesByProject.getOrDefault(p.getId(), List.of()), ownerNames))
                .collect(Collectors.toList());
    }

    public ProjectDto getProjectById(Long id, User user) {
        Project project = accessService.requireViewableProject(user, id);
        return toDto(project, user);
    }

    @Transactional
    public ProjectDto createProject(CreateProjectRequest request, User creator) {
        String key = request.getProjectKey().trim().toUpperCase();
        if (projectRepository.existsByProjectKey(key)) {
            throw new ConflictException("Project key already exists: " + key);
        }

        Long ownerId = creator.getId();
        if (request.getOwnerId() != null && !request.getOwnerId().equals(creator.getId())) {
            if (!accessService.isAdmin(creator)) {
                throw new ForbiddenException("Only admins can create a project for another owner.");
            }
            User owner = userRepository.findById(request.getOwnerId())
                    .orElseThrow(() -> new NotFoundException("Owner not found: " + request.getOwnerId()));
            if (!owner.isActive() || !owner.getRole().isAtLeast(RoleType.MANAGER)) {
                throw new BadRequestException("Project owner must be an active Manager or above.");
            }
            ownerId = owner.getId();
        }
        if (request.getStartDate() != null && request.getTargetEndDate() != null
                && request.getTargetEndDate().isBefore(request.getStartDate())) {
            throw new BadRequestException("Target end date cannot be before the start date.");
        }

        Project project = new Project(key, request.getName().trim(),
                request.getDescription() != null ? request.getDescription().trim() : null,
                ownerId, request.getStartDate(), request.getTargetEndDate());
        if (request.getStatus() != null) {
            project.setStatus(request.getStatus());
        }
        project.setNextIssueNumber(101);
        Project saved = projectRepository.save(project);

        // The owner is always a PROJECT_MANAGER member
        projectMemberRepository.save(new ProjectMember(saved.getId(), ownerId, ProjectRole.PROJECT_MANAGER));

        auditLogRepository.save(new AuditLog(creator.getId(), creator.getFullName(), "PROJECT_CREATED",
                "PROJECT", saved.getId().toString(), "Created project: " + saved.getName() + " (" + key + ")"));

        return toDto(saved, creator);
    }

    private Project requireManageableProject(Long projectId, User actor) {
        Project project = accessService.requireProject(projectId);
        if (!accessService.projectAccess(actor, project).canManage()) {
            throw new ForbiddenException("Only the project owner, its project managers or admins can manage members.");
        }
        return project;
    }

    @Transactional
    public void addMember(Long projectId, Long userId, ProjectRole role, User actor) {
        Project project = requireManageableProject(projectId, actor);
        User member = userRepository.findById(userId)
                .orElseThrow(() -> new NotFoundException("User not found: " + userId));
        if (!member.isActive()) {
            throw new BadRequestException("Cannot add a disabled user to a project.");
        }
        ProjectRole effectiveRole = role != null ? role : ProjectRole.DEVELOPER;
        if (member.getId().equals(project.getOwnerId()) && effectiveRole != ProjectRole.PROJECT_MANAGER) {
            throw new BadRequestException("The project owner must stay a PROJECT_MANAGER.");
        }

        projectMemberRepository.findByProjectIdAndUserId(projectId, userId).ifPresentOrElse(
                pm -> {
                    pm.setProjectRole(effectiveRole);
                    projectMemberRepository.save(pm);
                },
                () -> projectMemberRepository.save(new ProjectMember(projectId, userId, effectiveRole))
        );

        auditLogRepository.save(new AuditLog(actor.getId(), actor.getFullName(), "PROJECT_MEMBER_ADDED",
                "PROJECT", projectId.toString(), "Set " + member.getFullName() + " as " + effectiveRole
                + " in " + project.getProjectKey()));
    }

    @Transactional
    public void removeMember(Long projectId, Long userId, User actor) {
        Project project = requireManageableProject(projectId, actor);
        if (userId.equals(project.getOwnerId())) {
            throw new BadRequestException("The project owner cannot be removed from the project.");
        }
        if (projectMemberRepository.findByProjectIdAndUserId(projectId, userId).isEmpty()) {
            throw new NotFoundException("User " + userId + " is not a member of " + project.getProjectKey());
        }
        projectMemberRepository.deleteByProjectIdAndUserId(projectId, userId);
        auditLogRepository.save(new AuditLog(actor.getId(), actor.getFullName(), "PROJECT_MEMBER_REMOVED",
                "PROJECT", projectId.toString(), "Removed user " + userId + " from " + project.getProjectKey()));
    }

    public List<ProjectMemberDto> getProjectMembers(Long projectId, User viewer) {
        Project project = accessService.requireViewableProject(viewer, projectId);
        List<ProjectMember> memberships = projectMemberRepository.findByProjectId(projectId);
        Map<Long, User> users = userRepository.findAllById(
                        memberships.stream().map(ProjectMember::getUserId).toList()).stream()
                .collect(Collectors.toMap(User::getId, Function.identity()));

        return memberships.stream()
                .filter(pm -> users.containsKey(pm.getUserId()))
                .map(pm -> ProjectMemberDto.of(users.get(pm.getUserId()), pm.getProjectRole(),
                        pm.getUserId().equals(project.getOwnerId())))
                .sorted(Comparator.comparing(ProjectMemberDto::getFullName, String.CASE_INSENSITIVE_ORDER))
                .collect(Collectors.toList());
    }

    private ProjectDto toDto(Project project, User viewer) {
        Map<Long, String> ownerNames = new HashMap<>();
        if (project.getOwnerId() != null) {
            userRepository.findById(project.getOwnerId()).ifPresent(u -> ownerNames.put(u.getId(), u.getFullName()));
        }
        return toDto(project, viewer, issueRepository.findByProjectId(project.getId()), ownerNames);
    }

    private ProjectDto toDto(Project project, User viewer, List<Issue> issues, Map<Long, String> ownerNames) {
        ProjectDto dto = ProjectDto.fromEntity(project);
        if (project.getOwnerId() != null) {
            dto.setOwnerName(ownerNames.get(project.getOwnerId()));
        }
        dto.setTotalIssues(issues.size());
        // "Open" on a project card = not yet resolved or closed
        dto.setOpenIssues(issues.stream().filter(i -> !i.getStatus().isDone()).count());

        ProjectAccess access = accessService.projectAccess(viewer, project);
        dto.setCanManage(access.canManage());
        dto.setCanAssign(access.canAssign());
        return dto;
    }
}

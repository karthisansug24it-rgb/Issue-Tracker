package com.devtrack.service;

import com.devtrack.dto.ProjectDto;
import com.devtrack.dto.UserDto;
import com.devtrack.model.*;
import com.devtrack.repository.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

@Service
public class ProjectService {

    private final ProjectRepository projectRepository;
    private final ProjectMemberRepository projectMemberRepository;
    private final UserRepository userRepository;
    private final IssueRepository issueRepository;
    private final AuditLogRepository auditLogRepository;

    public ProjectService(ProjectRepository projectRepository,
                          ProjectMemberRepository projectMemberRepository,
                          UserRepository userRepository,
                          IssueRepository issueRepository,
                          AuditLogRepository auditLogRepository) {
        this.projectRepository = projectRepository;
        this.projectMemberRepository = projectMemberRepository;
        this.userRepository = userRepository;
        this.issueRepository = issueRepository;
        this.auditLogRepository = auditLogRepository;
    }

    public List<ProjectDto> getProjectsForUser(User user) {
        List<Project> projects;

        if (user.getRole() == RoleType.SUPER_ADMIN || user.getRole() == RoleType.ADMIN) {
            projects = projectRepository.findAll();
        } else {
            // Projects where user is owner or member
            List<Long> memberProjectIds = projectMemberRepository.findByUserId(user.getId()).stream()
                    .map(ProjectMember::getProjectId)
                    .collect(Collectors.toList());

            projects = projectRepository.findAll().stream()
                    .filter(p -> (p.getOwnerId() != null && p.getOwnerId().equals(user.getId()))
                            || memberProjectIds.contains(p.getId()))
                    .collect(Collectors.toList());
        }

        return projects.stream().map(this::mapToProjectDto).collect(Collectors.toList());
    }

    public ProjectDto getProjectById(Long id) {
        Project project = projectRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Project not found: " + id));
        return mapToProjectDto(project);
    }

    public ProjectDto createProject(Project project, User creator) {
        String key = project.getProjectKey().trim().toUpperCase();
        if (projectRepository.existsByProjectKey(key)) {
            throw new RuntimeException("Project key already exists: " + key);
        }

        project.setProjectKey(key);
        if (project.getOwnerId() == null) {
            project.setOwnerId(creator.getId());
        }

        Project saved = projectRepository.save(project);

        // Automatically add owner as PROJECT_MANAGER
        projectMemberRepository.save(new ProjectMember(saved.getId(), project.getOwnerId(), ProjectRole.PROJECT_MANAGER));

        auditLogRepository.save(new AuditLog(creator.getId(), creator.getFullName(), "PROJECT_CREATED",
                "PROJECT", saved.getId().toString(), "Created project: " + saved.getName() + " (" + key + ")"));

        return mapToProjectDto(saved);
    }

    @Transactional
    public void addMember(Long projectId, Long userId, ProjectRole role, User actor) {
        if (!projectRepository.existsById(projectId)) {
            throw new RuntimeException("Project not found: " + projectId);
        }

        projectMemberRepository.findByProjectIdAndUserId(projectId, userId).ifPresentOrElse(
                pm -> {
                    pm.setProjectRole(role != null ? role : ProjectRole.DEVELOPER);
                    projectMemberRepository.save(pm);
                },
                () -> projectMemberRepository.save(new ProjectMember(projectId, userId, role != null ? role : ProjectRole.DEVELOPER))
        );

        auditLogRepository.save(new AuditLog(actor.getId(), actor.getFullName(), "PROJECT_MEMBER_ADDED",
                "PROJECT", projectId.toString(), "Added user " + userId + " to project as " + role));
    }

    @Transactional
    public void removeMember(Long projectId, Long userId, User actor) {
        projectMemberRepository.deleteByProjectIdAndUserId(projectId, userId);
        auditLogRepository.save(new AuditLog(actor.getId(), actor.getFullName(), "PROJECT_MEMBER_REMOVED",
                "PROJECT", projectId.toString(), "Removed user " + userId + " from project"));
    }

    public List<UserDto> getProjectMembers(Long projectId) {
        return projectMemberRepository.findByProjectId(projectId).stream()
                .map(pm -> userRepository.findById(pm.getUserId()))
                .filter(Optional::isPresent)
                .map(Optional::get)
                .map(UserDto::fromEntity)
                .collect(Collectors.toList());
    }

    private ProjectDto mapToProjectDto(Project project) {
        ProjectDto dto = ProjectDto.fromEntity(project);

        if (project.getOwnerId() != null) {
            userRepository.findById(project.getOwnerId())
                    .ifPresent(u -> dto.setOwnerName(u.getFullName()));
        }

        long total = issueRepository.countByProjectId(project.getId());
        long closed = issueRepository.findByProjectIdAndStatus(project.getId(), IssueStatus.CLOSED).size();
        dto.setTotalIssues(total);
        dto.setOpenIssues(total - closed);

        return dto;
    }
}

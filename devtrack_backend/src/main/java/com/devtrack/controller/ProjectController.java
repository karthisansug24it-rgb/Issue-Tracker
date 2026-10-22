package com.devtrack.controller;

import com.devtrack.dto.CreateProjectRequest;
import com.devtrack.dto.ProjectDto;
import com.devtrack.dto.ProjectMemberDto;
import com.devtrack.dto.ProjectMemberRequest;
import com.devtrack.model.User;
import com.devtrack.service.ProjectService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/projects")
public class ProjectController {

    private final ProjectService projectService;

    public ProjectController(ProjectService projectService) {
        this.projectService = projectService;
    }

    @GetMapping
    public ResponseEntity<List<ProjectDto>> getProjects(@AuthenticationPrincipal User user) {
        return ResponseEntity.ok(projectService.getProjectsForUser(user));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ProjectDto> getProjectById(@PathVariable Long id, @AuthenticationPrincipal User user) {
        return ResponseEntity.ok(projectService.getProjectById(id, user));
    }

    @PostMapping
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN', 'MANAGER')")
    public ResponseEntity<ProjectDto> createProject(@Valid @RequestBody CreateProjectRequest request,
                                                   @AuthenticationPrincipal User user) {
        return ResponseEntity.ok(projectService.createProject(request, user));
    }

    @GetMapping("/{id}/members")
    public ResponseEntity<List<ProjectMemberDto>> getMembers(@PathVariable Long id, @AuthenticationPrincipal User user) {
        return ResponseEntity.ok(projectService.getProjectMembers(id, user));
    }

    // Who may manage members (owner, project managers, admins) is checked in ProjectService
    @PostMapping("/{id}/members")
    public ResponseEntity<Void> addMember(@PathVariable Long id,
                                          @Valid @RequestBody ProjectMemberRequest request,
                                          @AuthenticationPrincipal User user) {
        projectService.addMember(id, request.getUserId(), request.getProjectRole(), user);
        return ResponseEntity.ok().build();
    }

    @DeleteMapping("/{id}/members/{userId}")
    public ResponseEntity<Void> removeMember(@PathVariable Long id,
                                             @PathVariable Long userId,
                                             @AuthenticationPrincipal User user) {
        projectService.removeMember(id, userId, user);
        return ResponseEntity.ok().build();
    }
}

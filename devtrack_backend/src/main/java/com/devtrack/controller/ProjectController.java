package com.devtrack.controller;

import com.devtrack.dto.ProjectDto;
import com.devtrack.dto.UserDto;
import com.devtrack.model.Project;
import com.devtrack.model.ProjectRole;
import com.devtrack.model.User;
import com.devtrack.service.ProjectService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

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
    public ResponseEntity<ProjectDto> getProjectById(@PathVariable Long id) {
        return ResponseEntity.ok(projectService.getProjectById(id));
    }

    @PostMapping
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN', 'MANAGER')")
    public ResponseEntity<ProjectDto> createProject(@RequestBody Project project,
                                                   @AuthenticationPrincipal User user) {
        return ResponseEntity.ok(projectService.createProject(project, user));
    }

    @GetMapping("/{id}/members")
    public ResponseEntity<List<UserDto>> getMembers(@PathVariable Long id) {
        return ResponseEntity.ok(projectService.getProjectMembers(id));
    }

    @PostMapping("/{id}/members")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN', 'MANAGER')")
    public ResponseEntity<Void> addMember(@PathVariable Long id,
                                          @RequestBody Map<String, Object> body,
                                          @AuthenticationPrincipal User user) {
        Long userId = Long.valueOf(body.get("userId").toString());
        ProjectRole role = body.containsKey("projectRole")
                ? ProjectRole.valueOf(body.get("projectRole").toString())
                : ProjectRole.DEVELOPER;

        projectService.addMember(id, userId, role, user);
        return ResponseEntity.ok().build();
    }

    @DeleteMapping("/{id}/members/{userId}")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN', 'MANAGER')")
    public ResponseEntity<Void> removeMember(@PathVariable Long id,
                                             @PathVariable Long userId,
                                             @AuthenticationPrincipal User user) {
        projectService.removeMember(id, userId, user);
        return ResponseEntity.ok().build();
    }
}

package com.devtrack.controller;

import com.devtrack.dto.DepartmentDto;
import com.devtrack.dto.DepartmentRequest;
import com.devtrack.dto.TeamDto;
import com.devtrack.dto.TeamRequest;
import com.devtrack.exception.BadRequestException;
import com.devtrack.model.User;
import com.devtrack.service.OrganizationService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1")
public class OrganizationController {

    private final OrganizationService organizationService;

    public OrganizationController(OrganizationService organizationService) {
        this.organizationService = organizationService;
    }

    // Departments (names/codes only, visible to every signed-in user)
    @GetMapping("/departments")
    public ResponseEntity<List<DepartmentDto>> getDepartments() {
        return ResponseEntity.ok(organizationService.getAllDepartments());
    }

    @PostMapping("/departments")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN')")
    public ResponseEntity<DepartmentDto> createDepartment(@Valid @RequestBody DepartmentRequest request,
                                                          @AuthenticationPrincipal User actor) {
        return ResponseEntity.ok(organizationService.createDepartment(request, actor));
    }

    @PutMapping("/departments/{id}")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN')")
    public ResponseEntity<DepartmentDto> updateDepartment(@PathVariable Long id,
                                                          @Valid @RequestBody DepartmentRequest request,
                                                          @AuthenticationPrincipal User actor) {
        return ResponseEntity.ok(organizationService.updateDepartment(id, request, actor));
    }

    @DeleteMapping("/departments/{id}")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN')")
    public ResponseEntity<Void> deleteDepartment(@PathVariable Long id, @AuthenticationPrincipal User actor) {
        organizationService.deleteDepartment(id, actor);
        return ResponseEntity.ok().build();
    }

    // Teams (member lists include emails, so Team Lead and above only)
    @GetMapping("/teams")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN', 'MANAGER', 'TEAM_LEAD')")
    public ResponseEntity<List<TeamDto>> getTeams(@RequestParam(required = false) Long departmentId) {
        if (departmentId != null) {
            return ResponseEntity.ok(organizationService.getTeamsByDepartment(departmentId));
        }
        return ResponseEntity.ok(organizationService.getAllTeams());
    }

    // Managers may create teams they manage; finer rules live in OrganizationService
    @PostMapping("/teams")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN', 'MANAGER')")
    public ResponseEntity<TeamDto> createTeam(@Valid @RequestBody TeamRequest request,
                                              @AuthenticationPrincipal User actor) {
        return ResponseEntity.ok(organizationService.createTeam(request, actor));
    }

    @PutMapping("/teams/{id}")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN', 'MANAGER')")
    public ResponseEntity<TeamDto> updateTeam(@PathVariable Long id, @Valid @RequestBody TeamRequest request,
                                              @AuthenticationPrincipal User actor) {
        return ResponseEntity.ok(organizationService.updateTeam(id, request, actor));
    }

    @DeleteMapping("/teams/{id}")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN')")
    public ResponseEntity<Void> deleteTeam(@PathVariable Long id, @AuthenticationPrincipal User actor) {
        organizationService.deleteTeam(id, actor);
        return ResponseEntity.ok().build();
    }

    @PostMapping("/teams/{id}/members")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN', 'MANAGER')")
    public ResponseEntity<Void> addTeamMember(@PathVariable Long id, @RequestBody Map<String, Long> body,
                                              @AuthenticationPrincipal User actor) {
        Long userId = body.get("userId");
        if (userId == null) {
            throw new BadRequestException("userId is required");
        }
        organizationService.addMemberToTeam(id, userId, actor);
        return ResponseEntity.ok().build();
    }

    @DeleteMapping("/teams/{id}/members/{userId}")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN', 'MANAGER')")
    public ResponseEntity<Void> removeTeamMember(@PathVariable Long id, @PathVariable Long userId,
                                                 @AuthenticationPrincipal User actor) {
        organizationService.removeMemberFromTeam(id, userId, actor);
        return ResponseEntity.ok().build();
    }
}

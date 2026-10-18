package com.devtrack.controller;

import com.devtrack.dto.DepartmentDto;
import com.devtrack.dto.TeamDto;
import com.devtrack.model.Department;
import com.devtrack.model.Team;
import com.devtrack.service.OrganizationService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
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

    // Departments
    @GetMapping("/departments")
    public ResponseEntity<List<DepartmentDto>> getDepartments() {
        return ResponseEntity.ok(organizationService.getAllDepartments());
    }

    @PostMapping("/departments")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN')")
    public ResponseEntity<DepartmentDto> createDepartment(@RequestBody Department dept) {
        return ResponseEntity.ok(organizationService.createDepartment(dept));
    }

    @PutMapping("/departments/{id}")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN')")
    public ResponseEntity<DepartmentDto> updateDepartment(@PathVariable Long id, @RequestBody Department dept) {
        return ResponseEntity.ok(organizationService.updateDepartment(id, dept));
    }

    @DeleteMapping("/departments/{id}")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN')")
    public ResponseEntity<Void> deleteDepartment(@PathVariable Long id) {
        organizationService.deleteDepartment(id);
        return ResponseEntity.ok().build();
    }

    // Teams
    @GetMapping("/teams")
    public ResponseEntity<List<TeamDto>> getTeams(@RequestParam(required = false) Long departmentId) {
        if (departmentId != null) {
            return ResponseEntity.ok(organizationService.getTeamsByDepartment(departmentId));
        }
        return ResponseEntity.ok(organizationService.getAllTeams());
    }

    @PostMapping("/teams")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN', 'MANAGER')")
    public ResponseEntity<TeamDto> createTeam(@RequestBody Team team) {
        return ResponseEntity.ok(organizationService.createTeam(team));
    }

    @PutMapping("/teams/{id}")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN', 'MANAGER')")
    public ResponseEntity<TeamDto> updateTeam(@PathVariable Long id, @RequestBody Team team) {
        return ResponseEntity.ok(organizationService.updateTeam(id, team));
    }

    @DeleteMapping("/teams/{id}")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN')")
    public ResponseEntity<Void> deleteTeam(@PathVariable Long id) {
        organizationService.deleteTeam(id);
        return ResponseEntity.ok().build();
    }

    @PostMapping("/teams/{id}/members")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN', 'MANAGER')")
    public ResponseEntity<Void> addTeamMember(@PathVariable Long id, @RequestBody Map<String, Long> body) {
        organizationService.addMemberToTeam(id, body.get("userId"));
        return ResponseEntity.ok().build();
    }

    @DeleteMapping("/teams/{id}/members/{userId}")
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'ADMIN', 'MANAGER')")
    public ResponseEntity<Void> removeTeamMember(@PathVariable Long id, @PathVariable Long userId) {
        organizationService.removeMemberFromTeam(id, userId);
        return ResponseEntity.ok().build();
    }
}

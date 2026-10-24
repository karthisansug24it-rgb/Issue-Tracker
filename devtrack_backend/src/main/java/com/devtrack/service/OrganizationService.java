package com.devtrack.service;

import com.devtrack.dto.DepartmentDto;
import com.devtrack.dto.DepartmentRequest;
import com.devtrack.dto.TeamDto;
import com.devtrack.dto.TeamRequest;
import com.devtrack.dto.UserDto;
import com.devtrack.exception.BadRequestException;
import com.devtrack.exception.ConflictException;
import com.devtrack.exception.ForbiddenException;
import com.devtrack.exception.NotFoundException;
import com.devtrack.model.*;
import com.devtrack.repository.*;
import com.devtrack.security.AccessService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Objects;
import java.util.Optional;
import java.util.stream.Collectors;

@Service
public class OrganizationService {

    private final DepartmentRepository departmentRepository;
    private final TeamRepository teamRepository;
    private final TeamMemberRepository teamMemberRepository;
    private final UserRepository userRepository;
    private final AuditLogRepository auditLogRepository;
    private final AccessService accessService;

    public OrganizationService(DepartmentRepository departmentRepository,
                               TeamRepository teamRepository,
                               TeamMemberRepository teamMemberRepository,
                               UserRepository userRepository,
                               AuditLogRepository auditLogRepository,
                               AccessService accessService) {
        this.departmentRepository = departmentRepository;
        this.teamRepository = teamRepository;
        this.teamMemberRepository = teamMemberRepository;
        this.userRepository = userRepository;
        this.auditLogRepository = auditLogRepository;
        this.accessService = accessService;
    }

    // ------------------------------------------------------------ departments

    /** Finds a department by name or code (case-insensitive). */
    public Optional<Department> findDepartment(String nameOrCode) {
        if (nameOrCode == null || nameOrCode.isBlank()) {
            return Optional.empty();
        }
        String value = nameOrCode.trim();
        return departmentRepository.findByNameIgnoreCase(value)
                .or(() -> departmentRepository.findByCodeIgnoreCase(value));
    }

    /**
     * Links the user to a real department when the text matches one; otherwise keeps the
     * free-text value so nothing typed at registration is lost.
     */
    public void applyDepartment(User user, String departmentText) {
        Optional<Department> dept = findDepartment(departmentText);
        if (dept.isPresent()) {
            user.setDepartmentId(dept.get().getId());
            user.setDepartment(dept.get().getName());
        } else {
            user.setDepartmentId(null);
            user.setDepartment(departmentText != null && !departmentText.isBlank() ? departmentText.trim() : null);
        }
    }

    public List<DepartmentDto> getAllDepartments() {
        return departmentRepository.findAll().stream()
                .map(DepartmentDto::fromEntity)
                .collect(Collectors.toList());
    }

    @Transactional
    public DepartmentDto createDepartment(DepartmentRequest request, User actor) {
        String name = request.getName().trim();
        String code = request.getCode().trim().toUpperCase();
        if (departmentRepository.findByNameIgnoreCase(name).isPresent()) {
            throw new ConflictException("A department named '" + name + "' already exists.");
        }
        if (departmentRepository.findByCodeIgnoreCase(code).isPresent()) {
            throw new ConflictException("Department code '" + code + "' is already used.");
        }
        Department dept = new Department(name, code, request.getDescription());
        if (request.getActive() != null) {
            dept.setActive(request.getActive());
        }
        Department saved = departmentRepository.save(dept);
        audit(actor, "DEPARTMENT_CREATED", "DEPARTMENT", saved.getId(), "Created department " + name + " (" + code + ")");
        return DepartmentDto.fromEntity(saved);
    }

    @Transactional
    public DepartmentDto updateDepartment(Long id, DepartmentRequest request, User actor) {
        Department dept = departmentRepository.findById(id)
                .orElseThrow(() -> new NotFoundException("Department not found: " + id));
        String name = request.getName().trim();
        String code = request.getCode().trim().toUpperCase();

        departmentRepository.findByNameIgnoreCase(name).filter(d -> !d.getId().equals(id)).ifPresent(d -> {
            throw new ConflictException("A department named '" + name + "' already exists.");
        });
        departmentRepository.findByCodeIgnoreCase(code).filter(d -> !d.getId().equals(id)).ifPresent(d -> {
            throw new ConflictException("Department code '" + code + "' is already used.");
        });

        boolean renamed = !dept.getName().equals(name);
        dept.setName(name);
        dept.setCode(code);
        dept.setDescription(request.getDescription());
        if (request.getActive() != null) {
            dept.setActive(request.getActive());
        }
        Department saved = departmentRepository.save(dept);

        if (renamed) {
            // Keep the denormalised department name on users in sync
            List<User> users = userRepository.findByDepartmentId(id);
            users.forEach(u -> u.setDepartment(name));
            userRepository.saveAll(users);
        }
        audit(actor, "DEPARTMENT_UPDATED", "DEPARTMENT", id, "Updated department " + name + " (" + code + ")");
        return DepartmentDto.fromEntity(saved);
    }

    @Transactional
    public void deleteDepartment(Long id, boolean cascade, User actor) {
        Department dept = departmentRepository.findById(id)
                .orElseThrow(() -> new NotFoundException("Department not found: " + id));
        if (!cascade) {
            if (teamRepository.existsByDepartmentId(id)) {
                throw new ConflictException("Move or delete the teams in " + dept.getName() + " before deleting it.");
            }
            if (userRepository.existsByDepartmentId(id)) {
                throw new ConflictException("Users still belong to " + dept.getName() + ". Reassign them before deleting it.");
            }
        } else {
            teamRepository.findByDepartmentId(id).forEach(t -> {
                t.setDepartmentId(null);
                teamRepository.save(t);
            });
            userRepository.findByDepartmentId(id).forEach(u -> {
                u.setDepartmentId(null);
                u.setDepartment(null);
                userRepository.save(u);
            });
        }
        departmentRepository.delete(dept);
        audit(actor, "DEPARTMENT_DELETED", "DEPARTMENT", id, "Deleted department " + dept.getName());
    }

    @Transactional
    public void deleteDepartment(Long id, User actor) {
        deleteDepartment(id, false, actor);
    }

    // ------------------------------------------------------------------ teams

    public List<TeamDto> getAllTeams() {
        return teamRepository.findAll().stream()
                .map(this::mapToTeamDto)
                .collect(Collectors.toList());
    }

    public List<TeamDto> getTeamsByDepartment(Long departmentId) {
        return teamRepository.findByDepartmentId(departmentId).stream()
                .map(this::mapToTeamDto)
                .collect(Collectors.toList());
    }

    @Transactional
    public TeamDto createTeam(TeamRequest request, User actor) {
        requireDepartment(request.getDepartmentId());

        Long managerId = request.getManagerId();
        if (!accessService.isAdmin(actor)) {
            // Managers can only create teams that they manage themselves
            if (managerId != null && !managerId.equals(actor.getId())) {
                throw new ForbiddenException("Managers can only create teams they manage themselves.");
            }
            managerId = actor.getId();
        }
        validateManager(managerId);
        validateTeamLead(request.getTeamLeadId());

        Team team = new Team(request.getName().trim(), request.getDepartmentId(), managerId,
                request.getTeamLeadId(), request.getDescription());
        if (request.getActive() != null) {
            team.setActive(request.getActive());
        }
        Team saved = teamRepository.save(team);
        ensureMember(saved.getId(), saved.getManagerId());
        ensureMember(saved.getId(), saved.getTeamLeadId());

        audit(actor, "TEAM_CREATED", "TEAM", saved.getId(), "Created team " + saved.getName());
        return mapToTeamDto(saved);
    }

    @Transactional
    public TeamDto updateTeam(Long id, TeamRequest request, User actor) {
        Team team = requireManageableTeam(id, actor);
        requireDepartment(request.getDepartmentId());

        if (!accessService.isAdmin(actor) && !Objects.equals(request.getManagerId(), team.getManagerId())) {
            throw new ForbiddenException("Only admins can change a team's manager.");
        }
        validateManager(request.getManagerId());
        validateTeamLead(request.getTeamLeadId());

        team.setName(request.getName().trim());
        team.setDescription(request.getDescription());
        team.setDepartmentId(request.getDepartmentId());
        team.setManagerId(request.getManagerId());
        team.setTeamLeadId(request.getTeamLeadId());
        if (request.getActive() != null) {
            team.setActive(request.getActive());
        }
        Team saved = teamRepository.save(team);
        ensureMember(id, saved.getManagerId());
        ensureMember(id, saved.getTeamLeadId());

        audit(actor, "TEAM_UPDATED", "TEAM", id, "Updated team " + saved.getName());
        return mapToTeamDto(saved);
    }

    @Transactional
    public void deleteTeam(Long id, User actor) {
        Team team = requireManageableTeam(id, actor);
        teamMemberRepository.deleteByTeamId(id);
        teamRepository.delete(team);
        audit(actor, "TEAM_DELETED", "TEAM", id, "Deleted team " + team.getName());
    }

    @Transactional
    public void addMemberToTeam(Long teamId, Long userId, User actor) {
        Team team = requireManageableTeam(teamId, actor);
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new NotFoundException("User not found: " + userId));
        if (!user.isActive()) {
            throw new BadRequestException("Cannot add a disabled user to a team.");
        }
        ensureMember(teamId, userId);
        audit(actor, "TEAM_MEMBER_ADDED", "TEAM", teamId, "Added " + user.getFullName() + " to " + team.getName());
    }

    @Transactional
    public void removeMemberFromTeam(Long teamId, Long userId, User actor) {
        Team team = requireManageableTeam(teamId, actor);
        if (userId.equals(team.getManagerId()) || userId.equals(team.getTeamLeadId())) {
            throw new BadRequestException("Change the team's manager or lead before removing them from the team.");
        }
        teamMemberRepository.deleteByTeamIdAndUserId(teamId, userId);
        audit(actor, "TEAM_MEMBER_REMOVED", "TEAM", teamId, "Removed user " + userId + " from " + team.getName());
    }

    // ---------------------------------------------------------------- helpers

    private Team requireManageableTeam(Long id, User actor) {
        Team team = teamRepository.findById(id)
                .orElseThrow(() -> new NotFoundException("Team not found: " + id));
        if (!accessService.canManageTeam(actor, team)) {
            throw new ForbiddenException("You can only manage teams that you manage.");
        }
        return team;
    }

    private void requireDepartment(Long departmentId) {
        if (departmentId == null || !departmentRepository.existsById(departmentId)) {
            throw new BadRequestException("Department not found: " + departmentId);
        }
    }

    private void validateManager(Long managerId) {
        if (managerId == null) return;
        User manager = userRepository.findById(managerId)
                .orElseThrow(() -> new BadRequestException("Manager not found: " + managerId));
        if (!manager.isActive() || !manager.getRole().isAtLeast(RoleType.MANAGER)) {
            throw new BadRequestException("Team manager must be an active Manager, Admin or Super Admin.");
        }
    }

    private void validateTeamLead(Long teamLeadId) {
        if (teamLeadId == null) return;
        User lead = userRepository.findById(teamLeadId)
                .orElseThrow(() -> new BadRequestException("Team lead not found: " + teamLeadId));
        if (!lead.isActive() || !(lead.getRole() == RoleType.TEAM_LEAD || lead.getRole() == RoleType.MANAGER)) {
            throw new BadRequestException("Team lead must be an active user with the Team Lead or Manager role.");
        }
    }

    private void ensureMember(Long teamId, Long userId) {
        if (userId != null && teamMemberRepository.findByTeamIdAndUserId(teamId, userId).isEmpty()) {
            teamMemberRepository.save(new TeamMember(teamId, userId));
        }
    }

    private void audit(User actor, String action, String entityType, Long entityId, String details) {
        auditLogRepository.save(new AuditLog(actor.getId(), actor.getFullName(), action, entityType,
                String.valueOf(entityId), details));
    }

    private TeamDto mapToTeamDto(Team team) {
        TeamDto dto = new TeamDto();
        dto.setId(team.getId());
        dto.setName(team.getName());
        dto.setDepartmentId(team.getDepartmentId());
        dto.setDescription(team.getDescription());
        dto.setActive(team.isActive());

        if (team.getDepartmentId() != null) {
            departmentRepository.findById(team.getDepartmentId())
                    .ifPresent(d -> dto.setDepartmentName(d.getName()));
        }

        if (team.getManagerId() != null) {
            dto.setManagerId(team.getManagerId());
            userRepository.findById(team.getManagerId())
                    .ifPresent(u -> {
                        dto.setManagerName(u.getFullName());
                        dto.setManagerEmail(u.getEmail());
                    });
        }

        if (team.getTeamLeadId() != null) {
            dto.setTeamLeadId(team.getTeamLeadId());
            userRepository.findById(team.getTeamLeadId())
                    .ifPresent(u -> {
                        dto.setTeamLeadName(u.getFullName());
                        dto.setTeamLeadEmail(u.getEmail());
                    });
        }

        List<Long> memberIds = teamMemberRepository.findByTeamId(team.getId()).stream()
                .map(TeamMember::getUserId).toList();
        List<UserDto> members = userRepository.findAllById(memberIds).stream()
                .map(UserDto::fromEntity)
                .collect(Collectors.toList());
        dto.setMembers(members);

        return dto;
    }
}

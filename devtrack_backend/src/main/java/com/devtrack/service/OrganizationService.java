package com.devtrack.service;

import com.devtrack.dto.DepartmentDto;
import com.devtrack.dto.TeamDto;
import com.devtrack.dto.UserDto;
import com.devtrack.model.Department;
import com.devtrack.model.Team;
import com.devtrack.model.TeamMember;
import com.devtrack.model.User;
import com.devtrack.repository.DepartmentRepository;
import com.devtrack.repository.TeamMemberRepository;
import com.devtrack.repository.TeamRepository;
import com.devtrack.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

@Service
public class OrganizationService {

    private final DepartmentRepository departmentRepository;
    private final TeamRepository teamRepository;
    private final TeamMemberRepository teamMemberRepository;
    private final UserRepository userRepository;

    public OrganizationService(DepartmentRepository departmentRepository,
                               TeamRepository teamRepository,
                               TeamMemberRepository teamMemberRepository,
                               UserRepository userRepository) {
        this.departmentRepository = departmentRepository;
        this.teamRepository = teamRepository;
        this.teamMemberRepository = teamMemberRepository;
        this.userRepository = userRepository;
    }

    // Departments
    public List<DepartmentDto> getAllDepartments() {
        return departmentRepository.findAll().stream()
                .map(DepartmentDto::fromEntity)
                .collect(Collectors.toList());
    }

    public DepartmentDto createDepartment(Department dept) {
        Department saved = departmentRepository.save(dept);
        return DepartmentDto.fromEntity(saved);
    }

    @Transactional
    public DepartmentDto updateDepartment(Long id, Department update) {
        Department dept = departmentRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Department not found with id: " + id));
        if (update.getName() != null && !update.getName().isBlank()) dept.setName(update.getName().trim());
        if (update.getCode() != null && !update.getCode().isBlank()) dept.setCode(update.getCode().trim().toUpperCase());
        if (update.getDescription() != null) dept.setDescription(update.getDescription());
        dept.setActive(update.isActive());
        return DepartmentDto.fromEntity(departmentRepository.save(dept));
    }

    @Transactional
    public void deleteDepartment(Long id) {
        departmentRepository.deleteById(id);
    }

    // Teams
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
    public TeamDto createTeam(Team team) {
        Team saved = teamRepository.save(team);
        // Ensure assigned Manager is registered in team members
        if (saved.getManagerId() != null) {
            addMemberToTeam(saved.getId(), saved.getManagerId());
        }
        // Ensure assigned Team Lead is registered in team members
        if (saved.getTeamLeadId() != null) {
            addMemberToTeam(saved.getId(), saved.getTeamLeadId());
        }
        return mapToTeamDto(saved);
    }

    @Transactional
    public TeamDto updateTeam(Long id, Team update) {
        Team team = teamRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Team not found with id: " + id));
        if (update.getName() != null && !update.getName().isBlank()) team.setName(update.getName().trim());
        if (update.getDescription() != null) team.setDescription(update.getDescription());
        if (update.getDepartmentId() != null) team.setDepartmentId(update.getDepartmentId());
        team.setManagerId(update.getManagerId());
        team.setTeamLeadId(update.getTeamLeadId());
        team.setActive(update.isActive());

        // Automatically ensure both manager and team lead are members of the team
        if (update.getManagerId() != null) {
            addMemberToTeam(id, update.getManagerId());
        }
        if (update.getTeamLeadId() != null) {
            addMemberToTeam(id, update.getTeamLeadId());
        }

        Team saved = teamRepository.save(team);
        return mapToTeamDto(saved);
    }

    @Transactional
    public void deleteTeam(Long id) {
        teamMemberRepository.deleteByTeamId(id);
        teamRepository.deleteById(id);
    }

    @Transactional
    public void addMemberToTeam(Long teamId, Long userId) {
        if (teamMemberRepository.findByTeamIdAndUserId(teamId, userId).isEmpty()) {
            teamMemberRepository.save(new TeamMember(teamId, userId));
        }
    }

    @Transactional
    public void removeMemberFromTeam(Long teamId, Long userId) {
        teamMemberRepository.deleteByTeamIdAndUserId(teamId, userId);
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

        List<UserDto> members = teamMemberRepository.findByTeamId(team.getId()).stream()
                .map(tm -> userRepository.findById(tm.getUserId()))
                .filter(Optional::isPresent)
                .map(Optional::get)
                .map(UserDto::fromEntity)
                .collect(Collectors.toList());
        dto.setMembers(members);

        return dto;
    }
}

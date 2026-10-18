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

    // Teams
    public List<TeamDto> getAllTeams() {
        return teamRepository.findAll().stream()
                .map(this::mapToTeamDto)
                .collect(Collectors.toList());
    }

    public TeamDto createTeam(Team team) {
        Team saved = teamRepository.save(team);
        return mapToTeamDto(saved);
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

        if (team.getTeamLeadId() != null) {
            dto.setTeamLeadId(team.getTeamLeadId());
            userRepository.findById(team.getTeamLeadId())
                    .ifPresent(u -> dto.setTeamLeadName(u.getFullName()));
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

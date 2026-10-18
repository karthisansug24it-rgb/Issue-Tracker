package com.devtrack.dto;

import java.util.List;

public class TeamDto {
    private Long id;
    private String name;
    private Long departmentId;
    private String departmentName;
    private Long teamLeadId;
    private String teamLeadName;
    private String description;
    private boolean active;
    private List<UserDto> members;

    public TeamDto() {}

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public Long getDepartmentId() { return departmentId; }
    public void setDepartmentId(Long departmentId) { this.departmentId = departmentId; }

    public String getDepartmentName() { return departmentName; }
    public void setDepartmentName(String departmentName) { this.departmentName = departmentName; }

    public Long getTeamLeadId() { return teamLeadId; }
    public void setTeamLeadId(Long teamLeadId) { this.teamLeadId = teamLeadId; }

    public String getTeamLeadName() { return teamLeadName; }
    public void setTeamLeadName(String teamLeadName) { this.teamLeadName = teamLeadName; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public boolean isActive() { return active; }
    public void setActive(boolean active) { this.active = active; }

    public List<UserDto> getMembers() { return members; }
    public void setMembers(List<UserDto> members) { this.members = members; }
}

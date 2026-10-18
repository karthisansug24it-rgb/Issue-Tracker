package com.devtrack.model;

import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "teams")
public class Team {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String name;

    private Long departmentId;
    private Long managerId;
    private Long teamLeadId;
    private String description;
    private boolean active = true;
    private LocalDateTime createdAt;

    public Team() {}

    public Team(String name, Long departmentId, Long teamLeadId, String description) {
        this.name = name;
        this.departmentId = departmentId;
        this.teamLeadId = teamLeadId;
        this.description = description;
        this.active = true;
    }

    public Team(String name, Long departmentId, Long managerId, Long teamLeadId, String description) {
        this.name = name;
        this.departmentId = departmentId;
        this.managerId = managerId;
        this.teamLeadId = teamLeadId;
        this.description = description;
        this.active = true;
    }

    @PrePersist
    public void onPrePersist() {
        this.createdAt = LocalDateTime.now();
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public Long getDepartmentId() { return departmentId; }
    public void setDepartmentId(Long departmentId) { this.departmentId = departmentId; }

    public Long getManagerId() { return managerId; }
    public void setManagerId(Long managerId) { this.managerId = managerId; }

    public Long getTeamLeadId() { return teamLeadId; }
    public void setTeamLeadId(Long teamLeadId) { this.teamLeadId = teamLeadId; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public boolean isActive() { return active; }
    public void setActive(boolean active) { this.active = active; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
}

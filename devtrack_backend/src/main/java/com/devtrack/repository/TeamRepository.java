package com.devtrack.repository;

import com.devtrack.model.Team;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface TeamRepository extends JpaRepository<Team, Long> {
    List<Team> findByDepartmentId(Long departmentId);
    List<Team> findByTeamLeadId(Long teamLeadId);
    List<Team> findByManagerId(Long managerId);
    boolean existsByDepartmentId(Long departmentId);
}

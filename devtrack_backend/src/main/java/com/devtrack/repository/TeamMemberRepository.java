package com.devtrack.repository;

import com.devtrack.model.TeamMember;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface TeamMemberRepository extends JpaRepository<TeamMember, Long> {
    List<TeamMember> findByTeamId(Long teamId);
    List<TeamMember> findByUserId(Long userId);
    Optional<TeamMember> findByTeamIdAndUserId(Long teamId, Long userId);
    void deleteByTeamIdAndUserId(Long teamId, Long userId);
    void deleteByTeamId(Long teamId);
    void deleteByUserId(Long userId);
}

package com.devtrack.repository;

import com.devtrack.model.TimeEntry;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface TimeEntryRepository extends JpaRepository<TimeEntry, Long> {
    List<TimeEntry> findByIssueIdOrderByLoggedAtDesc(Long issueId);
    List<TimeEntry> findByUserId(Long userId);
}

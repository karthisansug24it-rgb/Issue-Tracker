package com.devtrack.repository;

import com.devtrack.model.Issue;
import com.devtrack.model.IssuePriority;
import com.devtrack.model.IssueStatus;
import com.devtrack.model.IssueType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.Collection;
import java.util.List;
import java.util.Optional;

@Repository
public interface IssueRepository extends JpaRepository<Issue, Long>, JpaSpecificationExecutor<Issue> {
    Optional<Issue> findByIssueKey(String issueKey);
    List<Issue> findByProjectId(Long projectId);
    List<Issue> findByProjectIdIn(Collection<Long> projectIds);
    List<Issue> findByAssigneeId(Long assigneeId);
    List<Issue> findByReporterId(Long reporterId);
    List<Issue> findByStatus(IssueStatus status);
    List<Issue> findByProjectIdAndAssigneeId(Long projectId, Long assigneeId);
    List<Issue> findByProjectIdAndStatus(Long projectId, IssueStatus status);

    long countByStatus(IssueStatus status);
    long countByPriority(IssuePriority priority);
    long countByType(IssueType type);
    long countByProjectId(Long projectId);
    long countByAssigneeIdAndStatusNot(Long assigneeId, IssueStatus status);

    List<Issue> findByDueDateBeforeAndStatusNotIn(LocalDate date, List<IssueStatus> closedStatuses);
}

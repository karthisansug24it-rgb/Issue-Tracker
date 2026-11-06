package com.devtrack.repository;

import com.devtrack.model.IssueAttachment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface IssueAttachmentRepository extends JpaRepository<IssueAttachment, Long> {
    List<IssueAttachment> findByIssueIdOrderByCreatedAtAsc(Long issueId);
    void deleteByIssueId(Long issueId);
    long countByIssueId(Long issueId);
}

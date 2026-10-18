package com.devtrack.model;

import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "notifications")
public class Notification {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long recipientId;

    @Column(nullable = false)
    private String title;

    @Column(nullable = false, length = 1000)
    private String message;

    private Long relatedIssueId;
    private String relatedProjectKey;

    @Column(nullable = false)
    private String type; // ASSIGNMENT, STATUS_UPDATE, REVIEW_REQUEST, DEADLINE, MENTION

    @Column(nullable = false)
    private boolean isRead = false;

    private LocalDateTime createdAt;

    public Notification() {}

    public Notification(Long recipientId, String title, String message, Long relatedIssueId, String relatedProjectKey, String type) {
        this.recipientId = recipientId;
        this.title = title;
        this.message = message;
        this.relatedIssueId = relatedIssueId;
        this.relatedProjectKey = relatedProjectKey;
        this.type = type;
        this.isRead = false;
    }

    @PrePersist
    public void onPrePersist() {
        this.createdAt = LocalDateTime.now();
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public Long getRecipientId() { return recipientId; }
    public void setRecipientId(Long recipientId) { this.recipientId = recipientId; }

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    public String getMessage() { return message; }
    public void setMessage(String message) { this.message = message; }

    public Long getRelatedIssueId() { return relatedIssueId; }
    public void setRelatedIssueId(Long relatedIssueId) { this.relatedIssueId = relatedIssueId; }

    public String getRelatedProjectKey() { return relatedProjectKey; }
    public void setRelatedProjectKey(String relatedProjectKey) { this.relatedProjectKey = relatedProjectKey; }

    public String getType() { return type; }
    public void setType(String type) { this.type = type; }

    public boolean isRead() { return isRead; }
    public void setRead(boolean read) { isRead = read; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
}

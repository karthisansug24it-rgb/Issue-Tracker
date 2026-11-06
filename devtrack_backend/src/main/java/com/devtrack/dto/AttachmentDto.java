package com.devtrack.dto;

import com.devtrack.model.IssueAttachment;
import java.time.LocalDateTime;

public class AttachmentDto {
    private Long id;
    private Long issueId;
    private String fileName;
    private String fileType;
    private Long fileSize;
    private String fileData;
    private Long uploaderId;
    private String uploaderName;
    private LocalDateTime createdAt;

    public AttachmentDto() {}

    public static AttachmentDto fromEntity(IssueAttachment attachment) {
        AttachmentDto dto = new AttachmentDto();
        dto.setId(attachment.getId());
        dto.setIssueId(attachment.getIssueId());
        dto.setFileName(attachment.getFileName());
        dto.setFileType(attachment.getFileType());
        dto.setFileSize(attachment.getFileSize());
        dto.setFileData(attachment.getFileData());
        dto.setUploaderId(attachment.getUploaderId());
        dto.setUploaderName(attachment.getUploaderName());
        dto.setCreatedAt(attachment.getCreatedAt());
        return dto;
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public Long getIssueId() { return issueId; }
    public void setIssueId(Long issueId) { this.issueId = issueId; }

    public String getFileName() { return fileName; }
    public void setFileName(String fileName) { this.fileName = fileName; }

    public String getFileType() { return fileType; }
    public void setFileType(String fileType) { this.fileType = fileType; }

    public Long getFileSize() { return fileSize; }
    public void setFileSize(Long fileSize) { this.fileSize = fileSize; }

    public String getFileData() { return fileData; }
    public void setFileData(String fileData) { this.fileData = fileData; }

    public Long getUploaderId() { return uploaderId; }
    public void setUploaderId(Long uploaderId) { this.uploaderId = uploaderId; }

    public String getUploaderName() { return uploaderName; }
    public void setUploaderName(String uploaderName) { this.uploaderName = uploaderName; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
}

package com.devtrack.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public class CommentRequest {
    @NotBlank(message = "Comment text is required")
    @Size(max = 3000, message = "Comment must be at most 3000 characters")
    private String commentText;

    public CommentRequest() {}

    public String getCommentText() { return commentText; }
    public void setCommentText(String commentText) { this.commentText = commentText; }
}

package com.devtrack.controller;

import com.devtrack.dto.*;
import com.devtrack.model.*;
import com.devtrack.service.IssueService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/issues")
public class IssueController {

    private final IssueService issueService;

    public IssueController(IssueService issueService) {
        this.issueService = issueService;
    }

    @GetMapping
    public ResponseEntity<List<IssueDto>> getIssues(
            @RequestParam(required = false) Long projectId,
            @RequestParam(required = false) Long assigneeId,
            @RequestParam(required = false) IssueStatus status,
            @RequestParam(required = false) IssuePriority priority,
            @RequestParam(required = false) IssueType type,
            @RequestParam(required = false) String search,
            @AuthenticationPrincipal User user) {
        return ResponseEntity.ok(issueService.getIssues(projectId, assigneeId, status, priority, type, search, user));
    }

    @GetMapping("/{id}")
    public ResponseEntity<IssueDto> getIssueById(@PathVariable Long id, @AuthenticationPrincipal User user) {
        return ResponseEntity.ok(issueService.getIssueById(id, user));
    }

    @PostMapping
    public ResponseEntity<IssueDto> createIssue(@Valid @RequestBody CreateIssueRequest request,
                                               @AuthenticationPrincipal User user) {
        return ResponseEntity.ok(issueService.createIssue(request, user));
    }

    @PatchMapping("/{id}/status")
    public ResponseEntity<IssueDto> updateStatus(@PathVariable Long id,
                                                @Valid @RequestBody UpdateIssueStatusRequest request,
                                                @AuthenticationPrincipal User user) {
        return ResponseEntity.ok(issueService.updateStatus(id, request.getStatus(), request.getComment(), user));
    }

    @PatchMapping("/{id}/assignee")
    public ResponseEntity<IssueDto> assignIssue(@PathVariable Long id,
                                               @RequestBody AssignIssueRequest request,
                                               @AuthenticationPrincipal User user) {
        return ResponseEntity.ok(issueService.assignIssue(id, request.getAssigneeId(), user));
    }

    @GetMapping("/{id}/history")
    public ResponseEntity<List<IssueHistory>> getHistory(@PathVariable Long id, @AuthenticationPrincipal User user) {
        return ResponseEntity.ok(issueService.getIssueHistory(id, user));
    }

    @GetMapping("/{id}/comments")
    public ResponseEntity<List<IssueComment>> getComments(@PathVariable Long id, @AuthenticationPrincipal User user) {
        return ResponseEntity.ok(issueService.getIssueComments(id, user));
    }

    @PostMapping("/{id}/comments")
    public ResponseEntity<IssueComment> addComment(@PathVariable Long id,
                                                   @Valid @RequestBody CommentRequest request,
                                                   @AuthenticationPrincipal User user) {
        return ResponseEntity.ok(issueService.addComment(id, request.getCommentText(), user));
    }

    @GetMapping("/{id}/time-entries")
    public ResponseEntity<List<TimeEntry>> getTimeEntries(@PathVariable Long id, @AuthenticationPrincipal User user) {
        return ResponseEntity.ok(issueService.getTimeEntries(id, user));
    }

    @PostMapping("/{id}/time-entries")
    public ResponseEntity<TimeEntry> logTime(@PathVariable Long id,
                                             @Valid @RequestBody LogTimeRequest request,
                                             @AuthenticationPrincipal User user) {
        return ResponseEntity.ok(issueService.logTime(id, request.getDurationMinutes(), request.getWorkDescription(), user));
    }
}

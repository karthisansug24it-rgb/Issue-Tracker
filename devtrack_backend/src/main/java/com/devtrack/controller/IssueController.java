package com.devtrack.controller;

import com.devtrack.dto.CreateIssueRequest;
import com.devtrack.dto.IssueDto;
import com.devtrack.dto.UpdateIssueStatusRequest;
import com.devtrack.model.*;
import com.devtrack.service.IssueService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

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
    public ResponseEntity<IssueDto> getIssueById(@PathVariable Long id) {
        return ResponseEntity.ok(issueService.getIssueById(id));
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
                                               @RequestBody Map<String, Long> body,
                                               @AuthenticationPrincipal User user) {
        Long assigneeId = body.get("assigneeId");
        return ResponseEntity.ok(issueService.assignIssue(id, assigneeId, user));
    }

    @GetMapping("/{id}/history")
    public ResponseEntity<List<IssueHistory>> getHistory(@PathVariable Long id) {
        return ResponseEntity.ok(issueService.getIssueHistory(id));
    }

    @GetMapping("/{id}/comments")
    public ResponseEntity<List<IssueComment>> getComments(@PathVariable Long id) {
        return ResponseEntity.ok(issueService.getIssueComments(id));
    }

    @PostMapping("/{id}/comments")
    public ResponseEntity<IssueComment> addComment(@PathVariable Long id,
                                                   @RequestBody Map<String, String> body,
                                                   @AuthenticationPrincipal User user) {
        return ResponseEntity.ok(issueService.addComment(id, body.get("commentText"), user));
    }

    @GetMapping("/{id}/time-entries")
    public ResponseEntity<List<TimeEntry>> getTimeEntries(@PathVariable Long id) {
        return ResponseEntity.ok(issueService.getTimeEntries(id));
    }

    @PostMapping("/{id}/time-entries")
    public ResponseEntity<TimeEntry> logTime(@PathVariable Long id,
                                             @RequestBody Map<String, Object> body,
                                             @AuthenticationPrincipal User user) {
        Integer minutes = Integer.valueOf(body.get("durationMinutes").toString());
        String desc = body.containsKey("workDescription") ? body.get("workDescription").toString() : "";
        return ResponseEntity.ok(issueService.logTime(id, minutes, desc, user));
    }
}

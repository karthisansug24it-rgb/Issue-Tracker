class IssueModel {
  final int id;
  final String issueKey;
  final int projectId;
  final String projectName;
  final String projectKey;
  final int? parentIssueId;
  final String? parentIssueKey;
  final String title;
  final String description;
  final String type; // BUG, TASK, FEATURE, INCIDENT, SUPPORT_REQUEST
  final String priority; // CRITICAL, HIGH, MEDIUM, LOW
  String status; // OPEN, ASSIGNED, IN_PROGRESS, IN_REVIEW, RESOLVED, CLOSED, REOPENED, BLOCKED
  final int reporterId;
  final String reporterName;
  int? assigneeId;
  String? assigneeName;
  final String? dueDate;
  final int estimatedMinutes;
  int actualMinutes;

  int attachmentCount;
  int subtaskCount;
  int subtaskDoneCount;

  // Capabilities computed by the server for the signed-in user
  List<String> allowedTransitions;
  bool canAssign;
  bool canLogTime;
  bool canManage;

  IssueModel({
    required this.id,
    required this.issueKey,
    required this.projectId,
    this.projectName = '',
    this.projectKey = '',
    this.parentIssueId,
    this.parentIssueKey,
    required this.title,
    this.description = '',
    this.type = 'TASK',
    this.priority = 'MEDIUM',
    this.status = 'OPEN',
    this.reporterId = 0,
    this.reporterName = '',
    this.assigneeId,
    this.assigneeName,
    this.dueDate,
    this.estimatedMinutes = 0,
    this.actualMinutes = 0,
    this.attachmentCount = 0,
    this.subtaskCount = 0,
    this.subtaskDoneCount = 0,
    this.allowedTransitions = const [],
    this.canAssign = false,
    this.canLogTime = false,
    this.canManage = false,
  });

  factory IssueModel.fromJson(Map<String, dynamic> json) {
    return IssueModel(
      id: json['id'] ?? 0,
      issueKey: json['issueKey'] ?? '',
      projectId: json['projectId'] ?? 0,
      projectName: json['projectName'] ?? '',
      projectKey: json['projectKey'] ?? '',
      parentIssueId: json['parentIssueId'],
      parentIssueKey: json['parentIssueKey'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      type: json['type'] ?? 'TASK',
      priority: json['priority'] ?? 'MEDIUM',
      status: json['status'] ?? 'OPEN',
      reporterId: json['reporterId'] ?? 0,
      reporterName: json['reporterName'] ?? '',
      assigneeId: json['assigneeId'],
      assigneeName: json['assigneeName'],
      dueDate: json['dueDate'],
      estimatedMinutes: json['estimatedMinutes'] ?? 0,
      actualMinutes: json['actualMinutes'] ?? 0,
      attachmentCount: json['attachmentCount'] ?? 0,
      subtaskCount: json['subtaskCount'] ?? 0,
      subtaskDoneCount: json['subtaskDoneCount'] ?? 0,
      allowedTransitions: json['allowedTransitions'] != null
          ? List<String>.from(json['allowedTransitions'])
          : const [],
      canAssign: json['canAssign'] ?? false,
      canLogTime: json['canLogTime'] ?? false,
      canManage: json['canManage'] ?? false,
    );
  }

  /// Copies the server's latest view of this issue (after an update) into this instance.
  void applyFrom(IssueModel other) {
    status = other.status;
    assigneeId = other.assigneeId;
    assigneeName = other.assigneeName;
    actualMinutes = other.actualMinutes;
    attachmentCount = other.attachmentCount;
    subtaskCount = other.subtaskCount;
    subtaskDoneCount = other.subtaskDoneCount;
    allowedTransitions = other.allowedTransitions;
    canAssign = other.canAssign;
    canLogTime = other.canLogTime;
    canManage = other.canManage;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'issueKey': issueKey,
      'projectId': projectId,
      'projectName': projectName,
      'projectKey': projectKey,
      'parentIssueId': parentIssueId,
      'parentIssueKey': parentIssueKey,
      'title': title,
      'description': description,
      'type': type,
      'priority': priority,
      'status': status,
      'reporterId': reporterId,
      'reporterName': reporterName,
      'assigneeId': assigneeId,
      'assigneeName': assigneeName,
      'dueDate': dueDate,
      'estimatedMinutes': estimatedMinutes,
      'actualMinutes': actualMinutes,
      'attachmentCount': attachmentCount,
      'subtaskCount': subtaskCount,
      'subtaskDoneCount': subtaskDoneCount,
      'allowedTransitions': allowedTransitions,
      'canAssign': canAssign,
      'canLogTime': canLogTime,
      'canManage': canManage,
    };
  }
}

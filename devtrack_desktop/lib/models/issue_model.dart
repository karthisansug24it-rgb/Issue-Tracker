class IssueModel {
  final int id;
  final String issueKey;
  final int projectId;
  final String projectName;
  final String projectKey;
  final String title;
  final String description;
  final String type; // BUG, TASK, FEATURE, INCIDENT, SUPPORT_REQUEST
  final String priority; // CRITICAL, HIGH, MEDIUM, LOW
  String status; // OPEN, ASSIGNED, IN_PROGRESS, IN_REVIEW, RESOLVED, CLOSED
  final int reporterId;
  final String reporterName;
  int? assigneeId;
  String? assigneeName;
  final String? dueDate;
  final int estimatedMinutes;
  int actualMinutes;

  IssueModel({
    required this.id,
    required this.issueKey,
    required this.projectId,
    this.projectName = '',
    this.projectKey = '',
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
  });

  factory IssueModel.fromJson(Map<String, dynamic> json) {
    return IssueModel(
      id: json['id'] ?? 0,
      issueKey: json['issueKey'] ?? '',
      projectId: json['projectId'] ?? 0,
      projectName: json['projectName'] ?? '',
      projectKey: json['projectKey'] ?? '',
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'issueKey': issueKey,
      'projectId': projectId,
      'projectName': projectName,
      'projectKey': projectKey,
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
    };
  }
}

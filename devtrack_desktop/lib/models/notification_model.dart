class NotificationModel {
  final int id;
  final String title;
  final String message;
  final int? relatedIssueId;
  final String? relatedProjectKey;
  final String type; // ASSIGNMENT, STATUS_UPDATE, REVIEW_REQUEST, COMMENT, ...
  bool read;
  final String createdAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    this.relatedIssueId,
    this.relatedProjectKey,
    this.type = '',
    this.read = false,
    this.createdAt = '',
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      relatedIssueId: json['relatedIssueId'],
      relatedProjectKey: json['relatedProjectKey'],
      type: json['type'] ?? '',
      read: json['read'] ?? false,
      createdAt: json['createdAt'] != null
          ? json['createdAt'].toString().replaceAll('T', ' ').padRight(16).substring(0, 16)
          : '',
    );
  }
}

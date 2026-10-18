class AuditLogModel {
  final int id;
  final String actorName;
  final String action;
  final String entityType;
  final String entityId;
  final String details;
  final String timestamp;

  AuditLogModel({
    required this.id,
    required this.actorName,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.details,
    required this.timestamp,
  });

  factory AuditLogModel.fromJson(Map<String, dynamic> json) {
    return AuditLogModel(
      id: json['id'] ?? 0,
      actorName: json['actorName'] ?? 'System',
      action: json['action'] ?? '',
      entityType: json['entityType'] ?? '',
      entityId: json['entityId'] ?? '',
      details: json['details'] ?? '',
      timestamp: json['timestamp'] != null
          ? json['timestamp'].toString().substring(0, 19).replaceAll('T', ' ')
          : 'Just now',
    );
  }
}

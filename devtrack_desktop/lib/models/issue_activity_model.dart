/// A single time log on an issue.
class TimeEntryModel {
  final int id;
  final String userName;
  final int durationMinutes;
  final String workDescription;
  final String loggedAt;

  TimeEntryModel({
    required this.id,
    this.userName = '',
    this.durationMinutes = 0,
    this.workDescription = '',
    this.loggedAt = '',
  });

  factory TimeEntryModel.fromJson(Map<String, dynamic> json) {
    return TimeEntryModel(
      id: json['id'] ?? 0,
      userName: json['userName'] ?? '',
      durationMinutes: json['durationMinutes'] ?? 0,
      workDescription: json['workDescription'] ?? '',
      loggedAt: _formatTimestamp(json['loggedAt']),
    );
  }
}

/// A single change in an issue's history (status, assignee, ...).
class IssueHistoryModel {
  final int id;
  final String actorName;
  final String fieldName;
  final String? oldValue;
  final String? newValue;
  final String changedAt;

  IssueHistoryModel({
    required this.id,
    this.actorName = '',
    this.fieldName = '',
    this.oldValue,
    this.newValue,
    this.changedAt = '',
  });

  factory IssueHistoryModel.fromJson(Map<String, dynamic> json) {
    return IssueHistoryModel(
      id: json['id'] ?? 0,
      actorName: json['actorName'] ?? 'System',
      fieldName: json['fieldName'] ?? '',
      oldValue: json['oldValue'],
      newValue: json['newValue'],
      changedAt: _formatTimestamp(json['changedAt']),
    );
  }
}

String _formatTimestamp(dynamic value) {
  if (value == null) return '';
  final text = value.toString().replaceAll('T', ' ');
  return text.length > 16 ? text.substring(0, 16) : text;
}

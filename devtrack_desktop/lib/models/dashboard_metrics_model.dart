class DashboardMetricsModel {
  final String role;
  final int totalUsers;
  final int totalProjects;
  final int totalTeams;
  final int totalIssues;
  final int openIssues;
  final int inProgressIssues;
  final int inReviewIssues;
  final int resolvedIssues;
  final int closedIssues;
  final int criticalIssues;
  final int overdueIssues;
  final int myAssignedIssues;
  final int myBugs;
  final int myTasks;
  final List<Map<String, dynamic>> myTeams;

  DashboardMetricsModel({
    required this.role,
    this.totalUsers = 0,
    this.totalProjects = 0,
    this.totalTeams = 0,
    this.totalIssues = 0,
    this.openIssues = 0,
    this.inProgressIssues = 0,
    this.inReviewIssues = 0,
    this.resolvedIssues = 0,
    this.closedIssues = 0,
    this.criticalIssues = 0,
    this.overdueIssues = 0,
    this.myAssignedIssues = 0,
    this.myBugs = 0,
    this.myTasks = 0,
    this.myTeams = const [],
  });

  factory DashboardMetricsModel.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> teamList = [];
    if (json['myTeams'] != null) {
      teamList = List<Map<String, dynamic>>.from(
        (json['myTeams'] as List).map((x) => Map<String, dynamic>.from(x))
      );
    }
    return DashboardMetricsModel(
      role: json['role'] ?? 'EMPLOYEE',
      totalUsers: json['totalUsers'] ?? 0,
      totalProjects: json['totalProjects'] ?? 0,
      totalTeams: json['totalTeams'] ?? 0,
      totalIssues: json['totalIssues'] ?? 0,
      openIssues: json['openIssues'] ?? 0,
      inProgressIssues: json['inProgressIssues'] ?? 0,
      inReviewIssues: json['inReviewIssues'] ?? 0,
      resolvedIssues: json['resolvedIssues'] ?? 0,
      closedIssues: json['closedIssues'] ?? 0,
      criticalIssues: json['criticalIssues'] ?? 0,
      overdueIssues: json['overdueIssues'] ?? 0,
      myAssignedIssues: json['myAssignedIssues'] ?? 0,
      myBugs: json['myBugs'] ?? 0,
      myTasks: json['myTasks'] ?? 0,
      myTeams: teamList,
    );
  }
}

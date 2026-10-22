class ProjectMemberModel {
  final int id; // user id
  final String fullName;
  final String email;
  final String role; // global role
  final String jobTitle;
  final bool active;
  final String projectRole; // PROJECT_MANAGER, TECH_LEAD, DEVELOPER, TESTER, DESIGNER, OBSERVER
  final bool owner;

  ProjectMemberModel({
    required this.id,
    required this.fullName,
    this.email = '',
    this.role = 'EMPLOYEE',
    this.jobTitle = '',
    this.active = true,
    this.projectRole = 'DEVELOPER',
    this.owner = false,
  });

  factory ProjectMemberModel.fromJson(Map<String, dynamic> json) {
    return ProjectMemberModel(
      id: json['id'] ?? 0,
      fullName: json['fullName'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'EMPLOYEE',
      jobTitle: json['jobTitle'] ?? '',
      active: json['active'] ?? true,
      projectRole: json['projectRole'] ?? 'DEVELOPER',
      owner: json['owner'] ?? false,
    );
  }
}

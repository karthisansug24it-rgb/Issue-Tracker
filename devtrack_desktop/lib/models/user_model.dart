class UserModel {
  final int id;
  final String fullName;
  final String email;
  final String role; // SUPER_ADMIN, ADMIN, MANAGER, TEAM_LEAD, EMPLOYEE
  final String department;
  final int? departmentId;
  final String jobTitle;
  final bool active;
  // Whether the signed-in user may change this account's role / status (server computed)
  final bool canModify;

  UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.department = '',
    this.departmentId,
    this.jobTitle = '',
    this.active = true,
    this.canModify = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? 0,
      fullName: json['fullName'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'EMPLOYEE',
      department: json['department'] ?? '',
      departmentId: json['departmentId'],
      jobTitle: json['jobTitle'] ?? '',
      active: json['active'] ?? true,
      canModify: json['canModify'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'role': role,
      'department': department,
      'departmentId': departmentId,
      'jobTitle': jobTitle,
      'active': active,
      'canModify': canModify,
    };
  }
}

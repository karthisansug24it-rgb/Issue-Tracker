class UserModel {
  final int id;
  final String fullName;
  final String email;
  final String role; // SUPER_ADMIN, ADMIN, MANAGER, EMPLOYEE
  final String department;
  final String jobTitle;
  final bool active;

  UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.department = '',
    this.jobTitle = '',
    this.active = true,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? 0,
      fullName: json['fullName'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'EMPLOYEE',
      department: json['department'] ?? '',
      jobTitle: json['jobTitle'] ?? '',
      active: json['active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'role': role,
      'department': department,
      'jobTitle': jobTitle,
      'active': active,
    };
  }
}

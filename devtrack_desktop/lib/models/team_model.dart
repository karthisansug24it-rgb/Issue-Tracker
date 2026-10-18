import 'user_model.dart';

class TeamModel {
  final int id;
  final String name;
  final int? departmentId;
  final String? departmentName;
  final int? managerId;
  final String? managerName;
  final String? managerEmail;
  final int? teamLeadId;
  final String? teamLeadName;
  final String? teamLeadEmail;
  final String? description;
  final bool active;
  final List<UserModel> members;

  TeamModel({
    required this.id,
    required this.name,
    this.departmentId,
    this.departmentName,
    this.managerId,
    this.managerName,
    this.managerEmail,
    this.teamLeadId,
    this.teamLeadName,
    this.teamLeadEmail,
    this.description,
    this.active = true,
    this.members = const [],
  });

  factory TeamModel.fromJson(Map<String, dynamic> json) {
    List<UserModel> memberList = [];
    if (json['members'] != null) {
      memberList = (json['members'] as List)
          .map((m) => UserModel.fromJson(m))
          .toList();
    }
    return TeamModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      departmentId: json['departmentId'],
      departmentName: json['departmentName'],
      managerId: json['managerId'],
      managerName: json['managerName'],
      managerEmail: json['managerEmail'],
      teamLeadId: json['teamLeadId'],
      teamLeadName: json['teamLeadName'],
      teamLeadEmail: json['teamLeadEmail'],
      description: json['description'],
      active: json['active'] ?? true,
      members: memberList,
    );
  }
}

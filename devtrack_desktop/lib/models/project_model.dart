class ProjectModel {
  final int id;
  final String projectKey;
  final String name;
  final String description;
  final String status;
  final int ownerId;
  final String ownerName;
  final int totalIssues;
  final int openIssues; // unresolved: everything except RESOLVED / CLOSED
  final bool canManage; // may manage members of this project
  final bool canAssign; // may assign issues in this project

  ProjectModel({
    required this.id,
    required this.projectKey,
    required this.name,
    this.description = '',
    this.status = 'ACTIVE',
    this.ownerId = 0,
    this.ownerName = '',
    this.totalIssues = 0,
    this.openIssues = 0,
    this.canManage = false,
    this.canAssign = false,
  });

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    return ProjectModel(
      id: json['id'] ?? 0,
      projectKey: json['projectKey'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? 'ACTIVE',
      ownerId: json['ownerId'] ?? 0,
      ownerName: json['ownerName'] ?? '',
      totalIssues: json['totalIssues'] ?? 0,
      openIssues: json['openIssues'] ?? 0,
      canManage: json['canManage'] ?? false,
      canAssign: json['canAssign'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'projectKey': projectKey,
      'name': name,
      'description': description,
      'status': status,
      'ownerId': ownerId,
      'ownerName': ownerName,
      'totalIssues': totalIssues,
      'openIssues': openIssues,
      'canManage': canManage,
      'canAssign': canAssign,
    };
  }
}

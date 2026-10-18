class ProjectModel {
  final int id;
  final String projectKey;
  final String name;
  final String description;
  final String status;
  final int ownerId;
  final String ownerName;
  final int totalIssues;
  final int openIssues;

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
    };
  }
}

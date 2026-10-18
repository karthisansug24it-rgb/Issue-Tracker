class DepartmentModel {
  final int id;
  final String name;
  final String code;
  final String? description;
  final bool active;

  DepartmentModel({
    required this.id,
    required this.name,
    required this.code,
    this.description,
    this.active = true,
  });

  factory DepartmentModel.fromJson(Map<String, dynamic> json) {
    return DepartmentModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      description: json['description'],
      active: json['active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'description': description,
      'active': active,
    };
  }
}

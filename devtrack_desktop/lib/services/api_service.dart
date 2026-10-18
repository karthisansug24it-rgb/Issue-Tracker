import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/project_model.dart';
import '../models/issue_model.dart';
import '../models/comment_model.dart';
import '../models/audit_log_model.dart';
import '../models/dashboard_metrics_model.dart';
import '../models/user_model.dart';
import 'auth_state.dart';

class ApiService {
  static final ApiService instance = ApiService._internal();
  ApiService._internal();

  final String baseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080/api/v1',
  );

  Map<String, String> _headers() {
    final token = AuthState.instance.token;
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // 1. Authentication Login
  Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/auth/login');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      String errorMsg = 'Login failed (${response.statusCode})';
      try {
        final body = jsonDecode(response.body);
        if (body['message'] != null) errorMsg = body['message'];
      } catch (_) {}
      throw Exception(errorMsg);
    }
  }

  // 2. Dashboard Metrics
  Future<DashboardMetricsModel> getDashboardMetrics() async {
    final url = Uri.parse('$baseUrl/dashboard/metrics');
    final response = await http.get(url, headers: _headers());

    if (response.statusCode == 200) {
      return DashboardMetricsModel.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load dashboard metrics: ${response.statusCode}');
  }

  // 3. Projects
  Future<List<ProjectModel>> getProjects() async {
    final url = Uri.parse('$baseUrl/projects');
    final response = await http.get(url, headers: _headers());

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => ProjectModel.fromJson(e)).toList();
    }
    throw Exception('Failed to load projects: ${response.statusCode}');
  }

  Future<ProjectModel> createProject(String key, String name, String desc) async {
    final url = Uri.parse('$baseUrl/projects');
    final response = await http.post(
      url,
      headers: _headers(),
      body: jsonEncode({
        'projectKey': key.toUpperCase(),
        'name': name,
        'description': desc,
        'status': 'ACTIVE',
      }),
    );

    if (response.statusCode == 200) {
      return ProjectModel.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to create project: ${response.body}');
  }

  // 4. Issues
  Future<List<IssueModel>> getIssues({int? projectId, String? status, String? type, String? priority}) async {
    final queryParams = <String, String>{};
    if (projectId != null) queryParams['projectId'] = projectId.toString();
    if (status != null && status != 'ALL') queryParams['status'] = status;
    if (type != null && type != 'ALL') queryParams['type'] = type;
    if (priority != null && priority != 'ALL') queryParams['priority'] = priority;

    final url = Uri.parse('$baseUrl/issues').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
    final response = await http.get(url, headers: _headers());

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => IssueModel.fromJson(e)).toList();
    }
    throw Exception('Failed to load issues: ${response.statusCode}');
  }

  Future<IssueModel> createIssue({
    required int projectId,
    required String title,
    required String description,
    required String type,
    required String priority,
    int? assigneeId,
    String? dueDate,
    int estimatedMinutes = 0,
  }) async {
    final url = Uri.parse('$baseUrl/issues');
    final response = await http.post(
      url,
      headers: _headers(),
      body: jsonEncode({
        'projectId': projectId,
        'title': title,
        'description': description,
        'type': type,
        'priority': priority,
        'assigneeId': assigneeId,
        'dueDate': dueDate,
        'estimatedMinutes': estimatedMinutes,
      }),
    );

    if (response.statusCode == 200) {
      return IssueModel.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to create issue: ${response.body}');
  }

  Future<void> updateIssueStatus(int issueId, String newStatus, {String? comment}) async {
    final url = Uri.parse('$baseUrl/issues/$issueId/status');
    final response = await http.patch(
      url,
      headers: _headers(),
      body: jsonEncode({
        'status': newStatus,
        'comment': comment,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update status: ${response.body}');
    }
  }

  Future<void> reassignIssue(int issueId, int newAssigneeId) async {
    final url = Uri.parse('$baseUrl/issues/$issueId/assignee');
    final response = await http.patch(
      url,
      headers: _headers(),
      body: jsonEncode({'assigneeId': newAssigneeId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to reassign issue: ${response.body}');
    }
  }

  // 5. Comments
  Future<List<CommentModel>> getComments(int issueId) async {
    final url = Uri.parse('$baseUrl/issues/$issueId/comments');
    final response = await http.get(url, headers: _headers());

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => CommentModel.fromJson(e)).toList();
    }
    return [];
  }

  Future<CommentModel> addComment(int issueId, String text) async {
    final url = Uri.parse('$baseUrl/issues/$issueId/comments');
    final response = await http.post(
      url,
      headers: _headers(),
      body: jsonEncode({'commentText': text}),
    );

    if (response.statusCode == 200) {
      return CommentModel.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to post comment: ${response.body}');
  }

  // 6. Time Tracking
  Future<void> logTime(int issueId, int minutes, {String description = 'Work progress update'}) async {
    final url = Uri.parse('$baseUrl/issues/$issueId/time-entries');
    final response = await http.post(
      url,
      headers: _headers(),
      body: jsonEncode({
        'durationMinutes': minutes,
        'workDescription': description,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to log time: ${response.body}');
    }
  }

  // 7. Users
  Future<List<UserModel>> getUsers() async {
    final url = Uri.parse('$baseUrl/users');
    final response = await http.get(url, headers: _headers());

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => UserModel.fromJson(e)).toList();
    }
    return [];
  }

  // 8. Audit Logs
  Future<List<AuditLogModel>> getAuditLogs() async {
    final url = Uri.parse('$baseUrl/audit-logs');
    final response = await http.get(url, headers: _headers());

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => AuditLogModel.fromJson(e)).toList();
    }
    return [];
  }

  // 9. Departments and Teams
  Future<List<dynamic>> getDepartments() async {
    final url = Uri.parse('$baseUrl/departments');
    final response = await http.get(url, headers: _headers());
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  Future<List<dynamic>> getTeams() async {
    final url = Uri.parse('$baseUrl/teams');
    final response = await http.get(url, headers: _headers());
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/project_model.dart';
import '../models/project_member_model.dart';
import '../models/issue_model.dart';
import '../models/issue_activity_model.dart';
import '../models/comment_model.dart';
import '../models/audit_log_model.dart';
import '../models/dashboard_metrics_model.dart';
import '../models/notification_model.dart';
import '../models/user_model.dart';
import '../models/department_model.dart';
import '../models/team_model.dart';
import 'auth_state.dart';

/// Error raised for any failed API call. [message] is already user friendly
/// (taken from the server's "message" field when available).
class ApiException implements Exception {
  final int statusCode; // 0 when the server could not be reached
  final String message;

  ApiException(this.statusCode, this.message);

  bool get isForbidden => statusCode == 403;

  @override
  String toString() => message;
}

class ApiService {
  static final ApiService instance = ApiService._internal();
  ApiService._internal();

  final String baseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080/api/v1',
  );

  static const _timeout = Duration(seconds: 20);

  Map<String, String> _headers({bool auth = true}) {
    final token = AuthState.instance.token;
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (auth && token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Sends a request and returns the decoded JSON body (or null for empty bodies).
  /// Throws [ApiException] on any failure. A 401 on an authenticated call means the
  /// session is no longer valid, so the user is signed out.
  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool auth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: (query != null && query.isNotEmpty) ? query : null,
    );
    final request = http.Request(method, uri)..headers.addAll(_headers(auth: auth));
    if (body != null) request.body = jsonEncode(body);

    http.Response response;
    try {
      response = await http.Response.fromStream(await request.send().timeout(_timeout));
    } on TimeoutException {
      throw ApiException(0, 'The DevTrack server did not respond in time. Please try again.');
    } catch (_) {
      throw ApiException(0, 'Cannot reach the DevTrack server at $baseUrl. Is the backend running?');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }

    String message = _defaultMessage(response.statusCode);
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['message'] is String && (decoded['message'] as String).isNotEmpty) {
        message = decoded['message'];
      }
    } catch (_) {}

    if (response.statusCode == 401 && auth && AuthState.instance.token != null) {
      AuthState.instance.handleSessionExpired();
    }
    throw ApiException(response.statusCode, message);
  }

  String _defaultMessage(int status) {
    switch (status) {
      case 400:
        return 'The request was invalid.';
      case 401:
        return 'Your session has expired. Please sign in again.';
      case 403:
        return 'You do not have permission to perform this action.';
      case 404:
        return 'The requested item was not found.';
      case 409:
        return 'This change conflicts with existing data.';
      default:
        return 'Server error ($status). Please try again.';
    }
  }

  List<T> _list<T>(dynamic data, T Function(Map<String, dynamic>) parse) {
    return (data as List).map((e) => parse(Map<String, dynamic>.from(e))).toList();
  }

  // 1. Authentication
  Future<Map<String, dynamic>> login(String email, String password) async {
    final data = await _send('POST', '/auth/login',
        body: {'email': email, 'password': password}, auth: false);
    return Map<String, dynamic>.from(data);
  }

  /// Public account creation. New accounts always start with the EMPLOYEE role.
  Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String password,
    String? department,
    String? jobTitle,
  }) async {
    final data = await _send('POST', '/auth/register', auth: false, body: {
      'fullName': fullName.trim(),
      'email': email.trim().toLowerCase(),
      'password': password,
      'department': department ?? 'Engineering',
      'jobTitle': jobTitle ?? 'Employee',
    });
    return Map<String, dynamic>.from(data);
  }

  /// Current user including the permission list.
  Future<Map<String, dynamic>> getCurrentUserInfo() async {
    return Map<String, dynamic>.from(await _send('GET', '/auth/me'));
  }

  Future<UserModel> getCurrentUser() async {
    return UserModel.fromJson(await getCurrentUserInfo());
  }

  Future<void> logout() async {
    try {
      await _send('POST', '/auth/logout', auth: false);
    } catch (_) {}
  }

  // 2. Dashboard
  Future<DashboardMetricsModel> getDashboardMetrics() async {
    return DashboardMetricsModel.fromJson(await _send('GET', '/dashboard/metrics'));
  }

  // 3. Projects
  Future<List<ProjectModel>> getProjects() async {
    return _list(await _send('GET', '/projects'), ProjectModel.fromJson);
  }

  Future<ProjectModel> createProject(String key, String name, String desc) async {
    final data = await _send('POST', '/projects', body: {
      'projectKey': key.trim().toUpperCase(),
      'name': name.trim(),
      'description': desc.trim(),
      'status': 'ACTIVE',
    });
    return ProjectModel.fromJson(data);
  }

  Future<List<ProjectMemberModel>> getProjectMembers(int projectId) async {
    return _list(await _send('GET', '/projects/$projectId/members'), ProjectMemberModel.fromJson);
  }

  Future<void> addProjectMember(int projectId, int userId, String projectRole) async {
    await _send('POST', '/projects/$projectId/members', body: {'userId': userId, 'projectRole': projectRole});
  }

  Future<void> removeProjectMember(int projectId, int userId) async {
    await _send('DELETE', '/projects/$projectId/members/$userId');
  }

  // 4. Issues
  Future<List<IssueModel>> getIssues({int? projectId, String? status, String? type, String? priority, String? search}) async {
    final query = <String, String>{};
    if (projectId != null) query['projectId'] = projectId.toString();
    if (status != null && status != 'ALL') query['status'] = status;
    if (type != null && type != 'ALL') query['type'] = type;
    if (priority != null && priority != 'ALL') query['priority'] = priority;
    if (search != null && search.trim().isNotEmpty) query['search'] = search.trim();
    return _list(await _send('GET', '/issues', query: query), IssueModel.fromJson);
  }

  Future<IssueModel> getIssue(int issueId) async {
    return IssueModel.fromJson(await _send('GET', '/issues/$issueId'));
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
    final data = await _send('POST', '/issues', body: {
      'projectId': projectId,
      'title': title.trim(),
      'description': description.trim(),
      'type': type,
      'priority': priority,
      'assigneeId': assigneeId,
      'dueDate': dueDate,
      'estimatedMinutes': estimatedMinutes,
    });
    return IssueModel.fromJson(data);
  }

  Future<IssueModel> updateIssueStatus(int issueId, String newStatus, {String? comment}) async {
    final data = await _send('PATCH', '/issues/$issueId/status', body: {
      'status': newStatus,
      'comment': comment,
    });
    return IssueModel.fromJson(data);
  }

  /// Assigns the issue; pass null to unassign.
  Future<IssueModel> assignIssue(int issueId, int? assigneeId) async {
    final data = await _send('PATCH', '/issues/$issueId/assignee', body: {'assigneeId': assigneeId});
    return IssueModel.fromJson(data);
  }

  Future<List<IssueHistoryModel>> getIssueHistory(int issueId) async {
    return _list(await _send('GET', '/issues/$issueId/history'), IssueHistoryModel.fromJson);
  }

  // 5. Comments
  Future<List<CommentModel>> getComments(int issueId) async {
    return _list(await _send('GET', '/issues/$issueId/comments'), CommentModel.fromJson);
  }

  Future<CommentModel> addComment(int issueId, String text) async {
    return CommentModel.fromJson(await _send('POST', '/issues/$issueId/comments', body: {'commentText': text}));
  }

  // 6. Time Tracking
  Future<void> logTime(int issueId, int minutes, {String description = ''}) async {
    await _send('POST', '/issues/$issueId/time-entries', body: {
      'durationMinutes': minutes,
      'workDescription': description,
    });
  }

  Future<List<TimeEntryModel>> getTimeEntries(int issueId) async {
    return _list(await _send('GET', '/issues/$issueId/time-entries'), TimeEntryModel.fromJson);
  }

  // 7. Users (staff directory is Team Lead and above)
  Future<List<UserModel>> getUsers() async {
    return _list(await _send('GET', '/users'), UserModel.fromJson);
  }

  Future<UserModel> updateUserRole(int userId, String newRole) async {
    return UserModel.fromJson(await _send('PATCH', '/users/$userId/role', body: {'role': newRole}));
  }

  Future<UserModel> toggleUserStatus(int userId) async {
    return UserModel.fromJson(await _send('PATCH', '/users/$userId/status'));
  }

  // 8. Audit Logs
  Future<List<AuditLogModel>> getAuditLogs() async {
    return _list(await _send('GET', '/audit-logs'), AuditLogModel.fromJson);
  }

  // 9. Notifications
  Future<List<NotificationModel>> getNotifications() async {
    return _list(await _send('GET', '/notifications'), NotificationModel.fromJson);
  }

  Future<int> getUnreadNotificationCount() async {
    final data = await _send('GET', '/notifications/unread-count');
    return (data['count'] as num?)?.toInt() ?? 0;
  }

  Future<void> markNotificationRead(int id) async {
    await _send('PATCH', '/notifications/$id/read');
  }

  Future<void> markAllNotificationsRead() async {
    await _send('PATCH', '/notifications/read-all');
  }

  // 10. Departments
  Future<List<DepartmentModel>> getDepartments() async {
    return _list(await _send('GET', '/departments'), DepartmentModel.fromJson);
  }

  Future<DepartmentModel> createDepartment({
    required String name,
    required String code,
    String? description,
  }) async {
    final data = await _send('POST', '/departments', body: {
      'name': name.trim(),
      'code': code.trim().toUpperCase(),
      'description': description?.trim(),
      'active': true,
    });
    return DepartmentModel.fromJson(data);
  }

  Future<DepartmentModel> updateDepartment(
    int id, {
    required String name,
    required String code,
    String? description,
    bool active = true,
  }) async {
    final data = await _send('PUT', '/departments/$id', body: {
      'name': name.trim(),
      'code': code.trim().toUpperCase(),
      'description': description?.trim(),
      'active': active,
    });
    return DepartmentModel.fromJson(data);
  }

  Future<void> deleteDepartment(int id) async {
    await _send('DELETE', '/departments/$id');
  }

  // 11. Teams
  Future<List<TeamModel>> getTeams({int? departmentId}) async {
    final query = <String, String>{};
    if (departmentId != null) query['departmentId'] = departmentId.toString();
    return _list(await _send('GET', '/teams', query: query), TeamModel.fromJson);
  }

  Future<TeamModel> createTeam({
    required String name,
    required int departmentId,
    String? description,
    int? managerId,
    int? teamLeadId,
  }) async {
    final data = await _send('POST', '/teams', body: {
      'name': name.trim(),
      'departmentId': departmentId,
      'managerId': managerId,
      'teamLeadId': teamLeadId,
      'description': description?.trim(),
      'active': true,
    });
    return TeamModel.fromJson(data);
  }

  Future<TeamModel> updateTeam(
    int id, {
    required String name,
    required int departmentId,
    String? description,
    int? managerId,
    int? teamLeadId,
    bool active = true,
  }) async {
    final data = await _send('PUT', '/teams/$id', body: {
      'name': name.trim(),
      'departmentId': departmentId,
      'managerId': managerId,
      'teamLeadId': teamLeadId,
      'description': description?.trim(),
      'active': active,
    });
    return TeamModel.fromJson(data);
  }

  Future<void> deleteTeam(int id) async {
    await _send('DELETE', '/teams/$id');
  }

  Future<void> addTeamMember(int teamId, int userId) async {
    await _send('POST', '/teams/$teamId/members', body: {'userId': userId});
  }

  Future<void> removeTeamMember(int teamId, int userId) async {
    await _send('DELETE', '/teams/$teamId/members/$userId');
  }
}

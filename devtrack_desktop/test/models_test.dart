import 'package:flutter_test/flutter_test.dart';
import 'package:devtrack_desktop/models/issue_model.dart';
import 'package:devtrack_desktop/models/notification_model.dart';
import 'package:devtrack_desktop/models/project_model.dart';
import 'package:devtrack_desktop/models/user_model.dart';

void main() {
  test('IssueModel reads server-computed capabilities', () {
    final issue = IssueModel.fromJson({
      'id': 7,
      'issueKey': 'WEB-101',
      'projectId': 1,
      'title': 'Login button not working',
      'status': 'ASSIGNED',
      'allowedTransitions': ['IN_PROGRESS', 'BLOCKED'],
      'canAssign': false,
      'canLogTime': true,
    });
    expect(issue.allowedTransitions, ['IN_PROGRESS', 'BLOCKED']);
    expect(issue.canAssign, isFalse);
    expect(issue.canLogTime, isTrue);
  });

  test('IssueModel defaults to no capabilities when fields are missing', () {
    final issue = IssueModel.fromJson({'id': 1, 'issueKey': 'X-1', 'projectId': 1, 'title': 't'});
    expect(issue.allowedTransitions, isEmpty);
    expect(issue.canAssign, isFalse);
    expect(issue.canLogTime, isFalse);
  });

  test('applyFrom copies the updated state including unassignment', () {
    final issue = IssueModel(id: 1, issueKey: 'X-1', projectId: 1, title: 't', assigneeId: 5, assigneeName: 'A');
    issue.applyFrom(IssueModel(id: 1, issueKey: 'X-1', projectId: 1, title: 't', status: 'OPEN',
        allowedTransitions: const ['ASSIGNED']));
    expect(issue.assigneeId, isNull);
    expect(issue.assigneeName, isNull);
    expect(issue.status, 'OPEN');
    expect(issue.allowedTransitions, ['ASSIGNED']);
  });

  test('ProjectModel and UserModel read permission flags', () {
    expect(ProjectModel.fromJson({'id': 1, 'projectKey': 'WEB', 'name': 'Web', 'canManage': true}).canManage, isTrue);
    final user = UserModel.fromJson({'id': 2, 'fullName': 'A', 'email': 'a@x', 'role': 'ADMIN', 'canModify': true, 'departmentId': 3});
    expect(user.canModify, isTrue);
    expect(user.departmentId, 3);
  });

  test('NotificationModel maps the server "read" flag and timestamp', () {
    final n = NotificationModel.fromJson({
      'id': 1,
      'title': 'Hi',
      'message': 'm',
      'read': true,
      'createdAt': '2026-10-22T09:15:30.123',
    });
    expect(n.read, isTrue);
    expect(n.createdAt, '2026-10-22 09:15');
  });
}

import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../utils/storage_helper.dart';
import 'api_service.dart';

class AuthState extends ChangeNotifier {
  static final AuthState instance = AuthState._internal();
  AuthState._internal() {
    _restoreSession();
  }

  UserModel? _currentUser;
  String? _token;
  List<String> _permissions = [];
  bool _isInitializing = true;
  String? _sessionMessage;

  UserModel? get currentUser => _currentUser;
  String? get token => _token;
  List<String> get permissions => _permissions;
  bool get isInitializing => _isInitializing;

  /// Shown once on the login screen, e.g. after the session expired.
  String? takeSessionMessage() {
    final msg = _sessionMessage;
    _sessionMessage = null;
    return msg;
  }

  bool get isLoggedIn => _currentUser != null && _token != null;

  // Role helpers are cumulative: each includes every role above it
  bool get isSuperAdmin => _currentUser?.role == 'SUPER_ADMIN';
  bool get isAdmin => _currentUser?.role == 'ADMIN' || isSuperAdmin;
  bool get isManager => _currentUser?.role == 'MANAGER' || isAdmin;
  bool get isTeamLead => _currentUser?.role == 'TEAM_LEAD' || isManager;
  bool get isEmployee => _currentUser?.role == 'EMPLOYEE';

  /// Permission names come from the server (see RolePermissions.java).
  bool hasPermission(String permission) => _permissions.contains(permission);

  void _applyUserInfo(Map<String, dynamic> info) {
    _currentUser = UserModel(
      id: info['id'] ?? 0,
      fullName: info['fullName'] ?? '',
      email: info['email'] ?? '',
      role: info['role'] ?? 'EMPLOYEE',
      department: info['department'] ?? '',
      departmentId: info['departmentId'],
      jobTitle: info['jobTitle'] ?? '',
      active: info['active'] ?? true,
    );
    _permissions = info['permissions'] != null ? List<String>.from(info['permissions']) : [];
  }

  void _persist() {
    if (_token != null) saveStorageString('auth_token', _token!);
    if (_currentUser != null) saveStorageString('auth_user', jsonEncode(_currentUser!.toJson()));
    saveStorageString('auth_permissions', jsonEncode(_permissions));
  }

  void _clear() {
    _currentUser = null;
    _token = null;
    _permissions = [];
    removeStorageString('auth_token');
    removeStorageString('auth_user');
    removeStorageString('auth_permissions');
  }

  Future<void> _restoreSession() async {
    try {
      final savedToken = getStorageString('auth_token');
      if (savedToken == null || savedToken.isEmpty) return;

      _token = savedToken;
      try {
        final savedUser = getStorageString('auth_user');
        if (savedUser != null && savedUser.isNotEmpty) {
          _currentUser = UserModel.fromJson(jsonDecode(savedUser));
        }
        final savedPerms = getStorageString('auth_permissions');
        if (savedPerms != null && savedPerms.isNotEmpty) {
          _permissions = List<String>.from(jsonDecode(savedPerms));
        }
      } catch (_) {}

      // Refresh role and permissions from the server (they may have changed)
      try {
        _applyUserInfo(await ApiService.instance.getCurrentUserInfo());
        _persist();
      } on ApiException catch (e) {
        if (e.statusCode == 0) {
          // Server unreachable: keep the cached session, calls will retry later
          if (_currentUser == null) _clear();
        } else {
          _clear(); // token expired, revoked or account disabled
        }
      }
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    final result = await ApiService.instance.login(email.trim(), password);
    _token = result['token'];
    _applyUserInfo(result);
    _persist();
    notifyListeners();
  }

  /// Re-reads the signed-in user's role and permissions (e.g. after an admin changed them).
  Future<void> refresh() async {
    if (!isLoggedIn) return;
    try {
      _applyUserInfo(await ApiService.instance.getCurrentUserInfo());
      _persist();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> register({
    required String fullName,
    required String email,
    required String password,
    String? department,
    String? jobTitle,
  }) async {
    await ApiService.instance.register(
      fullName: fullName,
      email: email,
      password: password,
      department: department,
      jobTitle: jobTitle,
    );
  }

  /// Called by ApiService when the server rejects the token.
  void handleSessionExpired() {
    if (!isLoggedIn) return;
    _clear();
    _sessionMessage = 'Your session has expired or your access changed. Please sign in again.';
    notifyListeners();
  }

  void logout() {
    ApiService.instance.logout();
    _clear();
    notifyListeners();
  }
}

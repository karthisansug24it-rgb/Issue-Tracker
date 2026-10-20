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

  UserModel? get currentUser => _currentUser;
  String? get token => _token;
  List<String> get permissions => _permissions;
  bool get isInitializing => _isInitializing;

  bool get isLoggedIn => _currentUser != null && _token != null;

  bool get isSuperAdmin => _currentUser?.role == 'SUPER_ADMIN';
  bool get isAdmin => _currentUser?.role == 'ADMIN' || isSuperAdmin;
  bool get isManager => _currentUser?.role == 'MANAGER' || isAdmin;
  bool get isTeamLead => _currentUser?.role == 'TEAM_LEAD' || isManager;
  bool get isEmployee => _currentUser?.role == 'EMPLOYEE';

  Future<void> _restoreSession() async {
    try {
      final savedToken = getStorageString('auth_token');
      final savedUserJson = getStorageString('auth_user');

      if (savedToken != null && savedToken.isNotEmpty) {
        _token = savedToken;
        if (savedUserJson != null && savedUserJson.isNotEmpty) {
          try {
            _currentUser = UserModel.fromJson(jsonDecode(savedUserJson));
          } catch (_) {}
        }

        // Verify and refresh with backend
        try {
          final liveUser = await ApiService.instance.getCurrentUser();
          _currentUser = liveUser;
          saveStorageString('auth_user', jsonEncode(liveUser.toJson()));
        } catch (e) {
          // Only clear session if backend explicitly responds with 401 Unauthorized
          final errStr = e.toString().toLowerCase();
          if (errStr.contains('401') || errStr.contains('unauthorized')) {
            _token = null;
            _currentUser = null;
            removeStorageString('auth_token');
            removeStorageString('auth_user');
          }
          // If it was a network hiccup or server startup lag, preserve the cached session
        }
      }
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    final result = await ApiService.instance.login(email.trim(), password.trim());
    _token = result['token'];
    _currentUser = UserModel(
      id: result['id'] ?? 0,
      fullName: result['fullName'] ?? '',
      email: result['email'] ?? '',
      role: result['role'] ?? 'EMPLOYEE',
      department: result['department'] ?? '',
      jobTitle: result['jobTitle'] ?? '',
      active: true,
    );
    if (result['permissions'] != null) {
      _permissions = List<String>.from(result['permissions']);
    }

    if (_token != null) {
      saveStorageString('auth_token', _token!);
    }
    if (_currentUser != null) {
      saveStorageString('auth_user', jsonEncode(_currentUser!.toJson()));
    }

    notifyListeners();
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

  void logout() {
    ApiService.instance.logout();
    _currentUser = null;
    _token = null;
    _permissions = [];
    removeStorageString('auth_token');
    removeStorageString('auth_user');
    notifyListeners();
  }
}

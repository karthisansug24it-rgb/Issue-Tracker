import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class AuthState extends ChangeNotifier {
  static final AuthState instance = AuthState._internal();
  AuthState._internal();

  UserModel? _currentUser;
  String? _token;
  List<String> _permissions = [];

  UserModel? get currentUser => _currentUser;
  String? get token => _token;
  List<String> get permissions => _permissions;

  bool get isLoggedIn => _currentUser != null && _token != null;

  bool get isSuperAdmin => _currentUser?.role == 'SUPER_ADMIN';
  bool get isAdmin => _currentUser?.role == 'ADMIN' || isSuperAdmin;
  bool get isManager => _currentUser?.role == 'MANAGER' || isAdmin;
  bool get isEmployee => _currentUser?.role == 'EMPLOYEE';

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
    notifyListeners();
  }

  void logout() {
    _currentUser = null;
    _token = null;
    _permissions = [];
    notifyListeners();
  }
}

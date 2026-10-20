import '../models/user_model.dart';
import '../utils/url_helper.dart';

enum RoleRoute {
  superAdmin('/superadmin', 'SUPER_ADMIN', 5, 'Super Admin Portal'),
  admin('/admin', 'ADMIN', 4, 'Administrator Portal'),
  manager('/manager', 'MANAGER', 3, 'Management Portal'),
  teamLead('/teamlead', 'TEAM_LEAD', 2, 'Team Lead Portal'),
  employee('/employee', 'EMPLOYEE', 1, 'Employee Workspace');

  final String path;
  final String roleName;
  final int minRank;
  final String title;

  const RoleRoute(this.path, this.roleName, this.minRank, this.title);

  static int getRoleRank(String? role) {
    switch (role) {
      case 'SUPER_ADMIN':
        return 5;
      case 'ADMIN':
        return 4;
      case 'MANAGER':
        return 3;
      case 'TEAM_LEAD':
        return 2;
      case 'EMPLOYEE':
      default:
        return 1;
    }
  }

  static String getRoleDefaultPath(String? role) {
    switch (role) {
      case 'SUPER_ADMIN':
        return '/superadmin';
      case 'ADMIN':
        return '/admin';
      case 'MANAGER':
        return '/manager';
      case 'TEAM_LEAD':
        return '/teamlead';
      case 'EMPLOYEE':
      default:
        return '/employee';
    }
  }

  static RoleRoute? fromPath(String rawPath) {
    final clean = rawPath.toLowerCase().trim();
    if (clean.contains('/superadmin')) return RoleRoute.superAdmin;
    if (clean.contains('/admin')) return RoleRoute.admin;
    if (clean.contains('/manager')) return RoleRoute.manager;
    if (clean.contains('/teamlead')) return RoleRoute.teamLead;
    if (clean.contains('/employee')) return RoleRoute.employee;
    return null;
  }
}

class RouteVerificationResult {
  final bool isAllowed;
  final String resolvedPath;
  final int initialTabIndex;
  final String? denialMessage;

  const RouteVerificationResult({
    required this.isAllowed,
    required this.resolvedPath,
    this.initialTabIndex = 0,
    this.denialMessage,
  });
}

class AppRouter {
  static int tabNameToIndex(String? tab, UserModel user) {
    if (tab == null) return 0;
    switch (tab.toLowerCase().trim()) {
      case 'dashboard':
        return 0;
      case 'projects':
        return 1;
      case 'issues':
        return 2;
      case 'teams':
        return (user.role == 'TEAM_LEAD' || user.role == 'MANAGER' || user.role == 'ADMIN' || user.role == 'SUPER_ADMIN') ? 3 : 0;
      case 'users':
        return (user.role == 'MANAGER' || user.role == 'ADMIN' || user.role == 'SUPER_ADMIN') ? 4 : 0;
      case 'audit':
      case 'audit_logs':
      case 'auditlogs':
        return (user.role == 'ADMIN' || user.role == 'SUPER_ADMIN') ? 5 : 0;
      default:
        return 0;
    }
  }

  static String indexToTabName(int index, UserModel user) {
    switch (index) {
      case 0:
        return 'dashboard';
      case 1:
        return 'projects';
      case 2:
        return 'issues';
      case 3:
        return 'teams';
      case 4:
        return 'users';
      case 5:
        return 'audit';
      default:
        return 'dashboard';
    }
  }

  /// Strictly verifies the current URL against the logged-in user's role.
  /// If the user tries to access a path above their role hierarchy (e.g. Employee visiting /superadmin),
  /// it strictly denies access and returns the authorized fallback route.
  static RouteVerificationResult verifyRoute(String rawLocation, UserModel? currentUser) {
    if (currentUser == null) {
      return const RouteVerificationResult(
        isAllowed: false,
        resolvedPath: '/login',
        initialTabIndex: 0,
        denialMessage: 'Authentication required. Please sign in to continue.',
      );
    }

    Uri uri;
    try {
      uri = Uri.parse(rawLocation.startsWith('/') ? rawLocation : '/$rawLocation');
    } catch (_) {
      uri = Uri.parse('/');
    }

    // Check query parameter override: ?role=superadmin
    String path = uri.path.toLowerCase();
    final roleParam = uri.queryParameters['role']?.toLowerCase();
    if (roleParam != null && roleParam.isNotEmpty) {
      path = '/$roleParam';
    }

    final targetRoute = RoleRoute.fromPath(path);
    final userRank = RoleRoute.getRoleRank(currentUser.role);
    final initialTab = tabNameToIndex(uri.queryParameters['tab'], currentUser);

    if (targetRoute == null) {
      // Unspecified or root path -> redirect to user's authorized role default
      final defaultPath = RoleRoute.getRoleDefaultPath(currentUser.role);
      return RouteVerificationResult(
        isAllowed: true,
        resolvedPath: defaultPath,
        initialTabIndex: initialTab,
      );
    }

    // Strict Role Guard
    if (userRank >= targetRoute.minRank) {
      // Access Granted
      return RouteVerificationResult(
        isAllowed: true,
        resolvedPath: targetRoute.path,
        initialTabIndex: initialTab,
      );
    } else {
      // Strict Access Denied: User attempted to access unauthorized role URL parameter
      final fallbackPath = RoleRoute.getRoleDefaultPath(currentUser.role);
      return RouteVerificationResult(
        isAllowed: false,
        resolvedPath: fallbackPath,
        initialTabIndex: 0,
        denialMessage: 'Access Denied: The URL path "${targetRoute.path}" strictly requires ${targetRoute.roleName} privileges. Redirected to your authorized portal.',
      );
    }
  }

  /// Updates the browser address bar with the current role path and optional tab parameter.
  static void syncUrl({required String role, required int tabIndex, required UserModel user}) {
    final basePath = RoleRoute.getRoleDefaultPath(role);
    final tabName = indexToTabName(tabIndex, user);
    final fullUrl = tabName == 'dashboard' ? basePath : '$basePath?tab=$tabName';
    setBrowserUrl(fullUrl);
  }
}

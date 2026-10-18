import 'package:flutter/material.dart';
import '../services/auth_state.dart';
import 'dashboard_screen.dart';
import 'projects_screen.dart';
import 'issues_screen.dart';
import 'teams_screen.dart';
import 'users_screen.dart';
import 'audit_logs_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    AuthState.instance.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    AuthState.instance.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    setState(() {
      _selectedIndex = 0; // reset to dashboard on auth change
    });
  }

  void _onNavigateToTab(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthState.instance.currentUser!;

    // Build navigation tabs based on user's exact role
    final destinations = <NavigationRailDestination>[
      const NavigationRailDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard),
        label: Text('Dashboard'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.folder_outlined),
        selectedIcon: Icon(Icons.folder),
        label: Text('Projects'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.bug_report_outlined),
        selectedIcon: Icon(Icons.bug_report),
        label: Text('Issues'),
      ),
    ];

    final screens = <Widget>[
      DashboardScreen(onNavigateToTab: _onNavigateToTab),
      ProjectsScreen(onNavigateToTab: _onNavigateToTab),
      const IssuesScreen(),
    ];

    if (AuthState.instance.isManager || AuthState.instance.isAdmin) {
      destinations.add(
        const NavigationRailDestination(
          icon: Icon(Icons.groups_outlined),
          selectedIcon: Icon(Icons.groups),
          label: Text('Teams'),
        ),
      );
      screens.add(const TeamsScreen());
    }

    if (AuthState.instance.isAdmin) {
      destinations.add(
        const NavigationRailDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people),
          label: Text('Users'),
        ),
      );
      screens.add(const UsersScreen());

      destinations.add(
        const NavigationRailDestination(
          icon: Icon(Icons.shield_outlined),
          selectedIcon: Icon(Icons.shield),
          label: Text('Audit Logs'),
        ),
      );
      screens.add(const AuditLogsScreen());
    }

    // Safety index clamp
    final activeIndex = _selectedIndex < screens.length ? _selectedIndex : 0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E40AF),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.track_changes, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'DevTrack',
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          // User Badge
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: _getRoleColor(user.role),
                  child: Text(
                    user.fullName.isNotEmpty ? user.fullName[0] : 'U',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.fullName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
                    Text('${user.role} · ${user.department}', style: TextStyle(fontSize: 11, color: _getRoleColor(user.role))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Real Logout Button
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.logout, size: 16),
              label: const Text('Sign Out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: () {
                AuthState.instance.logout();
              },
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          // Role-Restricted Left Sidebar NavigationRail
          NavigationRail(
            selectedIndex: activeIndex,
            onDestinationSelected: (index) => setState(() => _selectedIndex = index),
            labelType: NavigationRailLabelType.all,
            backgroundColor: Colors.white,
            minWidth: 92,
            selectedIconTheme: const IconThemeData(color: Color(0xFF1E40AF)),
            selectedLabelTextStyle: const TextStyle(color: Color(0xFF1E40AF), fontWeight: FontWeight.bold, fontSize: 12),
            unselectedLabelTextStyle: const TextStyle(color: Colors.black54, fontSize: 12),
            destinations: destinations,
          ),
          const VerticalDivider(thickness: 1, width: 1),

          // Main View Content
          Expanded(child: screens[activeIndex]),
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'SUPER_ADMIN': return Colors.purple;
      case 'ADMIN': return Colors.indigo;
      case 'MANAGER': return Colors.blue.shade700;
      default: return Colors.teal;
    }
  }
}

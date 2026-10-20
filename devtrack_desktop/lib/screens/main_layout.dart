import 'package:flutter/material.dart';
import '../services/auth_state.dart';
import 'dashboard_screen.dart';
import 'projects_screen.dart';
import 'issues_screen.dart';
import 'teams_screen.dart';
import 'users_screen.dart';
import 'audit_logs_screen.dart';

import '../services/app_router.dart';
import '../utils/url_helper.dart';

class MainLayout extends StatefulWidget {
  final int initialTabIndex;
  final String? denialNotice;

  const MainLayout({
    super.key,
    this.initialTabIndex = 0,
    this.denialNotice,
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTabIndex;
    AuthState.instance.addListener(_onAuthChanged);
    _syncCurrentUrl();

    listenToUrlChanges(_onBrowserUrlChanged);

    if (widget.denialNotice != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red.shade900,
              behavior: SnackBarBehavior.floating,
              content: Row(
                children: [
                  const Icon(Icons.gpp_bad, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.denialNotice!,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              duration: const Duration(seconds: 6),
            ),
          );
        }
      });
    }
  }

  void _onBrowserUrlChanged(String newLocation) {
    final user = AuthState.instance.currentUser;
    if (user != null && mounted) {
      final result = AppRouter.verifyRoute(newLocation, user);
      if (result.isAllowed) {
        if (_selectedIndex != result.initialTabIndex) {
          setState(() {
            _selectedIndex = result.initialTabIndex;
          });
        }
      } else {
        // Strict guard: revert URL and alert user
        _syncCurrentUrl();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade900,
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                const Icon(Icons.shield, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.denialMessage ?? 'Unauthorized route access.',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _syncCurrentUrl() {
    final user = AuthState.instance.currentUser;
    if (user != null) {
      AppRouter.syncUrl(
        role: user.role,
        tabIndex: _selectedIndex,
        user: user,
      );
    }
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
    _syncCurrentUrl();
  }

  void _onNavigateToTab(int index) {
    setState(() => _selectedIndex = index);
    _syncCurrentUrl();
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

    if (AuthState.instance.isTeamLead || AuthState.instance.isManager || AuthState.instance.isAdmin) {
      destinations.add(
        const NavigationRailDestination(
          icon: Icon(Icons.groups_outlined),
          selectedIcon: Icon(Icons.groups),
          label: Text('Teams'),
        ),
      );
      screens.add(const TeamsScreen());
    }

    if (AuthState.instance.isManager || AuthState.instance.isAdmin) {
      destinations.add(
        const NavigationRailDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people),
          label: Text('Users'),
        ),
      );
      screens.add(const UsersScreen());
    }

    if (AuthState.instance.isAdmin) {
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        final isCompactAppBar = constraints.maxWidth < 560;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 1,
            titleSpacing: isMobile ? 12 : null,
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
                const SizedBox(width: 8),
                const Text(
                  'DevTrack',
                  style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                if (!isMobile) ...[
                  const SizedBox(width: 10),
                  Tooltip(
                    message: 'Active Role Route & Verified Security Context',
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock_outline, size: 12, color: Color(0xFF1E40AF)),
                          const SizedBox(width: 4),
                          Text(
                            '${RoleRoute.getRoleDefaultPath(user.role)}${AppRouter.indexToTabName(activeIndex, user) == 'dashboard' ? '' : '?tab=${AppRouter.indexToTabName(activeIndex, user)}'}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E40AF),
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              // User Badge (Responsive: Avatar only if compact, full details if wide)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: isCompactAppBar ? 6 : 12),
                child: isCompactAppBar
                    ? Tooltip(
                        message: '${user.fullName}\n${user.role} · ${user.department}',
                        child: CircleAvatar(
                          radius: 15,
                          backgroundColor: _getRoleColor(user.role),
                          child: Text(
                            user.fullName.isNotEmpty ? user.fullName[0] : 'U',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      )
                    : Row(
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

              // Logout Button (Responsive: Icon button if compact, Outlined button if wide)
              Padding(
                padding: EdgeInsets.only(right: isCompactAppBar ? 8 : 16),
                child: isCompactAppBar
                    ? IconButton(
                        icon: const Icon(Icons.logout, size: 20, color: Colors.red),
                        tooltip: 'Sign Out',
                        onPressed: () {
                          setBrowserUrl('/login');
                          AuthState.instance.logout();
                        },
                      )
                    : OutlinedButton.icon(
                        icon: const Icon(Icons.logout, size: 16),
                        label: const Text('Sign Out'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          side: BorderSide(color: Colors.red.shade200),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onPressed: () {
                          setBrowserUrl('/login');
                          AuthState.instance.logout();
                        },
                      ),
              ),
            ],
          ),
          body: SelectionArea(
            child: isMobile
                ? screens[activeIndex]
                : Row(
                    children: [
                      // Role-Restricted Left Sidebar NavigationRail
                      NavigationRail(
                        selectedIndex: activeIndex,
                        onDestinationSelected: _onNavigateToTab,
                        labelType: NavigationRailLabelType.all,
                        backgroundColor: Colors.white,
                        minWidth: 84,
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
          ),
          bottomNavigationBar: isMobile
              ? NavigationBar(
                  selectedIndex: activeIndex,
                  onDestinationSelected: _onNavigateToTab,
                  height: 62,
                  elevation: 2,
                  backgroundColor: Colors.white,
                  destinations: destinations.map((d) {
                    final labelText = (d.label as Text).data ?? '';
                    return NavigationDestination(
                      icon: d.icon,
                      selectedIcon: d.selectedIcon,
                      label: labelText,
                    );
                  }).toList(),
                )
              : null,
        );
      },
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'SUPER_ADMIN': return Colors.purple;
      case 'ADMIN': return Colors.indigo;
      case 'MANAGER': return Colors.blue.shade700;
      case 'TEAM_LEAD': return Colors.teal.shade700;
      default: return Colors.teal;
    }
  }
}

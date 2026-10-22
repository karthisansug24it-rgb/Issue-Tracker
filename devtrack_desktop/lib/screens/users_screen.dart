import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/auth_state.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<UserModel> _users = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _roleFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  int _getRoleRank(String role) {
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

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await ApiService.instance.getUsers();
      // Order users order-wise: by Role Hierarchy (Super Admin -> Admin -> Manager -> Team Lead -> Employee), then Name
      users.sort((a, b) {
        final rankDiff = _getRoleRank(b.role).compareTo(_getRoleRank(a.role));
        if (rankDiff != 0) return rankDiff;
        return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
      });

      if (mounted) {
        setState(() {
          _users = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red.shade800, content: Text('Error loading users: $e')),
        );
      }
    }
  }

  // The server decides (same rules as the API): no self-changes, Super Admin manages
  // everyone, Admin manages up to Manager, Manager manages Team Leads and Employees.
  bool _canModifyUser(UserModel target) => target.canModify;

  Future<void> _showUpgradeRoleDialog(UserModel user) async {
    String selectedRole = user.role;

    // Full role hierarchy definitions
    final allRoles = [
      {
        'role': 'SUPER_ADMIN',
        'label': 'Super Admin',
        'desc': 'System-wide executive authority, global access, audit trails & security governance',
        'rank': 5,
      },
      {
        'role': 'ADMIN',
        'label': 'Organization Admin',
        'desc': 'Department & team administration, project controls, organization-wide user management',
        'rank': 4,
      },
      {
        'role': 'MANAGER',
        'label': 'Engineering / Dept Manager',
        'desc': 'Manages team scopes, allocates managers & leads, project-level oversight',
        'rank': 3,
      },
      {
        'role': 'TEAM_LEAD',
        'label': 'Technical Team Lead',
        'desc': 'Guides sprint delivery, assigns developer tasks, conducts bug reviews & approvals',
        'rank': 2,
      },
      {
        'role': 'EMPLOYEE',
        'label': 'Employee / Developer / QA',
        'desc': 'Executes assigned issues, submits work comments, updates progress & logs time',
        'rank': 1,
      },
    ];

    // Filter roles according to logged-in user hierarchy
    // RULE: If Manager is assigning, NEVER show Super Admin or Admin!
    final allowedRoles = allRoles.where((r) {
      final rank = r['rank'] as int;
      if (AuthState.instance.isSuperAdmin) return true;
      if (AuthState.instance.isAdmin) {
        // Admin can assign Manager, Team Lead, Employee (Admins are managed by Super Admins)
        return rank <= 3;
      }
      if (AuthState.instance.isManager) {
        // Manager can ONLY assign Team Lead and Employee (NO Super Admin, Admin, Manager)
        return rank <= 2;
      }
      return false;
    }).toList();

    // If current user's role is not in the allowed list, default to lowest permitted
    if (!allowedRoles.any((r) => r['role'] == selectedRole)) {
      selectedRole = allowedRoles.last['role'] as String;
    }

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _getRoleColor(user.role),
                    radius: 18,
                    child: Text(
                      user.fullName.isNotEmpty ? user.fullName[0] : 'U',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Assign / Upgrade Role', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                        Text('${user.fullName} (${user.email})', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.shield_outlined, size: 16, color: Colors.blue.shade800),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                AuthState.instance.isSuperAdmin
                                    ? 'Super Admin Scope: You can assign any role, including Admin and Super Admin.'
                                    : AuthState.instance.isAdmin
                                        ? 'Admin Scope: You can assign Manager, Team Lead and Employee roles.'
                                        : 'Manager Scope: You can assign Team Lead and Employee roles only.',
                                style: TextStyle(fontSize: 11, color: Colors.blue.shade900, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text('Select New Role Level (Order-wise Hierarchy):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 10),
                      ...allowedRoles.map((r) {
                        final roleCode = r['role'] as String;
                        final isSelected = selectedRole == roleCode;
                        final isCurrent = user.role == roleCode;

                        return InkWell(
                          onTap: () {
                            setDialogState(() => selectedRole = roleCode);
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? _getRoleColor(roleCode).withValues(alpha: 0.08) : Colors.white,
                              border: Border.all(
                                color: isSelected ? _getRoleColor(roleCode) : Colors.grey.shade300,
                                width: isSelected ? 1.5 : 1.0,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                  color: isSelected ? _getRoleColor(roleCode) : Colors.grey.shade500,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(r['label'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          const SizedBox(width: 8),
                                          Chip(
                                            label: Text(roleCode, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                            backgroundColor: _getRoleColor(roleCode).withValues(alpha: 0.15),
                                            padding: EdgeInsets.zero,
                                            visualDensity: VisualDensity.compact,
                                          ),
                                          if (isCurrent) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade200,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text('Current', style: TextStyle(fontSize: 9, color: Colors.grey)),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(r['desc'] as String, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E40AF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: selectedRole == user.role
                      ? null
                      : () async {
                          Navigator.pop(dialogCtx);
                          await _performUpgradeRole(user, selectedRole);
                        },
                  child: const Text('Confirm Role Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _performUpgradeRole(UserModel user, String newRole) async {
    try {
      final updated = await ApiService.instance.updateUserRole(user.id, newRole);
      setState(() {
        final index = _users.indexWhere((u) => u.id == user.id);
        if (index != -1) {
          _users[index] = updated;
        }
        // Re-sort order-wise
        _users.sort((a, b) {
          final rankDiff = _getRoleRank(b.role).compareTo(_getRoleRank(a.role));
          if (rankDiff != 0) return rankDiff;
          return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
        });
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade800,
            content: Text('${user.fullName} role successfully updated to $newRole!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade800,
            content: Text('Failed to update role: $e'),
          ),
        );
      }
    }
  }

  bool canToggleStatus(UserModel u) =>
      u.canModify && AuthState.instance.hasPermission('USER_STATUS_MANAGE');

  Future<void> _confirmToggleStatus(UserModel user) async {
    final disabling = user.active;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(disabling ? 'Disable account?' : 'Enable account?'),
        content: Text(disabling
            ? '${user.fullName} will be signed out and will not be able to sign in until re-enabled.'
            : '${user.fullName} will be able to sign in again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: disabling ? Colors.red.shade700 : Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(disabling ? 'Disable' : 'Enable'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final updated = await ApiService.instance.toggleUserStatus(user.id);
      if (!mounted) return;
      setState(() {
        final index = _users.indexWhere((u) => u.id == user.id);
        if (index != -1) _users[index] = updated;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.green.shade800,
        content: Text('${user.fullName} is now ${updated.active ? 'enabled' : 'disabled'}.'),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.red.shade800,
        content: Text('Failed to change account status: $e'),
      ));
    }
  }

  List<UserModel> get _filteredUsers {
    return _users.where((u) {
      if (_roleFilter != 'ALL' && u.role != _roleFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesName = u.fullName.toLowerCase().contains(q);
        final matchesEmail = u.email.toLowerCase().contains(q);
        final matchesDept = u.department.toLowerCase().contains(q);
        final matchesJob = u.jobTitle.toLowerCase().contains(q);
        if (!matchesName && !matchesEmail && !matchesDept && !matchesJob) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredUsers;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 650;
        final horizontalPadding = isCompact ? 12.0 : 24.0;

        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          body: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Responsive Header
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Users & Hierarchy Management',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Hierarchical permissions: Super Admin ➔ Admin ➔ Manager ➔ Team Lead ➔ Employee',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Reload Users',
                      onPressed: _loadUsers,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Responsive Search and Filter Bar
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: isCompact
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                decoration: InputDecoration(
                                  hintText: 'Search by name, email, department...',
                                  prefixIcon: const Icon(Icons.search, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  isDense: true,
                                ),
                                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _roleFilter,
                                    isExpanded: true,
                                    items: const [
                                      DropdownMenuItem(value: 'ALL', child: Text('All Roles', style: TextStyle(fontSize: 13))),
                                      DropdownMenuItem(value: 'SUPER_ADMIN', child: Text('Super Admin', style: TextStyle(fontSize: 13))),
                                      DropdownMenuItem(value: 'ADMIN', child: Text('Admin', style: TextStyle(fontSize: 13))),
                                      DropdownMenuItem(value: 'MANAGER', child: Text('Manager', style: TextStyle(fontSize: 13))),
                                      DropdownMenuItem(value: 'TEAM_LEAD', child: Text('Team Lead', style: TextStyle(fontSize: 13))),
                                      DropdownMenuItem(value: 'EMPLOYEE', child: Text('Employee', style: TextStyle(fontSize: 13))),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) setState(() => _roleFilter = val);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  decoration: InputDecoration(
                                    hintText: 'Search by name, email, department, or job title...',
                                    prefixIcon: const Icon(Icons.search, size: 20),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    isDense: true,
                                  ),
                                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _roleFilter,
                                    items: const [
                                      DropdownMenuItem(value: 'ALL', child: Text('All Roles', style: TextStyle(fontSize: 13))),
                                      DropdownMenuItem(value: 'SUPER_ADMIN', child: Text('Super Admin', style: TextStyle(fontSize: 13))),
                                      DropdownMenuItem(value: 'ADMIN', child: Text('Admin', style: TextStyle(fontSize: 13))),
                                      DropdownMenuItem(value: 'MANAGER', child: Text('Manager', style: TextStyle(fontSize: 13))),
                                      DropdownMenuItem(value: 'TEAM_LEAD', child: Text('Team Lead', style: TextStyle(fontSize: 13))),
                                      DropdownMenuItem(value: 'EMPLOYEE', child: Text('Employee', style: TextStyle(fontSize: 13))),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) setState(() => _roleFilter = val);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 14),

                // Users List
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : filtered.isEmpty
                          ? Center(
                              child: Text('No users found matching criteria.', style: TextStyle(color: Colors.grey.shade600)),
                            )
                          : Card(
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                              child: ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (context, _) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final u = filtered[index];
                                  final canModify = _canModifyUser(u);

                                  return ListTile(
                                    contentPadding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 16, vertical: 4),
                                    leading: CircleAvatar(
                                      backgroundColor: _getRoleColor(u.role),
                                      child: Text(
                                        u.fullName.isNotEmpty ? u.fullName[0] : 'U',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    title: Wrap(
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: [
                                        Text(
                                          u.fullName,
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        Chip(
                                          label: Text(
                                            _formatRoleLabel(u.role),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: _getRoleColor(u.role),
                                            ),
                                          ),
                                          backgroundColor: _getRoleColor(u.role).withValues(alpha: 0.12),
                                          side: BorderSide(color: _getRoleColor(u.role).withValues(alpha: 0.4)),
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                        ),
                                      ],
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        '${u.email} · Dept: ${u.department.isNotEmpty ? u.department : "General"} · ${u.jobTitle}',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (canModify) ...[
                                          if (isCompact)
                                            IconButton(
                                              icon: Icon(Icons.manage_accounts, color: _getRoleColor(u.role)),
                                              tooltip: 'Change Role',
                                              onPressed: () => _showUpgradeRoleDialog(u),
                                            )
                                          else
                                            OutlinedButton.icon(
                                              icon: const Icon(Icons.manage_accounts, size: 16),
                                              label: const Text('Change Role', style: TextStyle(fontSize: 12)),
                                              style: OutlinedButton.styleFrom(
                                                visualDensity: VisualDensity.compact,
                                                foregroundColor: _getRoleColor(u.role),
                                                side: BorderSide(color: _getRoleColor(u.role).withValues(alpha: 0.5)),
                                              ),
                                              onPressed: () => _showUpgradeRoleDialog(u),
                                            ),
                                          const SizedBox(width: 8),
                                        ],
                                        Tooltip(
                                          message: canToggleStatus(u)
                                              ? (u.active ? 'Click to disable this account' : 'Click to enable this account')
                                              : '',
                                          child: InkWell(
                                            onTap: canToggleStatus(u) ? () => _confirmToggleStatus(u) : null,
                                            borderRadius: BorderRadius.circular(4),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: u.active ? Colors.green.shade50 : Colors.grey.shade100,
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: u.active ? Colors.green.shade300 : Colors.grey.shade400),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    u.active ? 'Active' : 'Disabled',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                      color: u.active ? Colors.green.shade800 : Colors.grey.shade700,
                                                    ),
                                                  ),
                                                  if (canToggleStatus(u)) ...[
                                                    const SizedBox(width: 4),
                                                    Icon(Icons.power_settings_new, size: 12,
                                                        color: u.active ? Colors.green.shade800 : Colors.grey.shade700),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatRoleLabel(String role) {
    switch (role) {
      case 'SUPER_ADMIN':
        return 'SUPER ADMIN';
      case 'ADMIN':
        return 'ADMIN';
      case 'MANAGER':
        return 'MANAGER';
      case 'TEAM_LEAD':
        return 'TEAM LEAD';
      case 'EMPLOYEE':
        return 'EMPLOYEE';
      default:
        return role;
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'SUPER_ADMIN':
        return const Color(0xFF991B1B); // Crimson Red
      case 'ADMIN':
        return const Color(0xFF6B21A8); // Purple
      case 'MANAGER':
        return const Color(0xFF1E40AF); // Blue
      case 'TEAM_LEAD':
        return const Color(0xFF0F766E); // Teal
      case 'EMPLOYEE':
      default:
        return const Color(0xFF475569); // Slate Grey
    }
  }
}

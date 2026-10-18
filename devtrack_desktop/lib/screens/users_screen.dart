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

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final users = await ApiService.instance.getUsers();
    if (mounted) {
      setState(() {
        _users = users;
        _isLoading = false;
      });
    }
  }

  Future<void> _showUpgradeRoleDialog(UserModel user) async {
    String selectedRole = user.role;

    final roles = [
      {'role': 'EMPLOYEE', 'label': 'Employee (Basic User)', 'desc': 'Work on assigned issues, submit comments & time logs'},
      {'role': 'MANAGER', 'label': 'Manager', 'desc': 'Create issues, assign work items, review bug resolutions'},
      {'role': 'ADMIN', 'label': 'Admin', 'desc': 'Manage projects, departments, teams, and user accounts'},
      {'role': 'SUPER_ADMIN', 'label': 'Super Admin', 'desc': 'Global system access, administrative controls, and audit trails'},
    ];

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _getRoleColor(user.role),
                    radius: 16,
                    child: Text(
                      user.fullName.isNotEmpty ? user.fullName[0] : 'U',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Upgrade / Change Role', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                        Text('${user.fullName} (${user.email})', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select New Role Level:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 10),
                    ...roles.map((r) {
                      final isSelected = selectedRole == r['role'];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? _getRoleColor(r['role']!).withValues(alpha: 0.08) : Colors.transparent,
                          border: Border.all(
                            color: isSelected ? _getRoleColor(r['role']!) : Colors.grey.shade300,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: RadioListTile<String>(
                          value: r['role']!,
                          groupValue: selectedRole,
                          title: Row(
                            children: [
                              Text(r['label']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(width: 8),
                              Chip(
                                label: Text(r['role']!, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                backgroundColor: _getRoleColor(r['role']!).withValues(alpha: 0.15),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                          subtitle: Text(r['desc']!, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedRole = val);
                            }
                          },
                        ),
                      );
                    }),
                  ],
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
                  ),
                  onPressed: selectedRole == user.role
                      ? null
                      : () async {
                          Navigator.pop(dialogCtx);
                          await _performUpgradeRole(user, selectedRole);
                        },
                  child: const Text('Confirm Role Upgrade'),
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
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade800,
            content: Text('${user.fullName} successfully upgraded to $newRole!'),
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

  @override
  Widget build(BuildContext context) {
    final canUpgradeRole = AuthState.instance.isAdmin;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Users & Role Hierarchy', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      'Manage user accounts and upgrade permission hierarchy (Employee ➔ Manager ➔ Admin ➔ Super Admin)',
                      style: TextStyle(color: Colors.grey.shade600),
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
            const SizedBox(height: 24),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: ListView.separated(
                        itemCount: _users.length,
                        separatorBuilder: (context, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final u = _users[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getRoleColor(u.role),
                              child: Text(
                                u.fullName.isNotEmpty ? u.fullName[0] : 'U',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    u.fullName,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Chip(
                                  label: Text(u.role, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                  backgroundColor: _getRoleColor(u.role).withValues(alpha: 0.1),
                                  side: BorderSide(color: _getRoleColor(u.role).withValues(alpha: 0.5)),
                                ),
                              ],
                            ),
                            subtitle: Text('${u.email} · Dept: ${u.department} · ${u.jobTitle}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (canUpgradeRole) ...[
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.upgrade, size: 16),
                                    label: const Text('Upgrade Role', style: TextStyle(fontSize: 12)),
                                    style: OutlinedButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      foregroundColor: _getRoleColor(u.role),
                                      side: BorderSide(color: _getRoleColor(u.role).withValues(alpha: 0.5)),
                                    ),
                                    onPressed: () => _showUpgradeRoleDialog(u),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                Switch(
                                  value: u.active,
                                  onChanged: (val) {
                                    setState(() {
                                      _users[index] = UserModel(
                                        id: u.id,
                                        fullName: u.fullName,
                                        email: u.email,
                                        role: u.role,
                                        department: u.department,
                                        jobTitle: u.jobTitle,
                                        active: val,
                                      );
                                    });
                                  },
                                ),
                                Text(
                                  u.active ? 'Active' : 'Disabled',
                                  style: TextStyle(fontSize: 12, color: u.active ? Colors.green : Colors.grey),
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
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'SUPER_ADMIN':
        return Colors.purple;
      case 'ADMIN':
        return Colors.indigo;
      case 'MANAGER':
        return Colors.blue.shade700;
      default:
        return Colors.teal;
    }
  }
}

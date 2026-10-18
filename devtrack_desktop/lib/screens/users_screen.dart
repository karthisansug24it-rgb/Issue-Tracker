import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Users & Role Hierarchy', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Manage system accounts, access levels, and department designations', style: TextStyle(color: Colors.grey.shade600)),
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
                                Text(u.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                                Text(u.active ? 'Active' : 'Disabled', style: TextStyle(fontSize: 12, color: u.active ? Colors.green : Colors.grey)),
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
      case 'SUPER_ADMIN': return Colors.purple;
      case 'ADMIN': return Colors.indigo;
      case 'MANAGER': return Colors.blue.shade700;
      default: return Colors.teal;
    }
  }
}

import 'package:flutter/material.dart';
import '../models/department_model.dart';
import '../models/team_model.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/auth_state.dart';
import '../utils/clipboard_helper.dart';

class TeamsScreen extends StatefulWidget { 
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  List<DepartmentModel> _departments = [];
  List<TeamModel> _teams = [];
  List<UserModel> _users = [];
  bool _isLoading = true;

  int? _selectedDepartmentId;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _managerFilter = 'ALL'; // 'ALL', 'ASSIGNED', 'UNASSIGNED'
  String _activeTab = 'GROUPS'; // 'GROUPS' or 'DEPARTMENTS' when screen < 900px

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final depts = await ApiService.instance.getDepartments();
      final teams = await ApiService.instance.getTeams();
      final users = await ApiService.instance.getUsers();

      if (!mounted) return;

      setState(() {
        _departments = depts;
        _teams = teams;
        _users = users;
        _isLoading = false;

        // If the logged-in user is an Admin (not Super Admin) and hasn't selected a dept yet,
        // scope by their department
        final currentUser = AuthState.instance.currentUser;
        // Match on the real department id; if the user has none, show everything
        // instead of silently picking an unrelated department.
        if (_selectedDepartmentId == null && currentUser != null && !AuthState.instance.isSuperAdmin) {
          final deptId = currentUser.departmentId;
          if (deptId != null && _departments.any((d) => d.id == deptId)) {
            _selectedDepartmentId = deptId;
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red.shade800, content: Text('Error loading organization data: $e')),
      );
    }
  }

  // Mirrors the server rules: admins manage every team, managers only the teams they manage.
  bool get _canCreateTeam => AuthState.instance.isManager;

  bool _canManageTeam(TeamModel team) {
    final me = AuthState.instance.currentUser;
    if (me == null) return false;
    if (AuthState.instance.isAdmin) return true;
    return me.role == 'MANAGER' && team.managerId == me.id;
  }

  List<TeamModel> get _filteredTeams {
    return _teams.where((t) {
      // 1. Department Filter
      if (_selectedDepartmentId != null && t.departmentId != _selectedDepartmentId) {
        return false;
      }

      // 2. Manager Assignment Filter
      if (_managerFilter == 'ASSIGNED' && (t.managerId == null || t.managerId == 0)) {
        return false;
      }
      if (_managerFilter == 'UNASSIGNED' && t.managerId != null && t.managerId != 0) {
        return false;
      }

      // 3. Search Query Filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesName = t.name.toLowerCase().contains(q);
        final matchesDesc = (t.description ?? '').toLowerCase().contains(q);
        final matchesManager = (t.managerName ?? '').toLowerCase().contains(q);
        final matchesLead = (t.teamLeadName ?? '').toLowerCase().contains(q);
        final matchesDept = (t.departmentName ?? '').toLowerCase().contains(q);
        final matchesMembers = t.members.any((m) => m.fullName.toLowerCase().contains(q));
        if (!matchesName && !matchesDesc && !matchesManager && !matchesLead && !matchesDept && !matchesMembers) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  // 1. Create or Edit Team Dialog
  Future<void> _showTeamDialog({TeamModel? team, int? defaultDeptId}) async {
    final isEditing = team != null;
    final nameController = TextEditingController(text: team?.name ?? '');
    final descController = TextEditingController(text: team?.description ?? '');

    int selectedDeptId = team?.departmentId ??
        defaultDeptId ??
        _selectedDepartmentId ??
        (_departments.isNotEmpty ? _departments.first.id : 1);
    final me = AuthState.instance.currentUser!;
    final canChangeManager = AuthState.instance.isAdmin;
    // Managers create teams they manage themselves
    int? selectedManagerId = team?.managerId ?? (canChangeManager ? null : me.id);
    int? selectedTeamLeadId = team?.teamLeadId;

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (sbCtx, setDialogState) {
            final activeUsers = _users.where((u) => u.active).toList();

            // Manager candidates: MANAGER, ADMIN, SUPER_ADMIN
            // If current logged-in user is a MANAGER (not ADMIN/SUPER_ADMIN), filter out SUPER_ADMIN & ADMIN
            final managerCandidates = activeUsers.where((u) {
              if (!canChangeManager) {
                return u.id == selectedManagerId; // fixed: only admins can change a team's manager
              }
              return u.role == 'MANAGER' || u.role == 'ADMIN' || u.role == 'SUPER_ADMIN';
            }).toList();

            // Team Lead candidates: TEAM_LEAD, EMPLOYEE, or MANAGER
            // Team leads must hold the Team Lead (or Manager) role; promote employees first
            final leadCandidates = activeUsers.where((u) {
              return u.role == 'TEAM_LEAD' || u.role == 'MANAGER';
            }).toList();

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Row(
                children: [
                  Icon(isEditing ? Icons.edit_note : Icons.group_add, color: const Color(0xFF1E40AF)),
                  const SizedBox(width: 8),
                  Text(
                    isEditing ? 'Edit Team / Group' : 'Create Team / Group',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Team Name
                      const Text('Team / Group Name *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          hintText: 'e.g. Core Frontend Group, DevOps & Infra',
                          suffixIcon: ClipboardHelper.buildPasteOrClearSuffix(
                            controller: nameController,
                            setState: setDialogState,
                            context: context,
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Department Selection
                      Row(
                        children: [
                          const Text('Department *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(width: 6),
                          Text(
                            '(Department-scoped group)',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        initialValue: _departments.any((d) => d.id == selectedDeptId)
                            ? selectedDeptId
                            : (_departments.isNotEmpty ? _departments.first.id : null),
                        isExpanded: true,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                        items: _departments.map((d) {
                          return DropdownMenuItem<int>(
                            value: d.id,
                            child: Row(
                              children: [
                                Chip(
                                  label: Text(d.code, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                  backgroundColor: Colors.blue.shade50,
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                ),
                                const SizedBox(width: 8),
                                Text(d.name, style: const TextStyle(fontSize: 13)),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedDeptId = val);
                        },
                      ),
                      const SizedBox(height: 16),

                      // 1. Assign Manager
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text('1. Assign Manager', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.blue.shade200),
                                ),
                                child: Text('Department Oversight', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                              ),
                            ],
                          ),
                          if (selectedManagerId != null && canChangeManager)
                            TextButton(
                              style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                              onPressed: () => setDialogState(() => selectedManagerId = null),
                              child: const Text('Clear', style: TextStyle(fontSize: 12, color: Colors.red)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int?>(
                        initialValue: managerCandidates.any((u) => u.id == selectedManagerId) ? selectedManagerId : null,
                        isExpanded: true,
                        hint: const Text('Select Manager (Oversight & Resources)', style: TextStyle(fontSize: 13)),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Unassigned (Assign later)', style: TextStyle(fontSize: 13, color: Colors.grey)),
                          ),
                          ...managerCandidates.map((u) {
                            return DropdownMenuItem<int?>(
                              value: u.id,
                              child: Row(
                                children: [
                                  Text(u.fullName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 8),
                                  Chip(
                                    label: Text(u.role, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: Colors.blue.shade100,
                                  ),
                                  const SizedBox(width: 6),
                                  Text('· ${u.department}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                ],
                              ),
                            );
                          }),
                        ],
                        onChanged: !canChangeManager ? null : (val) {
                          setDialogState(() => selectedManagerId = val);
                        },
                      ),
                      const SizedBox(height: 16),

                      // 2. Assign Team Lead
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text('2. Assign Team Lead', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.teal.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.teal.shade200),
                                ),
                                child: Text('Technical Lead & Triage', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.teal.shade900)),
                              ),
                            ],
                          ),
                          if (selectedTeamLeadId != null)
                            TextButton(
                              style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                              onPressed: () => setDialogState(() => selectedTeamLeadId = null),
                              child: const Text('Clear', style: TextStyle(fontSize: 12, color: Colors.red)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int?>(
                        initialValue: leadCandidates.any((u) => u.id == selectedTeamLeadId) ? selectedTeamLeadId : null,
                        isExpanded: true,
                        hint: const Text('Select Team Lead (Sprint guide & Reviews)', style: TextStyle(fontSize: 13)),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Unassigned (Assign later)', style: TextStyle(fontSize: 13, color: Colors.grey)),
                          ),
                          ...leadCandidates.map((u) {
                            return DropdownMenuItem<int?>(
                              value: u.id,
                              child: Row(
                                children: [
                                  Text(u.fullName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 8),
                                  Chip(
                                    label: Text(u.role, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: Colors.teal.shade100,
                                  ),
                                  const SizedBox(width: 6),
                                  Text('· ${u.jobTitle}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                ],
                              ),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setDialogState(() => selectedTeamLeadId = val);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Description
                      const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: descController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Key responsibilities, technical area, deliverables for this group',
                          suffixIcon: ClipboardHelper.buildPasteOrClearSuffix(
                            controller: descController,
                            setState: setDialogState,
                            context: context,
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                      ),
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
                  ),
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a team name')),
                      );
                      return;
                    }
                    Navigator.pop(dialogCtx);
                    try {
                      if (isEditing) {
                        await ApiService.instance.updateTeam(
                          team.id,
                          name: name,
                          departmentId: selectedDeptId,
                          description: descController.text.trim(),
                          managerId: selectedManagerId,
                          teamLeadId: selectedTeamLeadId,
                          active: team.active,
                        );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(backgroundColor: Colors.green.shade800, content: Text('Team "$name" updated successfully!')),
                        );
                      } else {
                        await ApiService.instance.createTeam(
                          name: name,
                          departmentId: selectedDeptId,
                          description: descController.text.trim(),
                          managerId: selectedManagerId,
                          teamLeadId: selectedTeamLeadId,
                        );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(backgroundColor: Colors.green.shade800, content: Text('Team "$name" created successfully!')),
                        );
                      }
                      _loadData();
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(backgroundColor: Colors.red.shade800, content: Text('Error saving team: $e')),
                      );
                    }
                  },
                  child: Text(isEditing ? 'Save Changes' : 'Create Team'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 2a. Quick Assign/Change Manager Dialog
  Future<void> _showQuickAssignManagerDialog(TeamModel team) async {
    final activeUsers = _users.where((u) => u.active).toList();
    int? selectedManagerId = team.managerId;

    final managerCandidates = activeUsers.where((u) {
      if (AuthState.instance.isManager && !AuthState.instance.isAdmin) {
        return u.role == 'MANAGER';
      }
      return u.role == 'MANAGER' || u.role == 'ADMIN' || u.role == 'SUPER_ADMIN';
    }).toList();

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (sbCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Row(
                children: [
                  const Icon(Icons.manage_accounts, color: Color(0xFF1E40AF)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Assign Department Manager', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                        Text('Group: ${team.name}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select a Manager to oversee resource allocation, deliverables, and alignment for this team.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int?>(
                      initialValue: managerCandidates.any((u) => u.id == selectedManagerId) ? selectedManagerId : null,
                      isExpanded: true,
                      hint: const Text('Select Manager', style: TextStyle(fontSize: 13)),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Unassigned (No manager)', style: TextStyle(fontSize: 13, color: Colors.red)),
                        ),
                        ...managerCandidates.map((u) {
                          return DropdownMenuItem<int?>(
                            value: u.id,
                            child: Row(
                              children: [
                                Text(u.fullName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 6),
                                Chip(
                                  label: Text(u.role, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: Colors.blue.shade100,
                                ),
                                const SizedBox(width: 6),
                                Text('· ${u.department}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                              ],
                            ),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setDialogState(() => selectedManagerId = val);
                      },
                    ),
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
                  ),
                  onPressed: () async {
                    Navigator.pop(dialogCtx);
                    try {
                      await ApiService.instance.updateTeam(
                        team.id,
                        name: team.name,
                        departmentId: team.departmentId ?? (_departments.isNotEmpty ? _departments.first.id : 1),
                        description: team.description,
                        managerId: selectedManagerId,
                        teamLeadId: team.teamLeadId,
                        active: team.active,
                      );
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: Colors.green.shade800,
                          content: Text(
                            selectedManagerId == null
                                ? 'Manager unassigned for "${team.name}"'
                                : 'Manager assigned successfully for "${team.name}"!',
                          ),
                        ),
                      );
                      _loadData();
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(backgroundColor: Colors.red.shade800, content: Text('Error updating manager: $e')),
                      );
                    }
                  },
                  child: const Text('Confirm Assignment'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 2b. Quick Assign/Change Team Lead Dialog
  Future<void> _showQuickAssignLeadDialog(TeamModel team) async {
    final activeUsers = _users.where((u) => u.active).toList();
    int? selectedLeadId = team.teamLeadId;

    final leadCandidates = activeUsers.where((u) {
      return u.role == 'TEAM_LEAD' || u.role == 'MANAGER';
    }).toList();

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (sbCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Row(
                children: [
                  const Icon(Icons.engineering, color: Color(0xFF0F766E)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Assign Technical Team Lead', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                        Text('Group: ${team.name}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select a Technical Team Lead to guide day-to-day sprint progress, issue triage, and reviews.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int?>(
                      initialValue: leadCandidates.any((u) => u.id == selectedLeadId) ? selectedLeadId : null,
                      isExpanded: true,
                      hint: const Text('Select Team Lead', style: TextStyle(fontSize: 13)),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Unassigned (No lead)', style: TextStyle(fontSize: 13, color: Colors.red)),
                        ),
                        ...leadCandidates.map((u) {
                          return DropdownMenuItem<int?>(
                            value: u.id,
                            child: Row(
                              children: [
                                Text(u.fullName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                const SizedBox(width: 6),
                                Chip(
                                  label: Text(u.role, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: Colors.teal.shade100,
                                ),
                                const SizedBox(width: 6),
                                Text('· ${u.jobTitle}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                              ],
                            ),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setDialogState(() => selectedLeadId = val);
                      },
                    ),
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
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    Navigator.pop(dialogCtx);
                    try {
                      await ApiService.instance.updateTeam(
                        team.id,
                        name: team.name,
                        departmentId: team.departmentId ?? (_departments.isNotEmpty ? _departments.first.id : 1),
                        description: team.description,
                        managerId: team.managerId,
                        teamLeadId: selectedLeadId,
                        active: team.active,
                      );
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: Colors.teal.shade800,
                          content: Text(
                            selectedLeadId == null
                                ? 'Team Lead unassigned for "${team.name}"'
                                : 'Team Lead assigned successfully for "${team.name}"!',
                          ),
                        ),
                      );
                      _loadData();
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(backgroundColor: Colors.red.shade800, content: Text('Error updating team lead: $e')),
                      );
                    }
                  },
                  child: const Text('Confirm Assignment'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 3. Manage Team Members Dialog
  Future<void> _showManageMembersDialog(TeamModel team) async {
    final canManage = _canManageTeam(team);
    int? userToAddId; // kept outside the builder so the selection survives rebuilds
    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (sbCtx, setDialogState) {
            final currentMemberIds = team.members.map((m) => m.id).toSet();
            final availableUsers = _users.where((u) => u.active && !currentMemberIds.contains(u.id)).toList();
            if (userToAddId == null || !availableUsers.any((u) => u.id == userToAddId)) {
              userToAddId = availableUsers.isNotEmpty ? availableUsers.first.id : null;
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Row(
                children: [
                  const Icon(Icons.people_outline, color: Color(0xFF1E40AF)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Group Members: ${team.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                        Text('Department: ${team.departmentName ?? "General"}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 540,
                height: 480,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Add Member Box (only for people who manage this team)
                    if (canManage) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: userToAddId,
                              isExpanded: true,
                              hint: const Text('Select user to add to group', style: TextStyle(fontSize: 13)),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                isDense: true,
                                fillColor: Colors.white,
                                filled: true,
                              ),
                              items: availableUsers.map((u) {
                                return DropdownMenuItem<int>(
                                  value: u.id,
                                  child: Text('${u.fullName} (${u.role}) · ${u.department}', style: const TextStyle(fontSize: 12)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setDialogState(() => userToAddId = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.person_add, size: 16),
                            label: const Text('Add'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E40AF),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                            onPressed: userToAddId == null
                                ? null
                                : () async {
                                    Navigator.pop(dialogCtx);
                                    try {
                                      await ApiService.instance.addTeamMember(team.id, userToAddId!);
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(backgroundColor: Colors.green, content: Text('Member added successfully!')),
                                      );
                                      _loadData();
                                    } catch (e) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(backgroundColor: Colors.red.shade800, content: Text('Error adding member: $e')),
                                      );
                                    }
                                  },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ],

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Current Group Roster:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('${team.members.length} members', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    team.members.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Text('No members assigned to this group yet.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                            ),
                          )
                        : Expanded(
                            child: ListView.separated(
                              itemCount: team.members.length,
                              separatorBuilder: (context, _) => const Divider(height: 1),
                              itemBuilder: (itemCtx, idx) {
                                final member = team.members[idx];
                                final isLead = member.id == team.teamLeadId;
                                // Manager and lead must be changed on the team before removal
                                final canRemove = canManage && member.id != team.managerId && !isLead;

                                return ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    radius: 14,
                                    backgroundColor: isLead ? Colors.indigo : Colors.grey.shade400,
                                    child: Text(
                                      member.fullName.isNotEmpty ? member.fullName[0] : 'U',
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Text(member.fullName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                      const SizedBox(width: 6),
                                      if (isLead)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.indigo.shade50,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.indigo.shade200),
                                          ),
                                          child: const Text('TEAM LEAD / MGR', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.indigo)),
                                        ),
                                    ],
                                  ),
                                  subtitle: Text('${member.email} · ${member.jobTitle}', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                                  trailing: !canRemove ? null : IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                                    tooltip: 'Remove from group',
                                    onPressed: () async {
                                      Navigator.pop(dialogCtx);
                                      try {
                                        await ApiService.instance.removeTeamMember(team.id, member.id);
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Removed ${member.fullName} from group')),
                                        );
                                        _loadData();
                                      } catch (e) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(backgroundColor: Colors.red.shade800, content: Text('Error removing member: $e')),
                                        );
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 4. Create or Edit Department Dialog
  Future<void> _showDepartmentDialog({DepartmentModel? dept}) async {
    final isEditing = dept != null;
    final nameController = TextEditingController(text: dept?.name ?? '');
    final codeController = TextEditingController(text: dept?.code ?? '');
    final descController = TextEditingController(text: dept?.description ?? '');

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (sbCtx, setDeptState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text(isEditing ? 'Edit Department' : 'Create Department', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Department Name *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Mobile Engineering, Product Design',
                        suffixIcon: ClipboardHelper.buildPasteOrClearSuffix(
                          controller: nameController,
                          setState: setDeptState,
                          context: context,
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text('Department Code * (Unique)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: codeController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        hintText: 'e.g. MOB, DES, OPS',
                        suffixIcon: ClipboardHelper.buildPasteOrClearSuffix(
                          controller: codeController,
                          setState: setDeptState,
                          context: context,
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Department mission and functional scope',
                        suffixIcon: ClipboardHelper.buildPasteOrClearSuffix(
                          controller: descController,
                          setState: setDeptState,
                          context: context,
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                    ),
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
              ),
              onPressed: () async {
                final name = nameController.text.trim();
                final code = codeController.text.trim().toUpperCase();
                if (name.isEmpty || code.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Name and Code are required')),
                  );
                  return;
                }
                Navigator.pop(dialogCtx);
                try {
                  if (isEditing) {
                    await ApiService.instance.updateDepartment(
                      dept.id,
                      name: name,
                      code: code,
                      description: descController.text.trim(),
                      active: dept.active,
                    );
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(backgroundColor: Colors.green.shade800, content: Text('Department "$name" updated successfully!')),
                    );
                  } else {
                    await ApiService.instance.createDepartment(
                      name: name,
                      code: code,
                      description: descController.text.trim(),
                    );
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(backgroundColor: Colors.green.shade800, content: Text('Department "$name" created successfully!')),
                    );
                  }
                  _loadData();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(backgroundColor: Colors.red.shade800, content: Text('Error saving department: $e')),
                  );
                }
              },
              child: Text(isEditing ? 'Save Changes' : 'Create Department'),
            ),
          ],
        );
      },
    );
  },
);
}

  // 5. Delete Department Dialog
  Future<void> _deleteDepartment(DepartmentModel dept) async {
    final teamsInDept = _teams.where((t) => t.departmentId == dept.id).toList();
    if (teamsInDept.isNotEmpty) {
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Cannot Delete Department'),
          content: Text(
            'The department "${dept.name}" contains ${teamsInDept.length} team(s). Please reassign or delete these teams before deleting this department.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Department'),
        content: Text('Are you sure you want to delete the department "${dept.name}" (${dept.code})? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.instance.deleteDepartment(dept.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.green.shade800, content: Text('Department "${dept.name}" deleted.')),
        );
        if (_selectedDepartmentId == dept.id) {
          _selectedDepartmentId = null;
        }
        _loadData();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red.shade800, content: Text('Error deleting department: $e')),
        );
      }
    }
  }

  // 6. Delete Team Dialog
  Future<void> _deleteTeam(TeamModel team) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Team / Group'),
        content: Text('Are you sure you want to delete "${team.name}"? This will remove all member assignments.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.instance.deleteTeam(team.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.green.shade800, content: Text('Team "${team.name}" deleted successfully.')),
        );
        _loadData();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red.shade800, content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdminOrSuper = AuthState.instance.isAdmin;
    final currentUser = AuthState.instance.currentUser;
    final isScopedAdmin = !AuthState.instance.isSuperAdmin && currentUser != null && currentUser.department.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 900;
          final isMobile = constraints.maxWidth < 600;
          final isNarrow = constraints.maxWidth < 420;
          final horizontalPadding = isNarrow ? 12.0 : (isMobile ? 16.0 : 24.0);

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Bar: Title & Primary Actions
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            const Text('Departments & Groups', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                            if (isScopedAdmin)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.blue.shade300),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.shield_outlined, size: 14, color: Colors.blue.shade900),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Admin Scope: ${currentUser.department}',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage organizational departments, create working groups, and assign team managers (Real PostgreSQL Data)',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Reload from Database',
                          onPressed: _loadData,
                        ),
                        if (isAdminOrSuper)
                          OutlinedButton.icon(
                            icon: const Icon(Icons.domain_add, size: 16),
                            label: Text(isMobile ? 'Dept' : 'Add Department'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1E40AF),
                              padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 12, vertical: 12),
                            ),
                            onPressed: () => _showDepartmentDialog(),
                          ),
                        if (_canCreateTeam)
                          ElevatedButton.icon(
                            icon: const Icon(Icons.group_add, size: 16),
                            label: Text(isMobile ? 'Group' : 'Create Team / Group'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E40AF),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 14, vertical: 12),
                            ),
                            onPressed: () => _showTeamDialog(),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Search Bar & Manager Assignment Filter
                if (constraints.maxWidth >= 720)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search groups by name, description, department, or manager...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: ClipboardHelper.buildPasteOrClearSuffix(
                              controller: _searchController,
                              setState: setState,
                              context: context,
                              onChanged: () => setState(() => _searchQuery = _searchController.text.trim()),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            isDense: true,
                            fillColor: Colors.white,
                            filled: true,
                          ),
                          onChanged: (val) {
                            setState(() => _searchQuery = val.trim());
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'ALL', label: Text('All Groups')),
                          ButtonSegment(value: 'ASSIGNED', label: Text('With Manager')),
                          ButtonSegment(value: 'UNASSIGNED', label: Text('Needs Manager')),
                        ],
                        selected: {_managerFilter},
                        onSelectionChanged: (newSelection) {
                          setState(() => _managerFilter = newSelection.first);
                        },
                      ),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search groups...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: ClipboardHelper.buildPasteOrClearSuffix(
                            controller: _searchController,
                            setState: setState,
                            context: context,
                            onChanged: () => setState(() => _searchQuery = _searchController.text.trim()),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                          fillColor: Colors.white,
                          filled: true,
                        ),
                        onChanged: (val) {
                          setState(() => _searchQuery = val.trim());
                        },
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'ALL', label: Text('All Groups')),
                            ButtonSegment(value: 'ASSIGNED', label: Text('With Manager')),
                            ButtonSegment(value: 'UNASSIGNED', label: Text('Needs Manager')),
                          ],
                          selected: {_managerFilter},
                          onSelectionChanged: (newSelection) {
                            setState(() => _managerFilter = newSelection.first);
                          },
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 14),

                // Department Choice Chips Bar
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: Text('All Departments (${_teams.length} groups)'),
                        selected: _selectedDepartmentId == null,
                        onSelected: (val) {
                          if (val) setState(() => _selectedDepartmentId = null);
                        },
                      ),
                      const SizedBox(width: 8),
                      ..._departments.map((d) {
                        final isSelected = _selectedDepartmentId == d.id;
                        final teamCount = _teams.where((t) => t.departmentId == d.id).length;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            avatar: CircleAvatar(
                              radius: 10,
                              backgroundColor: isSelected ? Colors.white : Colors.indigo.shade100,
                              child: Text(
                                d.code.isNotEmpty ? d.code[0] : 'D',
                                style: TextStyle(fontSize: 10, color: isSelected ? Colors.indigo : Colors.black87, fontWeight: FontWeight.bold),
                              ),
                            ),
                            label: Text('${d.name} (${d.code}) · $teamCount'),
                            selected: isSelected,
                            onSelected: (val) {
                              setState(() => _selectedDepartmentId = val ? d.id : null);
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Compact view toggle: [ Groups | Departments ]
                if (isCompact) ...[
                  Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<String>(
                          segments: [
                            ButtonSegment(
                              value: 'GROUPS',
                              label: Text('Groups (${_filteredTeams.length})'),
                              icon: const Icon(Icons.groups, size: 16),
                            ),
                            ButtonSegment(
                              value: 'DEPARTMENTS',
                              label: Text('Departments (${_departments.length})'),
                              icon: const Icon(Icons.apartment, size: 16),
                            ),
                          ],
                          selected: {_activeTab},
                          onSelectionChanged: (set) => setState(() => _activeTab = set.first),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // Main Content Area
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : isCompact
                          ? (_activeTab == 'DEPARTMENTS'
                              ? _buildDepartmentsCard(isAdminOrSuper)
                              : _buildGroupsCard(isAdminOrSuper, isMobile))
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 290,
                                  child: _buildDepartmentsCard(isAdminOrSuper),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildGroupsCard(isAdminOrSuper, isMobile),
                                ),
                              ],
                            ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDepartmentsCard(bool isAdminOrSuper) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Departments', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Chip(
                  label: Text('${_departments.length} total', style: const TextStyle(fontSize: 11)),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: _departments.length,
                separatorBuilder: (context, _) => const Divider(height: 1),
                itemBuilder: (context, idx) {
                  final dept = _departments[idx];
                  final isSelected = _selectedDepartmentId == dept.id;
                  final teamCount = _teams.where((t) => t.departmentId == dept.id).length;

                  return ListTile(
                    selected: isSelected,
                    selectedTileColor: Colors.blue.shade50,
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    title: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        Text(
                          dept.name,
                          style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, fontSize: 13),
                        ),
                        Chip(
                          label: Text(dept.code, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          backgroundColor: Colors.grey.shade200,
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    subtitle: Text('$teamCount active groups', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                    trailing: isAdminOrSuper
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 16),
                                tooltip: 'Edit Department',
                                onPressed: () => _showDepartmentDialog(dept: dept),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                tooltip: 'Delete Department',
                                onPressed: () => _deleteDepartment(dept),
                              ),
                            ],
                          )
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedDepartmentId = dept.id;
                        _activeTab = 'GROUPS';
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupsCard(bool isAdminOrSuper, bool isMobile) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  _selectedDepartmentId == null
                      ? 'All Organizational Groups (${_filteredTeams.length})'
                      : 'Groups in ${_departments.firstWhere((d) => d.id == _selectedDepartmentId, orElse: () => DepartmentModel(id: 0, name: 'Selected Dept', code: '')).name} (${_filteredTeams.length})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (_canCreateTeam)
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(
                      _selectedDepartmentId != null ? 'Create Group in this Department' : 'Create Group',
                    ),
                    onPressed: () => _showTeamDialog(defaultDeptId: _selectedDepartmentId),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _filteredTeams.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.group_off_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No groups match your search "$_searchQuery"'
                                : (_managerFilter == 'UNASSIGNED'
                                    ? 'Great! All groups have managers assigned.'
                                    : 'No groups found in this selection.'),
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 12),
                          if (_canCreateTeam)
                            ElevatedButton.icon(
                              icon: const Icon(Icons.group_add, size: 16),
                              label: const Text('Create New Group / Team'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E40AF),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => _showTeamDialog(defaultDeptId: _selectedDepartmentId),
                            ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _filteredTeams.length,
                      separatorBuilder: (context, _) => const Divider(height: 1),
                      itemBuilder: (itemCtx, index) {
                        final team = _filteredTeams[index];
                        final memberCount = team.members.length;
                        final hasManager = team.teamLeadId != null && team.teamLeadId != 0;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: hasManager ? Colors.indigo.shade700 : Colors.amber.shade800,
                            child: Icon(
                              hasManager ? Icons.groups : Icons.group_add,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          title: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Text(team.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 13, color: Colors.grey),
                                tooltip: 'Copy group name',
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.only(left: 4),
                                constraints: const BoxConstraints(),
                                onPressed: () => ClipboardHelper.copy(context, team.name, label: 'Group Name'),
                              ),
                              Chip(
                                label: Text(team.departmentName ?? 'General', style: const TextStyle(fontSize: 10)),
                                backgroundColor: Colors.blue.shade50,
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                              if (!team.active) ...[
                                Chip(
                                  label: const Text('INACTIVE', style: TextStyle(fontSize: 9, color: Colors.red)),
                                  backgroundColor: Colors.red.shade50,
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 1. Manager Row
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 4,
                                  runSpacing: 2,
                                  children: [
                                    Icon(
                                      team.managerId != null ? Icons.manage_accounts : Icons.warning_amber_rounded,
                                      size: 14,
                                      color: team.managerId != null ? const Color(0xFF1E40AF) : Colors.amber.shade900,
                                    ),
                                    const Text(
                                      'Manager: ',
                                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF1E293B)),
                                    ),
                                    Text(
                                      team.managerName ?? 'Unassigned',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: team.managerId != null ? const Color(0xFF1E40AF) : Colors.red.shade700,
                                      ),
                                    ),
                                    if (team.managerName != null)
                                      IconButton(
                                        icon: const Icon(Icons.copy, size: 12, color: Colors.grey),
                                        tooltip: 'Copy manager name',
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.only(left: 4),
                                        constraints: const BoxConstraints(),
                                        onPressed: () => ClipboardHelper.copy(context, team.managerName!, label: 'Manager'),
                                      ),
                                    if (isAdminOrSuper)
                                      InkWell(
                                        onTap: () => _showQuickAssignManagerDialog(team),
                                        borderRadius: BorderRadius.circular(4),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: team.managerId != null ? Colors.blue.shade50 : Colors.amber.shade50,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: team.managerId != null ? Colors.blue.shade300 : Colors.amber.shade400,
                                            ),
                                          ),
                                          child: Text(
                                            team.managerId != null ? 'Change' : '+ Assign Manager',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: team.managerId != null ? const Color(0xFF1E40AF) : Colors.amber.shade900,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),

                                // 2. Team Lead Row
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 4,
                                  runSpacing: 2,
                                  children: [
                                    Icon(
                                      team.teamLeadId != null ? Icons.engineering : Icons.info_outline,
                                      size: 14,
                                      color: team.teamLeadId != null ? const Color(0xFF0F766E) : Colors.grey.shade600,
                                    ),
                                    const Text(
                                      'Team Lead: ',
                                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF1E293B)),
                                    ),
                                    Text(
                                      team.teamLeadName ?? 'Unassigned',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: team.teamLeadId != null ? const Color(0xFF0F766E) : Colors.grey.shade600,
                                      ),
                                    ),
                                    if (team.teamLeadName != null)
                                      IconButton(
                                        icon: const Icon(Icons.copy, size: 12, color: Colors.grey),
                                        tooltip: 'Copy lead name',
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.only(left: 4),
                                        constraints: const BoxConstraints(),
                                        onPressed: () => ClipboardHelper.copy(context, team.teamLeadName!, label: 'Team Lead'),
                                      ),
                                    if (_canManageTeam(team))
                                      InkWell(
                                        onTap: () => _showQuickAssignLeadDialog(team),
                                        borderRadius: BorderRadius.circular(4),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: team.teamLeadId != null ? Colors.teal.shade50 : Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: team.teamLeadId != null ? Colors.teal.shade300 : Colors.grey.shade300,
                                            ),
                                          ),
                                          child: Text(
                                            team.teamLeadId != null ? 'Change' : '+ Assign Lead',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: team.teamLeadId != null ? const Color(0xFF0F766E) : Colors.grey.shade700,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),

                                // 3. Description & Active Members
                                Text(
                                  '${team.description ?? "No description provided"} · $memberCount active member(s)',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                          trailing: isMobile
                              ? Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 2,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.people_alt_outlined, size: 18),
                                      tooltip: 'Members ($memberCount)',
                                      onPressed: () => _showManageMembersDialog(team),
                                    ),
                                    if (_canManageTeam(team))
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF1E40AF)),
                                        tooltip: 'Edit Group',
                                        onPressed: () => _showTeamDialog(team: team),
                                      ),
                                    if (isAdminOrSuper)
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                        tooltip: 'Delete Group',
                                        onPressed: () => _deleteTeam(team),
                                      ),
                                  ],
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.people_alt_outlined, size: 14),
                                      label: Text('Members ($memberCount)', style: const TextStyle(fontSize: 12)),
                                      style: OutlinedButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      ),
                                      onPressed: () => _showManageMembersDialog(team),
                                    ),
                                    const SizedBox(width: 8),
                                    if (_canManageTeam(team))
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF1E40AF)),
                                        tooltip: 'Edit Group & Details',
                                        onPressed: () => _showTeamDialog(team: team),
                                      ),
                                    if (isAdminOrSuper)
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                        tooltip: 'Delete Group',
                                        onPressed: () => _deleteTeam(team),
                                      ),
                                  ],
                                ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../models/project_member_model.dart';
import '../models/project_model.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/auth_state.dart';

const _projectRoles = ['PROJECT_MANAGER', 'TECH_LEAD', 'DEVELOPER', 'TESTER', 'DESIGNER', 'OBSERVER'];

class ProjectsScreen extends StatefulWidget {
  final Function(int) onNavigateToTab;

  const ProjectsScreen({super.key, required this.onNavigateToTab});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  List<ProjectModel> _projects = [];
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadProjects();
    AuthState.instance.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    AuthState.instance.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (AuthState.instance.isLoggedIn) _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final projects = await ApiService.instance.getProjects();
      if (!mounted) return;
      setState(() {
        _projects = projects;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = e.toString();
      });
    }
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: error ? Colors.red.shade800 : Colors.green.shade800,
      content: Text(message),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = AuthState.instance.hasPermission('PROJECT_CREATE');

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 560;
          final horizontalPadding = isMobile ? 12.0 : 24.0;

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Projects', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Manage project scopes, members, and issue progress', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      ],
                    ),
                    if (canCreate)
                      ElevatedButton.icon(
                        onPressed: _showCreateProjectDialog,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('New Project'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo.shade700,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 18, vertical: 12),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // Projects Grid / List
                Expanded(child: _buildBody()),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 8),
            Text(_loadError!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: _loadProjects, icon: const Icon(Icons.refresh), label: const Text('Retry')),
          ],
        ),
      );
    }
    if (_projects.isEmpty) {
      return Center(
        child: Text(
          'You are not a member of any project yet.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 450,
        mainAxisExtent: 240,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _projects.length,
      itemBuilder: (context, index) {
        final proj = _projects[index];
        final progress = proj.totalIssues > 0 ? (proj.totalIssues - proj.openIssues) / proj.totalIssues : 0.0;

        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.indigo.shade200),
                      ),
                      child: Text(
                        proj.projectKey,
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo.shade900),
                      ),
                    ),
                    Chip(
                      label: Text(proj.status, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      backgroundColor: Colors.green.shade50,
                      side: BorderSide(color: Colors.green.shade200),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  proj.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Text(
                    proj.description,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text('Owner: ${proj.ownerName}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    Text('${proj.openIssues} unresolved / ${proj.totalIssues} total', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey.shade200,
                  color: Colors.indigo.shade600,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (proj.canManage || AuthState.instance.isAdmin || AuthState.instance.hasPermission('PROJECT_CREATE'))
                      IconButton(
                        style: IconButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                        tooltip: 'Permanently delete project',
                        onPressed: () => _confirmDeleteProject(proj),
                      )
                    else
                      const SizedBox.shrink(),
                    TextButton.icon(
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      icon: Icon(proj.canManage ? Icons.manage_accounts : Icons.people_outline, size: 16),
                      label: Text(proj.canManage ? 'Manage Members' : 'Members'),
                      onPressed: () => _showMembersDialog(proj),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteProject(ProjectModel project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Project Permanently?'),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete "${project.name}" (${project.projectKey})?\n\n'
          'This will permanently delete the project and all its associated issues, comments, time logs, and member mappings from the database. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiService.instance.deleteProject(project.id);
        _snack('Project ${project.projectKey} deleted permanently');
        _loadProjects();
      } catch (e) {
        _snack(e.toString(), error: true);
      }
    }
  }

  // --------------------------------------------------------------- members

  Future<void> _showMembersDialog(ProjectModel project) async {
    List<ProjectMemberModel> members;
    List<UserModel> directory = [];
    try {
      members = await ApiService.instance.getProjectMembers(project.id);
      if (project.canManage && AuthState.instance.hasPermission('USER_DIRECTORY_VIEW')) {
        directory = (await ApiService.instance.getUsers()).where((u) => u.active).toList();
      }
    } catch (e) {
      _snack(e.toString(), error: true);
      return;
    }

    int? userToAdd;
    String roleToAdd = 'DEVELOPER';
    bool busy = false;
    bool changed = false;

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final memberIds = members.map((m) => m.id).toSet();
            final candidates = directory.where((u) => !memberIds.contains(u.id)).toList();
            if (userToAdd != null && !candidates.any((u) => u.id == userToAdd)) userToAdd = null;

            Future<void> run(Future<void> Function() action) async {
              setDialogState(() => busy = true);
              try {
                await action();
                members = await ApiService.instance.getProjectMembers(project.id);
                changed = true;
              } catch (e) {
                _snack(e.toString(), error: true);
              } finally {
                if (dialogCtx.mounted) setDialogState(() => busy = false);
              }
            }

            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.people_outline, color: Color(0xFF1E40AF)),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${project.projectKey} · Members', style: const TextStyle(fontWeight: FontWeight.bold))),
                  if (busy) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
              content: SizedBox(
                width: 560,
                height: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      if (project.canManage && directory.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<int>(
                                  initialValue: userToAdd,
                                  isExpanded: true,
                                  hint: const Text('Add a person', style: TextStyle(fontSize: 13)),
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  items: candidates
                                      .map((u) => DropdownMenuItem(
                                            value: u.id,
                                            child: Text('${u.fullName} (${u.role})', style: const TextStyle(fontSize: 12)),
                                          ))
                                      .toList(),
                                  onChanged: (v) => setDialogState(() => userToAdd = v),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  initialValue: roleToAdd,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  items: _projectRoles
                                      .map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 11))))
                                      .toList(),
                                  onChanged: (v) => setDialogState(() => roleToAdd = v ?? 'DEVELOPER'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: busy || userToAdd == null
                                    ? null
                                    : () => run(() => ApiService.instance.addProjectMember(project.id, userToAdd!, roleToAdd)),
                                child: const Text('Add'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Text('${members.length} member(s)', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      const SizedBox(height: 6),
                      Expanded(
                        child: ListView.separated(
                          itemCount: members.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final m = members[i];
                            final editable = project.canManage && !m.owner;
                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 14,
                                backgroundColor: m.owner ? Colors.indigo : Colors.grey.shade400,
                                child: Text(m.fullName.isNotEmpty ? m.fullName[0] : '?',
                                    style: const TextStyle(color: Colors.white, fontSize: 11)),
                              ),
                              title: Text(
                                m.owner ? '${m.fullName} (owner)' : m.fullName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: m.active ? null : Colors.grey,
                                ),
                              ),
                              subtitle: Text('${m.role} · ${m.jobTitle}${m.active ? '' : ' · disabled'}',
                                  style: const TextStyle(fontSize: 11)),
                              trailing: !editable
                                  ? Text(m.projectRole, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        DropdownButton<String>(
                                          value: m.projectRole,
                                          isDense: true,
                                          underline: const SizedBox(),
                                          items: _projectRoles
                                              .map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 11))))
                                              .toList(),
                                          onChanged: busy
                                              ? null
                                              : (r) {
                                                  if (r == null || r == m.projectRole) return;
                                                  run(() => ApiService.instance.addProjectMember(project.id, m.id, r));
                                                },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                          tooltip: 'Permanently remove member from project',
                                          onPressed: busy
                                              ? null
                                              : () async {
                                                  final confirm = await showDialog<bool>(
                                                    context: dialogCtx,
                                                    builder: (c) => AlertDialog(
                                                      title: const Text('Remove Project Member?'),
                                                      content: Text('Are you sure you want to permanently remove "${m.fullName}" from project ${project.projectKey}?'),
                                                      actions: [
                                                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                                        ElevatedButton(
                                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
                                                          onPressed: () => Navigator.pop(c, true),
                                                          child: const Text('Remove Member'),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                  if (confirm == true) {
                                                    run(() => ApiService.instance.removeProjectMember(project.id, m.id));
                                                  }
                                                },
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
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Close')),
              ],
            );
          },
        );
      },
    );
    if (changed) _loadProjects();
  }

  // ---------------------------------------------------------- create project

  void _showCreateProjectDialog() {
    String key = '';
    String name = '';
    String desc = '';
    bool saving = false;
    String? error;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create New Project'),
              content: SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Project Key (2-10 letters/digits, e.g. CRM, MOB)', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        maxLength: 10,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, counterText: ''),
                        onChanged: (v) => key = v,
                      ),
                      const SizedBox(height: 14),
                      const Text('Project Name', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        maxLength: 150,
                        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, counterText: ''),
                        onChanged: (v) => name = v,
                      ),
                      const SizedBox(height: 14),
                      const Text('Description', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        maxLines: 3,
                        maxLength: 2000,
                        decoration: const InputDecoration(border: OutlineInputBorder(), counterText: ''),
                        onChanged: (v) => desc = v,
                      ),
                      const SizedBox(height: 8),
                      Text('You will be the project owner. Add members after creating it.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      if (error != null) ...[
                        const SizedBox(height: 8),
                        Text(error!, style: TextStyle(color: Colors.red.shade800)),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (key.trim().isEmpty || name.trim().isEmpty) {
                            setDialogState(() => error = 'Key and name are required.');
                            return;
                          }
                          setDialogState(() {
                            saving = true;
                            error = null;
                          });
                          try {
                            await ApiService.instance.createProject(key, name, desc);
                            if (dialogContext.mounted) Navigator.pop(dialogContext);
                            _snack('Project ${key.trim().toUpperCase()} created.');
                            _loadProjects();
                          } catch (e) {
                            setDialogState(() {
                              saving = false;
                              error = e.toString();
                            });
                          }
                        },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

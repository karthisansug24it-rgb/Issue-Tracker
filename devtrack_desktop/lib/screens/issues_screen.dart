import 'package:flutter/material.dart';
import '../models/comment_model.dart';
import '../models/issue_activity_model.dart';
import '../models/issue_model.dart';
import '../models/project_member_model.dart';
import '../models/project_model.dart';
import '../services/api_service.dart';
import '../services/auth_state.dart';
import '../utils/clipboard_helper.dart';

const _allStatuses = ['OPEN', 'ASSIGNED', 'IN_PROGRESS', 'BLOCKED', 'IN_REVIEW', 'RESOLVED', 'CLOSED', 'REOPENED'];

class IssuesScreen extends StatefulWidget {
  const IssuesScreen({super.key});

  @override
  State<IssuesScreen> createState() => _IssuesScreenState();
}

class _IssuesScreenState extends State<IssuesScreen> {
  List<IssueModel> _issues = [];
  List<ProjectModel> _projects = [];
  bool _isLoading = true;
  String? _loadError;

  String _searchQuery = '';
  String _selectedStatus = 'ALL';
  String _selectedPriority = 'ALL';
  int? _selectedProjectId;

  @override
  void initState() {
    super.initState();
    _loadData();
    AuthState.instance.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    AuthState.instance.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (AuthState.instance.isLoggedIn) _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final projects = await ApiService.instance.getProjects();
      final issues = await ApiService.instance.getIssues(
        projectId: _selectedProjectId,
        status: _selectedStatus == 'ALL' ? null : _selectedStatus,
        priority: _selectedPriority == 'ALL' ? null : _selectedPriority,
      );
      if (!mounted) return;
      setState(() {
        _projects = projects;
        _issues = issues;
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

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: Colors.red.shade800, content: Text(e.toString())),
    );
  }

  List<IssueModel> get _filteredIssues {
    if (_searchQuery.trim().isEmpty) return _issues;
    final q = _searchQuery.toLowerCase();
    return _issues.where((i) =>
        i.title.toLowerCase().contains(q) ||
        i.issueKey.toLowerCase().contains(q) ||
        (i.assigneeName != null && i.assigneeName!.toLowerCase().contains(q))
    ).toList();
  }

  // ------------------------------------------------------------------ filters

  Widget _searchField() {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Search by issue key, title, assignee...',
        prefixIcon: const Icon(Icons.search, size: 20),
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      onChanged: (val) => setState(() => _searchQuery = val),
    );
  }

  List<Widget> _filterDropdowns() {
    return [
      DropdownButton<int?>(
        value: _projects.any((p) => p.id == _selectedProjectId) ? _selectedProjectId : null,
        hint: const Text('All Projects'),
        underline: const SizedBox(),
        items: [
          const DropdownMenuItem(value: null, child: Text('All Projects')),
          ..._projects.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))),
        ],
        onChanged: (val) {
          setState(() => _selectedProjectId = val);
          _loadData();
        },
      ),
      const SizedBox(width: 16),
      DropdownButton<String>(
        value: _selectedStatus,
        underline: const SizedBox(),
        items: [
          const DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
          ..._allStatuses.map((s) => DropdownMenuItem(value: s, child: Text(s.replaceAll('_', ' ')))),
        ],
        onChanged: (val) {
          setState(() => _selectedStatus = val!);
          _loadData();
        },
      ),
      const SizedBox(width: 16),
      DropdownButton<String>(
        value: _selectedPriority,
        underline: const SizedBox(),
        items: const [
          DropdownMenuItem(value: 'ALL', child: Text('All Priorities')),
          DropdownMenuItem(value: 'CRITICAL', child: Text('CRITICAL')),
          DropdownMenuItem(value: 'HIGH', child: Text('HIGH')),
          DropdownMenuItem(value: 'MEDIUM', child: Text('MEDIUM')),
          DropdownMenuItem(value: 'LOW', child: Text('LOW')),
        ],
        onChanged: (val) {
          setState(() => _selectedPriority = val!);
          _loadData();
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 820;
          final isMobile = constraints.maxWidth < 560;
          final horizontalPadding = isMobile ? 12.0 : (isCompact ? 16.0 : 24.0);

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Action Row
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Issues & Work Items', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          AuthState.instance.isAdmin
                              ? 'Track bugs, features, and tasks across all projects'
                              : 'Track bugs, features, and tasks in your projects',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ],
                    ),
                    if (AuthState.instance.hasPermission('ISSUE_CREATE'))
                      ElevatedButton.icon(
                        onPressed: _projects.isEmpty ? null : _showCreateIssueDialog,
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(isMobile ? 'New Issue' : 'New Issue / Bug'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 18, vertical: 12),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Filter Bar
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: isCompact
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _searchField(),
                              const SizedBox(height: 10),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(children: _filterDropdowns()),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(flex: 2, child: _searchField()),
                              const SizedBox(width: 16),
                              ..._filterDropdowns(),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Issues List / Table
                Expanded(child: _buildIssueList(isMobile)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildIssueList(bool isMobile) {
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
            Text(_loadError!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: _loadData, icon: const Icon(Icons.refresh), label: const Text('Retry')),
          ],
        ),
      );
    }
    if (_filteredIssues.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              _projects.isEmpty
                  ? 'You are not a member of any project yet. Ask a manager to add you.'
                  : 'No issues match current filter',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ListView.separated(
        itemCount: _filteredIssues.length,
        separatorBuilder: (context, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final issue = _filteredIssues[index];
          final isBug = issue.type == 'BUG';
          return ListTile(
            leading: Tooltip(
              message: 'Click to copy ${issue.issueKey}',
              child: InkWell(
                onTap: () => ClipboardHelper.copy(context, issue.issueKey, label: 'Issue Key'),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isBug ? Colors.red.shade50 : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: isBug ? Colors.red.shade200 : Colors.blue.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        issue.issueKey,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isBug ? Colors.red.shade900 : Colors.blue.shade900,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.copy, size: 10, color: isBug ? Colors.red.shade700 : Colors.blue.shade700),
                    ],
                  ),
                ),
              ),
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    issue.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text('(${issue.type})', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
            subtitle: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${issue.projectName} · ${issue.assigneeName ?? "Unassigned"}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _buildPriorityBadge(issue.priority),
                          _buildStatusBadge(issue.status),
                        ],
                      ),
                    ],
                  )
                : Text(
                    '${issue.projectName} · Assigned to: ${issue.assigneeName ?? "Unassigned"} · Due: ${issue.dueDate ?? "None"}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
            trailing: isMobile
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                        tooltip: 'Permanently delete issue',
                        onPressed: () => _confirmDeleteIssue(issue),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildPriorityBadge(issue.priority),
                      const SizedBox(width: 12),
                      _buildStatusBadge(issue.status),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                        tooltip: 'Permanently delete issue',
                        onPressed: () => _confirmDeleteIssue(issue),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
            onTap: () => _showIssueDetails(issue),
          );
        },
      ),
    );
  }

  Widget _buildPriorityBadge(String priority) {
    Color color;
    switch (priority) {
      case 'CRITICAL': color = Colors.red; break;
      case 'HIGH': color = Colors.orange.shade800; break;
      case 'MEDIUM': color = Colors.blue.shade700; break;
      default: color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(priority, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    switch (status) {
      case 'OPEN': bg = Colors.grey.shade200; fg = Colors.grey.shade800; break;
      case 'ASSIGNED': bg = Colors.blue.shade50; fg = Colors.blue.shade800; break;
      case 'IN_PROGRESS': bg = Colors.amber.shade50; fg = Colors.amber.shade900; break;
      case 'IN_REVIEW': bg = Colors.purple.shade50; fg = Colors.purple.shade800; break;
      case 'RESOLVED': bg = Colors.green.shade50; fg = Colors.green.shade800; break;
      case 'CLOSED': bg = Colors.grey.shade300; fg = Colors.grey.shade900; break;
      case 'REOPENED': bg = Colors.orange.shade50; fg = Colors.orange.shade900; break;
      case 'BLOCKED': bg = Colors.red.shade50; fg = Colors.red.shade800; break;
      default: bg = Colors.grey.shade100; fg = Colors.black87;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(status.replaceAll('_', ' '), style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Future<void> _confirmDeleteIssue(IssueModel issue, {VoidCallback? onCloseDialog}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Issue Permanently?'),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete issue "${issue.issueKey}: ${issue.title}"?\n\n'
          'This will permanently delete this issue and all its comments, activity history, and logged time entries from the database. This action cannot be undone.',
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
        await ApiService.instance.deleteIssue(issue.id);
        if (onCloseDialog != null) onCloseDialog();
        setState(() {
          _issues.removeWhere((i) => i.id == issue.id);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.green.shade800,
              content: Text('Issue ${issue.issueKey} deleted permanently'),
            ),
          );
        }
      } catch (e) {
        _showError(e);
      }
    }
  }

  // ------------------------------------------------------------ create issue

  void _showCreateIssueDialog() {
    if (_projects.isEmpty) return;
    final me = AuthState.instance.currentUser!;
    ProjectModel selectedProject = _projects.firstWhere(
      (p) => p.id == _selectedProjectId,
      orElse: () => _projects.first,
    );
    String title = '';
    String description = '';
    String type = 'BUG';
    String priority = 'MEDIUM';
    int? selectedAssigneeId; // default: unassigned
    DateTime? dueDate;
    List<ProjectMemberModel> members = [];
    bool loadingMembers = true;
    bool saving = false;
    String? error;

    Future<void> loadMembers(StateSetter setDialogState) async {
      setDialogState(() => loadingMembers = true);
      try {
        final result = await ApiService.instance.getProjectMembers(selectedProject.id);
        setDialogState(() {
          members = result.where((m) => m.active).toList();
          loadingMembers = false;
        });
      } catch (e) {
        setDialogState(() {
          members = [];
          loadingMembers = false;
        });
      }
    }

    bool started = false;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            if (!started) {
              started = true;
              loadMembers(setDialogState);
            }
            // Users who cannot assign may only pick themselves
            final assignable = selectedProject.canAssign
                ? members
                : members.where((m) => m.id == me.id).toList();

            return AlertDialog(
              title: const Text('Create New Issue / Bug'),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Project
                      const Text('Project', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        initialValue: selectedProject.id,
                        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                        items: _projects.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setDialogState(() {
                            selectedProject = _projects.firstWhere((p) => p.id == v);
                            selectedAssigneeId = null;
                          });
                          loadMembers(setDialogState);
                        },
                      ),
                      const SizedBox(height: 14),

                      // Title
                      const Text('Issue Title', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        maxLength: 200,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Login button not working',
                          border: OutlineInputBorder(),
                          isDense: true,
                          counterText: '',
                        ),
                        onChanged: (v) => title = v,
                      ),
                      const SizedBox(height: 14),

                      // Type & Priority
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Issue Type', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  initialValue: type,
                                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                                  items: const [
                                    DropdownMenuItem(value: 'BUG', child: Text('Bug')),
                                    DropdownMenuItem(value: 'TASK', child: Text('Task')),
                                    DropdownMenuItem(value: 'FEATURE', child: Text('Feature')),
                                    DropdownMenuItem(value: 'INCIDENT', child: Text('Incident')),
                                    DropdownMenuItem(value: 'SUPPORT_REQUEST', child: Text('Support Request')),
                                  ],
                                  onChanged: (v) => setDialogState(() => type = v!),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Priority', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  initialValue: priority,
                                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                                  items: const [
                                    DropdownMenuItem(value: 'CRITICAL', child: Text('Critical')),
                                    DropdownMenuItem(value: 'HIGH', child: Text('High')),
                                    DropdownMenuItem(value: 'MEDIUM', child: Text('Medium')),
                                    DropdownMenuItem(value: 'LOW', child: Text('Low')),
                                  ],
                                  onChanged: (v) => setDialogState(() => priority = v!),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Assignee & due date
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Assignee', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                loadingMembers
                                    ? const LinearProgressIndicator()
                                    : DropdownButtonFormField<int?>(
                                        key: ValueKey('assignee-${selectedProject.id}'),
                                        initialValue: selectedAssigneeId,
                                        isExpanded: true,
                                        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                                        items: [
                                          const DropdownMenuItem<int?>(value: null, child: Text('Unassigned')),
                                          ...assignable.map((m) => DropdownMenuItem<int?>(
                                                value: m.id,
                                                child: Text(m.id == me.id ? '${m.fullName} (me)' : '${m.fullName} · ${m.projectRole}',
                                                    overflow: TextOverflow.ellipsis),
                                              )),
                                        ],
                                        onChanged: (v) => setDialogState(() => selectedAssigneeId = v),
                                      ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Due Date', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.event, size: 16),
                                  label: Text(dueDate == null ? 'Not set' : _isoDate(dueDate!)),
                                  onPressed: () async {
                                    final now = DateTime.now();
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: dueDate ?? now.add(const Duration(days: 7)),
                                      firstDate: DateTime(now.year - 1),
                                      lastDate: DateTime(now.year + 5),
                                    );
                                    if (picked != null) setDialogState(() => dueDate = picked);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Description
                      const Text('Description / Steps to Reproduce', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        maxLines: 3,
                        maxLength: 5000,
                        decoration: const InputDecoration(
                          hintText: 'Enter details about the bug or task requirements...',
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                        onChanged: (v) => description = v,
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 10),
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
                          if (title.trim().isEmpty) {
                            setDialogState(() => error = 'Please enter a title.');
                            return;
                          }
                          setDialogState(() {
                            saving = true;
                            error = null;
                          });
                          try {
                            await ApiService.instance.createIssue(
                              projectId: selectedProject.id,
                              title: title,
                              description: description,
                              type: type,
                              priority: priority,
                              assigneeId: selectedAssigneeId,
                              dueDate: dueDate != null ? _isoDate(dueDate!) : null,
                            );
                            if (dialogContext.mounted) Navigator.pop(dialogContext);
                            _loadData();
                          } catch (e) {
                            setDialogState(() {
                              saving = false;
                              error = e.toString();
                            });
                          }
                        },
                  child: const Text('Create Issue'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ------------------------------------------------------------ issue details

  Future<void> _showIssueDetails(IssueModel summary) async {
    IssueModel issue;
    List<CommentModel> comments;
    List<IssueHistoryModel> history;
    List<TimeEntryModel> timeEntries;
    List<ProjectMemberModel> members = [];
    try {
      issue = await ApiService.instance.getIssue(summary.id);
      final results = await Future.wait([
        ApiService.instance.getComments(issue.id),
        ApiService.instance.getIssueHistory(issue.id),
        ApiService.instance.getTimeEntries(issue.id),
      ]);
      comments = results[0] as List<CommentModel>;
      history = results[1] as List<IssueHistoryModel>;
      timeEntries = results[2] as List<TimeEntryModel>;
      if (issue.canAssign) {
        members = (await ApiService.instance.getProjectMembers(issue.projectId)).where((m) => m.active).toList();
      }
    } catch (e) {
      _showError(e);
      return;
    }

    String commentText = '';
    final commentController = TextEditingController();
    bool busy = false;
    bool changed = false;

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDetailsState) {
            Future<void> run(Future<void> Function() action) async {
              setDetailsState(() => busy = true);
              try {
                await action();
                changed = true;
              } catch (e) {
                _showError(e);
              } finally {
                if (dialogContext.mounted) setDetailsState(() => busy = false);
              }
            }

            Future<void> refreshActivity() async {
              final h = await ApiService.instance.getIssueHistory(issue.id);
              final t = await ApiService.instance.getTimeEntries(issue.id);
              setDetailsState(() {
                history = h;
                timeEntries = t;
              });
            }

            final statusOptions = <String>[issue.status, ...issue.allowedTransitions];
            final assigneeOptions = members.any((m) => m.id == issue.assigneeId) || issue.assigneeId == null
                ? members
                : [
                    ProjectMemberModel(id: issue.assigneeId!, fullName: issue.assigneeName ?? 'Current assignee'),
                    ...members,
                  ];

            return AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Text(issue.issueKey, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            issue.title,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (busy) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    tooltip: 'Delete Issue Permanently',
                    onPressed: busy
                        ? null
                        : () => _confirmDeleteIssue(issue, onCloseDialog: () => Navigator.pop(dialogContext)),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(dialogContext)),
                ],
              ),
              content: SizedBox(
                width: 650,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status & Assignee Action Row (options come from the server's rules)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Status: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(width: 8),
                                issue.allowedTransitions.isEmpty
                                    ? Tooltip(
                                        message: 'You cannot change the status of this issue',
                                        child: _buildStatusBadge(issue.status),
                                      )
                                    : DropdownButton<String>(
                                        value: issue.status,
                                        isDense: true,
                                        items: statusOptions
                                            .map((s) => DropdownMenuItem(
                                                  value: s,
                                                  child: Text(s == issue.status
                                                      ? s.replaceAll('_', ' ')
                                                      : '→ ${s.replaceAll('_', ' ')}'),
                                                ))
                                            .toList(),
                                        onChanged: busy
                                            ? null
                                            : (newStatus) {
                                                if (newStatus == null || newStatus == issue.status) return;
                                                run(() async {
                                                  final updated = await ApiService.instance.updateIssueStatus(issue.id, newStatus);
                                                  setDetailsState(() => issue.applyFrom(updated));
                                                  await refreshActivity();
                                                });
                                              },
                                      ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Assignee: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(width: 8),
                                !issue.canAssign
                                    ? Text(issue.assigneeName ?? 'Unassigned')
                                    : DropdownButton<int?>(
                                        value: issue.assigneeId,
                                        hint: const Text('Unassigned'),
                                        isDense: true,
                                        items: [
                                          const DropdownMenuItem<int?>(value: null, child: Text('Unassigned')),
                                          ...assigneeOptions.map((m) => DropdownMenuItem<int?>(
                                                value: m.id,
                                                child: Text(m.fullName),
                                              )),
                                        ],
                                        onChanged: busy
                                            ? null
                                            : (newAssigneeId) {
                                                if (newAssigneeId == issue.assigneeId) return;
                                                run(() async {
                                                  final updated = await ApiService.instance.assignIssue(issue.id, newAssigneeId);
                                                  setDetailsState(() => issue.applyFrom(updated));
                                                  await refreshActivity();
                                                });
                                              },
                                      ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Details Grid
                      Wrap(
                        spacing: 16,
                        runSpacing: 12,
                        children: [
                          SizedBox(width: 120, child: _buildDetailItem('Project', issue.projectName)),
                          SizedBox(width: 120, child: _buildDetailItem('Priority', issue.priority)),
                          SizedBox(width: 120, child: _buildDetailItem('Reporter', issue.reporterName)),
                          SizedBox(width: 120, child: _buildDetailItem('Due Date', issue.dueDate ?? 'Not set')),
                          SizedBox(
                            width: 120,
                            child: _buildDetailItem('Time Logged',
                                '${_formatMinutes(issue.actualMinutes)} / ${_formatMinutes(issue.estimatedMinutes)}'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Description
                      const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          issue.description.isNotEmpty ? issue.description : 'No description provided.',
                          style: TextStyle(color: Colors.grey.shade800),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Time Logging
                      if (issue.canLogTime)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.timer, size: 16),
                          label: const Text('Log Work Time'),
                          onPressed: busy
                              ? null
                              : () async {
                                  final entry = await _askTimeEntry(dialogContext);
                                  if (entry == null) return;
                                  run(() async {
                                    await ApiService.instance.logTime(issue.id, entry.$1, description: entry.$2);
                                    setDetailsState(() => issue.actualMinutes += entry.$1);
                                    await refreshActivity();
                                  });
                                },
                        ),
                      if (timeEntries.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        ...timeEntries.take(10).map((t) {
                          final canDeleteTime = AuthState.instance.isAdmin ||
                              issue.canManage ||
                              t.userId == AuthState.instance.currentUser?.id;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${t.loggedAt} · ${t.userName} · ${_formatMinutes(t.durationMinutes)}'
                                    '${t.workDescription.isNotEmpty ? ' · ${t.workDescription}' : ''}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                  ),
                                ),
                                if (canDeleteTime)
                                  InkWell(
                                    borderRadius: BorderRadius.circular(4),
                                    onTap: busy
                                        ? null
                                        : () async {
                                            final confirm = await showDialog<bool>(
                                              context: dialogContext,
                                              builder: (c) => AlertDialog(
                                                title: const Text('Delete Time Entry?'),
                                                content: Text('Are you sure you want to permanently delete this logged time entry (${_formatMinutes(t.durationMinutes)})?'),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                                  ElevatedButton(
                                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
                                                    onPressed: () => Navigator.pop(c, true),
                                                    child: const Text('Delete Permanently'),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirm == true) {
                                              run(() async {
                                                await ApiService.instance.deleteTimeEntry(issue.id, t.id);
                                                setDetailsState(() {
                                                  issue.actualMinutes = (issue.actualMinutes - t.durationMinutes).clamp(0, 999999);
                                                  timeEntries.removeWhere((item) => item.id == t.id);
                                                });
                                                await refreshActivity();
                                              });
                                            }
                                          },
                                    child: const Padding(
                                      padding: EdgeInsets.all(2.0),
                                      child: Icon(Icons.delete_outline, size: 14, color: Colors.redAccent),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                      ],
                      const SizedBox(height: 20),

                      // Discussion / Comments
                      const Divider(),
                      const Text('Discussion', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),

                      if (comments.isEmpty)
                        Text('No comments yet.', style: TextStyle(color: Colors.grey.shade600))
                      else
                        ...comments.map((c) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.blueGrey.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(c.authorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(c.createdAt, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                                          if (AuthState.instance.isAdmin || issue.canManage || c.authorId == AuthState.instance.currentUser?.id) ...[
                                            const SizedBox(width: 4),
                                            InkWell(
                                              borderRadius: BorderRadius.circular(4),
                                              onTap: busy
                                                  ? null
                                                  : () async {
                                                      final confirm = await showDialog<bool>(
                                                        context: dialogContext,
                                                        builder: (c) => AlertDialog(
                                                          title: const Text('Delete Comment?'),
                                                          content: const Text('Are you sure you want to permanently delete this comment from the database?'),
                                                          actions: [
                                                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                                            ElevatedButton(
                                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
                                                              onPressed: () => Navigator.pop(c, true),
                                                              child: const Text('Delete Permanently'),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                      if (confirm == true) {
                                                        run(() async {
                                                          await ApiService.instance.deleteComment(issue.id, c.id);
                                                          setDetailsState(() => comments.removeWhere((item) => item.id == c.id));
                                                        });
                                                      }
                                                    },
                                              child: const Padding(
                                                padding: EdgeInsets.all(2.0),
                                                child: Icon(Icons.delete_outline, size: 14, color: Colors.redAccent),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(c.commentText),
                                ],
                              ),
                            )),

                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: commentController,
                              maxLength: 3000,
                              decoration: const InputDecoration(
                                hintText: 'Add a comment or work update...',
                                border: OutlineInputBorder(),
                                isDense: true,
                                counterText: '',
                              ),
                              onChanged: (v) => commentText = v,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: busy
                                ? null
                                : () {
                                    if (commentText.trim().isEmpty) return;
                                    run(() async {
                                      final newC = await ApiService.instance.addComment(issue.id, commentText.trim());
                                      setDetailsState(() {
                                        comments.add(newC);
                                        commentText = '';
                                        commentController.clear();
                                      });
                                    });
                                  },
                            child: const Text('Post'),
                          ),
                        ],
                      ),

                      // Activity history
                      if (history.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const Divider(),
                        const Text('Activity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        ...history.map((h) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.history, size: 14, color: Colors.grey.shade600),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '${h.changedAt} · ${h.actorName} ${_describeChange(h)}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    commentController.dispose();
    if (changed) _loadData();
  }

  String _describeChange(IssueHistoryModel h) {
    switch (h.fieldName) {
      case 'CREATED':
        return 'created the issue (${(h.newValue ?? '').replaceAll('_', ' ')})';
      case 'STATUS':
        return 'changed status ${(h.oldValue ?? '').replaceAll('_', ' ')} → ${(h.newValue ?? '').replaceAll('_', ' ')}';
      case 'ASSIGNEE':
        return 'reassigned ${h.oldValue ?? 'Unassigned'} → ${h.newValue ?? 'Unassigned'}';
      default:
        return 'changed ${h.fieldName.toLowerCase()} ${h.oldValue ?? ''} → ${h.newValue ?? ''}';
    }
  }

  static String _formatMinutes(int minutes) {
    if (minutes <= 0) return '0m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  /// Asks for a duration and description. Returns (minutes, description) or null.
  Future<(int, String)?> _askTimeEntry(BuildContext parentContext) {
    int hours = 0;
    int minutes = 30;
    String description = '';
    return showDialog<(int, String)>(
      context: parentContext,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            final total = hours * 60 + minutes;
            return AlertDialog(
              title: const Text('Log Work Time'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: hours,
                          decoration: const InputDecoration(labelText: 'Hours', border: OutlineInputBorder(), isDense: true),
                          items: List.generate(13, (i) => DropdownMenuItem(value: i, child: Text('$i h'))),
                          onChanged: (v) => setState(() => hours = v ?? 0),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: minutes,
                          decoration: const InputDecoration(labelText: 'Minutes', border: OutlineInputBorder(), isDense: true),
                          items: const [0, 15, 30, 45]
                              .map((m) => DropdownMenuItem(value: m, child: Text('$m min')))
                              .toList(),
                          onChanged: (v) => setState(() => minutes = v ?? 0),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    maxLength: 255,
                    decoration: const InputDecoration(
                      labelText: 'What did you work on?',
                      border: OutlineInputBorder(),
                      isDense: true,
                      counterText: '',
                    ),
                    onChanged: (v) => description = v,
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: total <= 0 ? null : () => Navigator.pop(ctx, (total, description.trim())),
                  child: Text('Log ${_formatMinutes(total)}'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}

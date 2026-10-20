import 'package:flutter/material.dart';
import '../models/issue_model.dart';
import '../models/project_model.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/auth_state.dart';
import '../utils/clipboard_helper.dart';

class IssuesScreen extends StatefulWidget {
  const IssuesScreen({super.key});

  @override
  State<IssuesScreen> createState() => _IssuesScreenState();
}

class _IssuesScreenState extends State<IssuesScreen> {
  List<IssueModel> _issues = [];
  List<ProjectModel> _projects = [];
  List<UserModel> _users = [];
  bool _isLoading = true;

  String _searchQuery = '';
  String _selectedStatus = 'ALL';
  String _selectedPriority = 'ALL';
  int? _selectedProjectId;

  @override
  void initState() {
    super.initState();
    _loadData();
    AuthState.instance.addListener(_loadData);
  }

  @override
  void dispose() {
    AuthState.instance.removeListener(_loadData);
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final projects = await ApiService.instance.getProjects();
      final issues = await ApiService.instance.getIssues(
        projectId: _selectedProjectId,
        status: _selectedStatus == 'ALL' ? null : _selectedStatus,
        priority: _selectedPriority == 'ALL' ? null : _selectedPriority,
      );
      final users = await ApiService.instance.getUsers();
      if (mounted) {
        setState(() {
          _projects = projects;
          _issues = issues;
          _users = users;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
                        Text('Track bugs, features, and tasks across all teams', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: _showCreateIssueDialog,
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
                              TextField(
                                decoration: InputDecoration(
                                  hintText: 'Search by issue key, title, assignee...',
                                  prefixIcon: const Icon(Icons.search, size: 20),
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                onChanged: (val) => setState(() => _searchQuery = val),
                              ),
                              const SizedBox(height: 10),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    DropdownButton<int?>(
                                      value: _selectedProjectId,
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
                                      items: const [
                                        DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                                        DropdownMenuItem(value: 'OPEN', child: Text('OPEN')),
                                        DropdownMenuItem(value: 'ASSIGNED', child: Text('ASSIGNED')),
                                        DropdownMenuItem(value: 'IN_PROGRESS', child: Text('IN PROGRESS')),
                                        DropdownMenuItem(value: 'IN_REVIEW', child: Text('IN REVIEW')),
                                        DropdownMenuItem(value: 'RESOLVED', child: Text('RESOLVED')),
                                        DropdownMenuItem(value: 'CLOSED', child: Text('CLOSED')),
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
                                  ],
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              // Search Field
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  decoration: InputDecoration(
                                    hintText: 'Search by issue key, title, assignee...',
                                    prefixIcon: const Icon(Icons.search, size: 20),
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                  onChanged: (val) => setState(() => _searchQuery = val),
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Project Filter
                              DropdownButton<int?>(
                                value: _selectedProjectId,
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

                              // Status Filter
                              DropdownButton<String>(
                                value: _selectedStatus,
                                underline: const SizedBox(),
                                items: const [
                                  DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                                  DropdownMenuItem(value: 'OPEN', child: Text('OPEN')),
                                  DropdownMenuItem(value: 'ASSIGNED', child: Text('ASSIGNED')),
                                  DropdownMenuItem(value: 'IN_PROGRESS', child: Text('IN PROGRESS')),
                                  DropdownMenuItem(value: 'IN_REVIEW', child: Text('IN REVIEW')),
                                  DropdownMenuItem(value: 'RESOLVED', child: Text('RESOLVED')),
                                  DropdownMenuItem(value: 'CLOSED', child: Text('CLOSED')),
                                ],
                                onChanged: (val) {
                                  setState(() => _selectedStatus = val!);
                                  _loadData();
                                },
                              ),
                              const SizedBox(width: 16),

                              // Priority Filter
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
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Issues List / Table
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredIssues.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 8),
                                  Text('No issues match current filter', style: TextStyle(color: Colors.grey.shade600)),
                                ],
                              ),
                            )
                          : Card(
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
                                  return ListTile(
                                    leading: Tooltip(
                                      message: 'Click to copy ${issue.issueKey}',
                                      child: InkWell(
                                        onTap: () => ClipboardHelper.copy(context, issue.issueKey, label: 'Issue Key'),
                                        borderRadius: BorderRadius.circular(4),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: issue.type == 'BUG' ? Colors.red.shade50 : Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: issue.type == 'BUG' ? Colors.red.shade200 : Colors.blue.shade200,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                issue.issueKey,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: issue.type == 'BUG' ? Colors.red.shade900 : Colors.blue.shade900,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Icon(
                                                Icons.copy,
                                                size: 10,
                                                color: issue.type == 'BUG' ? Colors.red.shade700 : Colors.blue.shade700,
                                              ),
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
                                        ? const Icon(Icons.chevron_right, color: Colors.grey)
                                        : Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              _buildPriorityBadge(issue.priority),
                                              const SizedBox(width: 12),
                                              _buildStatusBadge(issue.status),
                                              const SizedBox(width: 8),
                                              const Icon(Icons.chevron_right, color: Colors.grey),
                                            ],
                                          ),
                                    onTap: () => _showIssueDetails(issue),
                                  );
                                },
                              ),
                            ),
                ),
              ],
            ),
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
      default: bg = Colors.grey.shade100; fg = Colors.black87;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(status.replaceAll('_', ' '), style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  void _showCreateIssueDialog() {
    int selectedProjId = _projects.isNotEmpty ? _projects.first.id : 1;
    String title = '';
    String description = '';
    String type = 'BUG';
    String priority = 'HIGH';
    int? selectedAssigneeId = _users.isNotEmpty ? _users.first.id : null;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create New Issue / Bug'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Project
                      const Text('Project', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        initialValue: selectedProjId,
                        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                        items: _projects.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                        onChanged: (v) => setDialogState(() => selectedProjId = v!),
                      ),
                      const SizedBox(height: 14),

                      // Title
                      const Text('Issue Title', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        decoration: const InputDecoration(
                          hintText: 'e.g. Login button not working',
                          border: OutlineInputBorder(),
                          isDense: true,
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

                      // Assignee
                      const Text('Assignee', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int?>(
                        initialValue: selectedAssigneeId,
                        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                        items: _users.map((u) => DropdownMenuItem<int?>(
                          value: u.id,
                          child: Text('${u.fullName} (${u.role})'),
                        )).toList(),
                        onChanged: (v) => setDialogState(() => selectedAssigneeId = v),
                      ),
                      const SizedBox(height: 14),

                      // Description
                      const Text('Description / Steps to Reproduce', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Enter details about the bug or task requirements...',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => description = v,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (title.trim().isEmpty) return;
                    final navigator = Navigator.of(context);
                    await ApiService.instance.createIssue(
                      projectId: selectedProjId,
                      title: title,
                      description: description,
                      type: type,
                      priority: priority,
                      assigneeId: selectedAssigneeId,
                    );
                    navigator.pop();
                    _loadData();
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

  void _showIssueDetails(IssueModel issue) async {
    final comments = await ApiService.instance.getComments(issue.id);
    String commentText = '';

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDetailsState) {
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
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 650),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status & Reassign Action Row
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
                                DropdownButton<String>(
                                  value: issue.status,
                                  isDense: true,
                                  items: const [
                                    DropdownMenuItem(value: 'OPEN', child: Text('OPEN')),
                                    DropdownMenuItem(value: 'ASSIGNED', child: Text('ASSIGNED')),
                                    DropdownMenuItem(value: 'IN_PROGRESS', child: Text('IN PROGRESS')),
                                    DropdownMenuItem(value: 'IN_REVIEW', child: Text('IN REVIEW')),
                                    DropdownMenuItem(value: 'RESOLVED', child: Text('RESOLVED')),
                                    DropdownMenuItem(value: 'CLOSED', child: Text('CLOSED')),
                                  ],
                                  onChanged: (newStatus) async {
                                    if (newStatus != null) {
                                      await ApiService.instance.updateIssueStatus(issue.id, newStatus);
                                      setDetailsState(() => issue.status = newStatus);
                                      _loadData();
                                    }
                                  },
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Assignee: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(width: 8),
                                DropdownButton<int?>(
                                  value: issue.assigneeId,
                                  hint: const Text('Unassigned'),
                                  isDense: true,
                                  items: [
                                    const DropdownMenuItem<int?>(value: null, child: Text('Unassigned')),
                                    ..._users.map((u) => DropdownMenuItem<int?>(
                                      value: u.id,
                                      child: Text(u.fullName),
                                    )),
                                  ],
                                  onChanged: (newAssigneeId) async {
                                    if (newAssigneeId != null) {
                                      await ApiService.instance.reassignIssue(issue.id, newAssigneeId);
                                      final assignedUser = _users.firstWhere((u) => u.id == newAssigneeId);
                                      setDetailsState(() {
                                        issue.assigneeId = newAssigneeId;
                                        issue.assigneeName = assignedUser.fullName;
                                      });
                                      _loadData();
                                    }
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
                          SizedBox(width: 120, child: _buildDetailItem('Due Date', issue.dueDate ?? 'Not set')),
                          SizedBox(width: 120, child: _buildDetailItem('Time Logged', '${issue.actualMinutes} mins')),
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

                      // Time Logging Button
                      OutlinedButton.icon(
                        icon: const Icon(Icons.timer, size: 16),
                        label: const Text('Log Work Time (+30 mins)'),
                        onPressed: () async {
                          await ApiService.instance.logTime(issue.id, 30);
                          setDetailsState(() => issue.actualMinutes += 30);
                          _loadData();
                        },
                      ),
                      const SizedBox(height: 20),

                      // Discussion / Comments
                      const Divider(),
                      const Text('Discussion & Activity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                                  Text(c.createdAt, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
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
                              decoration: const InputDecoration(
                                hintText: 'Add a comment or work update...',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (v) => commentText = v,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () async {
                              if (commentText.trim().isEmpty) return;
                              final newC = await ApiService.instance.addComment(issue.id, commentText);
                              setDetailsState(() {
                                comments.add(newC);
                              });
                            },
                            child: const Text('Post'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
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

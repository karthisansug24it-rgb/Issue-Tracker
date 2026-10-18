import 'package:flutter/material.dart';
import '../models/dashboard_metrics_model.dart';
import '../models/issue_model.dart';
import '../services/api_service.dart';
import '../services/auth_state.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int) onNavigateToTab;

  const DashboardScreen({super.key, required this.onNavigateToTab});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardMetricsModel? _metrics;
  List<IssueModel> _recentIssues = [];
  bool _isLoading = true;

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
    final metrics = await ApiService.instance.getDashboardMetrics();
    final issues = await ApiService.instance.getIssues();
    if (mounted) {
      setState(() {
        _metrics = metrics;
        _recentIssues = issues.take(5).toList();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthState.instance.currentUser;
    if (user == null || _isLoading || _metrics == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Banner
          Card(
            color: Colors.blueGrey.shade50,
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.blueGrey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: _getRoleColor(user.role),
                    child: Text(
                      user.fullName.isNotEmpty ? user.fullName[0] : 'U',
                      style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back, ${user.fullName}',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Role: ${_formatRole(user.role)} · Department: ${user.department} · Title: ${user.jobTitle}',
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  Chip(
                    backgroundColor: _getRoleColor(user.role).withValues(alpha: 0.15),
                    side: BorderSide(color: _getRoleColor(user.role)),
                    label: Text(
                      user.role,
                      style: TextStyle(color: _getRoleColor(user.role), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Role-specific description badge
          _buildRoleExplanationBanner(user.role),
          const SizedBox(height: 20),

          // Metrics Summary Cards
          const Text('Overview Metrics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildStatCard('Active Projects', '${_metrics!.totalProjects}', Icons.folder_outlined, Colors.indigo, () => widget.onNavigateToTab(1)),
              _buildStatCard('Total Issues', '${_metrics!.totalIssues}', Icons.assignment_outlined, Colors.blueGrey, () => widget.onNavigateToTab(2)),
              _buildStatCard('Open / Assigned', '${_metrics!.openIssues}', Icons.hourglass_empty, Colors.orange, () => widget.onNavigateToTab(2)),
              _buildStatCard('In Progress', '${_metrics!.inProgressIssues}', Icons.trending_up, Colors.blue, () => widget.onNavigateToTab(2)),
              _buildStatCard('In Review', '${_metrics!.inReviewIssues}', Icons.rate_review_outlined, Colors.purple, () => widget.onNavigateToTab(2)),
              _buildStatCard('Resolved / Closed', '${_metrics!.resolvedIssues + _metrics!.closedIssues}', Icons.check_circle_outline, Colors.green, () => widget.onNavigateToTab(2)),
              _buildStatCard('Critical Priority', '${_metrics!.criticalIssues}', Icons.warning_amber_rounded, Colors.red, () => widget.onNavigateToTab(2)),
            ],
          ),
          const SizedBox(height: 28),

          // Role Specific Focus Section
          if (user.role == 'EMPLOYEE') ...[
            const Text('My Assigned Work', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildSmallStatCard('My Open Tasks', '${_metrics!.myTasks}', Colors.blue)),
                const SizedBox(width: 16),
                Expanded(child: _buildSmallStatCard('My Open Bugs', '${_metrics!.myBugs}', Colors.red)),
                const SizedBox(width: 16),
                Expanded(child: _buildSmallStatCard('Total Assigned to Me', '${_metrics!.myAssignedIssues}', Colors.green)),
              ],
            ),
            const SizedBox(height: 28),
          ],

          // Recent Work Items Table
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Work Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: () => widget.onNavigateToTab(2),
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('View All Issues'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentIssues.length,
              separatorBuilder: (context, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final issue = _recentIssues[index];
                return ListTile(
                  leading: Chip(
                    label: Text(issue.issueKey, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    backgroundColor: Colors.grey.shade200,
                  ),
                  title: Text(issue.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '${issue.projectName} · Assigned to: ${issue.assigneeName ?? "Unassigned"} · Due: ${issue.dueDate ?? "None"}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildPriorityChip(issue.priority),
                      const SizedBox(width: 8),
                      _buildStatusChip(issue.status),
                    ],
                  ),
                  onTap: () => widget.onNavigateToTab(2),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleExplanationBanner(String role) {
    String text;
    IconData icon;
    Color color;

    switch (role) {
      case 'SUPER_ADMIN':
        icon = Icons.admin_panel_settings;
        color = Colors.purple;
        text = 'SUPER ADMIN MODE: Full system control, role permissions, admin accounts, and security audit logs.';
        break;
      case 'ADMIN':
        icon = Icons.business;
        color = Colors.indigo;
        text = 'ADMIN MODE: Department and team management, project creation, employee membership, and company reports.';
        break;
      case 'MANAGER':
        icon = Icons.manage_accounts;
        color = Colors.blue;
        text = 'MANAGER MODE: Project planning, task & bug assignments, deadline tracking, team reviews, and approvals.';
        break;
      default:
        icon = Icons.badge;
        color = Colors.teal;
        text = 'EMPLOYEE MODE: View assigned tasks and bugs, update progress statuses, log work hours, and add comments.';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String count, IconData icon, MaterialColor color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w500)),
                Icon(icon, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            Text(count, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color.shade700)),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallStatCard(String title, String count, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: color.shade900)),
          Text(count, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color.shade700)),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg;
    Color fg;
    switch (status) {
      case 'OPEN':
        bg = Colors.grey.shade200; fg = Colors.grey.shade800; break;
      case 'ASSIGNED':
        bg = Colors.blue.shade50; fg = Colors.blue.shade800; break;
      case 'IN_PROGRESS':
        bg = Colors.amber.shade50; fg = Colors.amber.shade900; break;
      case 'IN_REVIEW':
        bg = Colors.purple.shade50; fg = Colors.purple.shade800; break;
      case 'RESOLVED':
        bg = Colors.green.shade50; fg = Colors.green.shade800; break;
      case 'CLOSED':
        bg = Colors.grey.shade300; fg = Colors.grey.shade900; break;
      default:
        bg = Colors.grey.shade100; fg = Colors.black87;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(status.replaceAll('_', ' '), style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildPriorityChip(String priority) {
    Color color;
    switch (priority) {
      case 'CRITICAL': color = Colors.red; break;
      case 'HIGH': color = Colors.orange; break;
      case 'MEDIUM': color = Colors.blue; break;
      default: color = Colors.grey;
    }
    return Text(priority, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold));
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'SUPER_ADMIN': return Colors.purple;
      case 'ADMIN': return Colors.indigo;
      case 'MANAGER': return Colors.blue.shade700;
      default: return Colors.teal;
    }
  }

  String _formatRole(String role) {
    return role.replaceAll('_', ' ');
  }
}

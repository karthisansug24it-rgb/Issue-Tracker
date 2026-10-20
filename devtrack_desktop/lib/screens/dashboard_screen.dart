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
    try {
      final metrics = await ApiService.instance.getDashboardMetrics();
      final issues = await ApiService.instance.getIssues();
      if (mounted) {
        setState(() {
          _metrics = metrics;
          _recentIssues = issues.take(5).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthState.instance.currentUser;
    if (user == null || _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_metrics == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.blueGrey),
            const SizedBox(height: 12),
            const Text('Unable to load dashboard metrics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Ensure the backend service is running on port 8080.', style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry Connection'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E40AF),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 640;
        final horizontalPadding = isCompact ? 14.0 : 24.0;

        // Dynamic stat card width
        final statCardWidth = constraints.maxWidth < 360
            ? constraints.maxWidth
            : (constraints.maxWidth < 640
                ? (constraints.maxWidth - 12) / 2
                : 172.0);

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 20),
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
                  padding: EdgeInsets.all(isCompact ? 14 : 20),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: isCompact ? 24 : 28,
                            backgroundColor: _getRoleColor(user.role),
                            child: Text(
                              user.fullName.isNotEmpty ? user.fullName[0] : 'U',
                              style: TextStyle(
                                fontSize: isCompact ? 18 : 22,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Welcome back, ${user.fullName}',
                                  style: TextStyle(fontSize: isCompact ? 18 : 22, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Role: ${_formatRole(user.role)} · Dept: ${user.department}',
                                  style: TextStyle(color: Colors.grey.shade700, fontSize: isCompact ? 12 : 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Chip(
                        backgroundColor: _getRoleColor(user.role).withValues(alpha: 0.15),
                        side: BorderSide(color: _getRoleColor(user.role)),
                        label: Text(
                          user.role,
                          style: TextStyle(color: _getRoleColor(user.role), fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Role-specific description badge
              _buildRoleExplanationBanner(user.role),
              const SizedBox(height: 20),

              // Metrics Summary Cards
              const Text('Overview Metrics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildStatCard('Active Projects', '${_metrics!.totalProjects}', Icons.folder_outlined, Colors.indigo, () => widget.onNavigateToTab(1), width: statCardWidth),
                  _buildStatCard('Total Teams', '${_metrics!.totalTeams}', Icons.groups_outlined, Colors.teal, () {
                    if (AuthState.instance.isTeamLead || AuthState.instance.isManager || AuthState.instance.isAdmin) {
                      widget.onNavigateToTab(3);
                    }
                  }, width: statCardWidth),
                  _buildStatCard('Total Issues', '${_metrics!.totalIssues}', Icons.assignment_outlined, Colors.blueGrey, () => widget.onNavigateToTab(2), width: statCardWidth),
                  _buildStatCard('Open / Assigned', '${_metrics!.openIssues}', Icons.hourglass_empty, Colors.orange, () => widget.onNavigateToTab(2), width: statCardWidth),
                  _buildStatCard('In Progress', '${_metrics!.inProgressIssues}', Icons.trending_up, Colors.blue, () => widget.onNavigateToTab(2), width: statCardWidth),
                  _buildStatCard('In Review', '${_metrics!.inReviewIssues}', Icons.rate_review_outlined, Colors.purple, () => widget.onNavigateToTab(2), width: statCardWidth),
                  _buildStatCard('Resolved / Closed', '${_metrics!.resolvedIssues + _metrics!.closedIssues}', Icons.check_circle_outline, Colors.green, () => widget.onNavigateToTab(2), width: statCardWidth),
                  _buildStatCard('Critical Priority', '${_metrics!.criticalIssues}', Icons.warning_amber_rounded, Colors.red, () => widget.onNavigateToTab(2), width: statCardWidth),
                  if (AuthState.instance.isManager || AuthState.instance.isAdmin)
                    _buildStatCard('Total Users', '${_metrics!.totalUsers}', Icons.people_outline, Colors.deepPurple, () {
                      widget.onNavigateToTab(4);
                    }, width: statCardWidth),
                ],
              ),
              const SizedBox(height: 24),

              // Role Specific Focus Section (Responsive Cards - Fixes 38px/33px/77px overflows)
              if (user.role == 'EMPLOYEE' || user.role == 'TEAM_LEAD' || user.role == 'MANAGER' || (_metrics!.myAssignedIssues > 0)) ...[
                const Text('My Assigned Work', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Builder(
                  builder: (context) {
                    final myWorkCardWidth = constraints.maxWidth < 460
                        ? constraints.maxWidth
                        : (constraints.maxWidth < 780
                            ? (constraints.maxWidth - 12) / 2
                            : (constraints.maxWidth - 24) / 3);
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: myWorkCardWidth,
                          child: _buildSmallStatCard('My Open Tasks', '${_metrics!.myTasks}', Icons.task_alt, Colors.blue, onTap: () => widget.onNavigateToTab(2)),
                        ),
                        SizedBox(
                          width: myWorkCardWidth,
                          child: _buildSmallStatCard('My Open Bugs', '${_metrics!.myBugs}', Icons.bug_report, Colors.red, onTap: () => widget.onNavigateToTab(2)),
                        ),
                        SizedBox(
                          width: myWorkCardWidth,
                          child: _buildSmallStatCard('Total Assigned to Me', '${_metrics!.myAssignedIssues}', Icons.assignment_ind, Colors.green, onTap: () => widget.onNavigateToTab(2)),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],

              // Assigned Teams & Leadership Structure Section
              _buildAssignedTeamsSection(),
              const SizedBox(height: 24),

              // Recent Work Items Table
              Wrap(
                spacing: 12,
                runSpacing: 6,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Recent Work Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    onPressed: () => widget.onNavigateToTab(2),
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('View All Issues'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
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
                    final isNarrow = constraints.maxWidth < 520;

                    return ListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 16, vertical: 4),
                      leading: Chip(
                        label: Text(issue.issueKey, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        backgroundColor: Colors.grey.shade200,
                        visualDensity: VisualDensity.compact,
                      ),
                      title: Text(issue.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${issue.projectName} · Assigned: ${issue.assigneeName ?? "Unassigned"}',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (isNarrow) ...[
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                _buildPriorityChip(issue.priority),
                                _buildStatusChip(issue.status),
                              ],
                            ),
                          ],
                        ],
                      ),
                      trailing: isNarrow
                          ? null
                          : Row(
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
      },
    );
  }

  Widget _buildAssignedTeamsSection() {
    final teams = _metrics?.myTeams ?? [];
    final canManageTeams = AuthState.instance.isTeamLead || AuthState.instance.isManager || AuthState.instance.isAdmin;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 6,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Icon(Icons.groups_rounded, color: Color(0xFF1E40AF), size: 22),
                const Text('My Assigned Teams & Works', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Text(
                    '${teams.length} Allocated',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                  ),
                ),
              ],
            ),
            if (canManageTeams)
              TextButton.icon(
                onPressed: () => widget.onNavigateToTab(3),
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('Manage Teams & Members'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (teams.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blueGrey.shade400, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'No Department Teams Assigned Yet',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Once an Admin or Manager assigns you to a team or sets you as a Team Lead / Manager, your team structure and work overview will appear here.',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: teams.map((team) {
                  final cardWidth = isWide ? (constraints.maxWidth - 14) / 2 : constraints.maxWidth;
                  return SizedBox(
                    width: cardWidth,
                    child: _buildTeamCard(team),
                  );
                }).toList(),
              );
            },
          ),
      ],
    );
  }

  Widget _buildTeamCard(Map<String, dynamic> team) {
    final teamName = team['name'] ?? 'Untitled Team';
    final deptName = team['departmentName'] ?? 'General';
    final managerName = team['managerName'] as String?;
    final teamLeadName = team['teamLeadName'] as String?;
    final memberCount = team['memberCount'] ?? 0;
    final roleInTeam = team['userRoleInTeam']?.toString() ?? 'Member';
    final isActive = team['active'] == true;
    final description = team['description'] as String?;

    Color roleColor;
    IconData roleIcon;
    if (roleInTeam.contains('Manager')) {
      roleColor = Colors.blue.shade700;
      roleIcon = Icons.manage_accounts;
    } else if (roleInTeam.contains('Lead')) {
      roleColor = Colors.teal.shade700;
      roleIcon = Icons.psychology;
    } else if (roleInTeam.contains('Admin')) {
      roleColor = Colors.purple.shade700;
      roleIcon = Icons.admin_panel_settings;
    } else {
      roleColor = Colors.green.shade700;
      roleIcon = Icons.person;
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.blueGrey.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Team Name + Dept & Role Chip (Responsive Wrap)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          teamName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isActive ? Colors.green.shade50 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: isActive ? Colors.green.shade300 : Colors.grey.shade300),
                          ),
                          child: Text(
                            isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isActive ? Colors.green.shade800 : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.business_outlined, size: 13, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(deptName, style: TextStyle(color: Colors.grey.shade700, fontSize: 11, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: roleColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: roleColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(roleIcon, size: 14, color: roleColor),
                      const SizedBox(width: 4),
                      Text(
                        roleInTeam,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: roleColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (description != null && description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Assigned Manager & Team Lead Rows
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  // Assigned Manager Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(Icons.manage_accounts, size: 15, color: Colors.blue.shade800),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Manager:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          managerName ?? 'No Manager Assigned',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: managerName != null ? FontWeight.bold : FontWeight.normal,
                            color: managerName != null ? Colors.blue.shade900 : Colors.grey.shade500,
                            fontStyle: managerName != null ? FontStyle.normal : FontStyle.italic,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Assigned Team Lead Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(Icons.psychology, size: 15, color: Colors.teal.shade800),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Team Lead:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          teamLeadName ?? 'No Team Lead Assigned',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: teamLeadName != null ? FontWeight.bold : FontWeight.normal,
                            color: teamLeadName != null ? Colors.teal.shade900 : Colors.grey.shade500,
                            fontStyle: teamLeadName != null ? FontStyle.normal : FontStyle.italic,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Team Members Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(Icons.people_alt_outlined, size: 15, color: Colors.indigo.shade800),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Team Size:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '$memberCount Members Allocated',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.indigo.shade900),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Card Action Buttons (Responsive Wrap)
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 6,
              children: [
                if (AuthState.instance.isTeamLead || AuthState.instance.isManager || AuthState.instance.isAdmin)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    onPressed: () => widget.onNavigateToTab(3),
                    icon: const Icon(Icons.group_add_outlined, size: 14),
                    label: const Text('View Team', style: TextStyle(fontSize: 12)),
                  ),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  onPressed: () => widget.onNavigateToTab(2),
                  icon: const Icon(Icons.task_alt, size: 14),
                  label: const Text('Assigned Works', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
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
        text = 'MANAGER MODE: Project planning, team leadership allocation, resource tracking, and milestone reviews.';
        break;
      case 'TEAM_LEAD':
        icon = Icons.psychology;
        color = Colors.teal;
        text = 'TEAM LEAD MODE: Sprint execution, technical guidance, developer code reviews, and work issue triage.';
        break;
      default:
        icon = Icons.badge;
        color = Colors.teal;
        text = 'EMPLOYEE MODE: View assigned tasks and bugs, update progress statuses, log work hours, and add comments.';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String count, IconData icon, MaterialColor color, VoidCallback onTap, {double? width}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: width ?? 172,
        padding: const EdgeInsets.all(14),
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
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                Icon(icon, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 10),
            Text(count, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color.shade700)),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallStatCard(String title, String count, IconData icon, MaterialColor color, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: color.shade700, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.w600, color: color.shade900, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    count,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color.shade700),
                  ),
                ],
              ),
            ),
          ],
        ),
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
      case 'TEAM_LEAD': return Colors.teal.shade700;
      default: return Colors.blueGrey.shade700;
    }
  }

  String _formatRole(String role) {
    return role.replaceAll('_', ' ');
  }
}

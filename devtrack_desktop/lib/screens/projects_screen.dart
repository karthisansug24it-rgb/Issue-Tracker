import 'package:flutter/material.dart';
import '../models/project_model.dart';
import '../services/api_service.dart';
import '../services/auth_state.dart';

class ProjectsScreen extends StatefulWidget {
  final Function(int) onNavigateToTab;

  const ProjectsScreen({super.key, required this.onNavigateToTab});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  List<ProjectModel> _projects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProjects();
    AuthState.instance.addListener(_loadProjects);
  }

  @override
  void dispose() {
    AuthState.instance.removeListener(_loadProjects);
    super.dispose();
  }

  Future<void> _loadProjects() async {
    setState(() => _isLoading = true);
    final projects = await ApiService.instance.getProjects();
    if (mounted) {
      setState(() {
        _projects = projects;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = AuthState.instance.isManager;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Projects', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Manage project scopes, members, and issue progress', style: TextStyle(color: Colors.grey.shade600)),
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
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // Projects Grid / List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 450,
                        mainAxisExtent: 220,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: _projects.length,
                      itemBuilder: (context, index) {
                        final proj = _projects[index];
                        final progress = proj.totalIssues > 0
                            ? (proj.totalIssues - proj.openIssues) / proj.totalIssues
                            : 0.0;

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
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Manager: ${proj.ownerName}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                    Text('${proj.openIssues} open / ${proj.totalIssues} total', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
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
                              ],
                            ),
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

  void _showCreateProjectDialog() {
    String key = '';
    String name = '';
    String desc = '';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create New Project'),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Project Key (e.g. CRM, MOB)', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  onChanged: (v) => key = v,
                ),
                const SizedBox(height: 14),
                const Text('Project Name', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  onChanged: (v) => name = v,
                ),
                const SizedBox(height: 14),
                const Text('Description', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  maxLines: 3,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  onChanged: (v) => desc = v,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (key.trim().isEmpty || name.trim().isEmpty) return;
                final navigator = Navigator.of(context);
                await ApiService.instance.createProject(key, name, desc);
                navigator.pop();
                _loadProjects();
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }
}

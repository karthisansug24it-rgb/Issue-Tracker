import 'package:flutter/material.dart';
import '../models/audit_log_model.dart';
import '../services/api_service.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  List<AuditLogModel> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final logs = await ApiService.instance.getAuditLogs();
      if (!mounted) return;
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red.shade800, content: Text('Error loading audit logs: $e')),
      );
    }
  }

  Future<void> _confirmDeleteLog(AuditLogModel log) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Audit Log?'),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete this audit log record (${log.action}: ${log.details}) from the database? This action cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiService.instance.deleteAuditLog(log.id);
        setState(() => _logs.removeWhere((l) => l.id == log.id));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(backgroundColor: Colors.green, content: Text('Audit log record deleted permanently.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: Colors.red.shade800, content: Text('Error deleting audit log: $e')),
          );
        }
      }
    }
  }

  Future<void> _confirmClearAllLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Purge All Audit Logs?'),
          ],
        ),
        content: const Text(
          'Are you sure you want to permanently delete ALL security & audit logs from the database?\n\n'
          'All historical audit records will be permanently erased. This action cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Purge All Logs'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiService.instance.clearAuditLogs();
        setState(() => _logs.clear());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(backgroundColor: Colors.green, content: Text('All audit logs purged permanently from database.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: Colors.red.shade800, content: Text('Error purging audit logs: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Security & Audit Logs', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          'Historical audit trail of administrative activities and system changes',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                    if (_logs.isNotEmpty)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.delete_sweep, size: 16, color: Colors.redAccent),
                        label: const Text('Clear All Logs', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: _confirmClearAllLogs,
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _logs.isEmpty
                          ? Center(
                              child: Text('No audit logs recorded yet.', style: TextStyle(color: Colors.grey.shade600)),
                            )
                          : Card(
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                              child: ListView.separated(
                                itemCount: _logs.length,
                                separatorBuilder: (context, _) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final log = _logs[index];
                                  return ListTile(
                                    contentPadding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 16, vertical: 4),
                                    leading: const CircleAvatar(
                                      backgroundColor: Colors.blueGrey,
                                      child: Icon(Icons.shield_outlined, color: Colors.white, size: 20),
                                    ),
                                    title: Wrap(
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: [
                                        Text(
                                          log.action,
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        Chip(
                                          label: Text(log.entityType, style: const TextStyle(fontSize: 10)),
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                        ),
                                      ],
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('${log.actorName} · ${log.details}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                                          if (isCompact) ...[
                                            const SizedBox(height: 2),
                                            Text(log.timestamp, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                                          ],
                                        ],
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (!isCompact)
                                          Text(log.timestamp, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                          tooltip: 'Delete record permanently',
                                          onPressed: () => _confirmDeleteLog(log),
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
}

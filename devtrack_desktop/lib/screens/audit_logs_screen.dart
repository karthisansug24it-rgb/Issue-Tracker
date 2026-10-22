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
                const Text('Security & Audit Logs', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  'Historical audit trail of administrative activities and system changes',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
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
                                    trailing: isCompact
                                        ? null
                                        : Text(log.timestamp, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
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

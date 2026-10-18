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
    final logs = await ApiService.instance.getAuditLogs();
    if (mounted) {
      setState(() {
        _logs = logs;
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
            const Text('Security & Audit Logs', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Historical audit trail of administrative activities and system changes', style: TextStyle(color: Colors.grey.shade600)),
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
                        itemCount: _logs.length,
                        separatorBuilder: (context, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final log = _logs[index];
                          return ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Colors.blueGrey,
                              child: Icon(Icons.shield_outlined, color: Colors.white, size: 20),
                            ),
                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    log.action,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Chip(label: Text(log.entityType, style: const TextStyle(fontSize: 10))),
                              ],
                            ),
                            subtitle: Text('${log.actorName} · ${log.details}'),
                            trailing: Text(log.timestamp, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
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
}

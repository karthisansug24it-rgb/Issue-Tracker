import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/api_service.dart';

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int _unread = 0;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refreshCount();
  }

  Future<void> _refreshCount() async {
    try {
      final count = await ApiService.instance.getUnreadNotificationCount();
      if (mounted) setState(() => _unread = count);
    } catch (_) {}
  }

  Future<void> _openList() async {
    if (_loading) return;
    setState(() => _loading = true);
    List<NotificationModel> items = [];
    try {
      items = await ApiService.instance.getNotifications();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red.shade800, content: Text(e.toString())),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _loading = false);

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final unread = items.where((n) => !n.read).length;
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.notifications_outlined, color: Color(0xFF1E40AF)),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold))),
                  if (unread > 0)
                    TextButton(
                      onPressed: () async {
                        try {
                          await ApiService.instance.markAllNotificationsRead();
                          setDialogState(() {
                            for (final n in items) {
                              n.read = true;
                            }
                          });
                        } catch (_) {}
                      },
                      child: const Text('Mark all read'),
                    ),
                ],
              ),
              content: SizedBox(
                width: 480,
                height: items.isEmpty ? 100 : 420,
                child: items.isEmpty
                    ? const Center(
                        child: Text('You have no notifications.', textAlign: TextAlign.center),
                      )
                    : ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final n = items[i];
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              n.read ? Icons.notifications_none : Icons.notifications_active,
                              color: n.read ? Colors.grey : const Color(0xFF1E40AF),
                            ),
                            title: Text(
                              n.title,
                              style: TextStyle(fontWeight: n.read ? FontWeight.normal : FontWeight.bold),
                            ),
                            subtitle: Text('${n.message}\n${n.createdAt}', style: const TextStyle(fontSize: 11)),
                            isThreeLine: true,
                            onTap: n.read
                                ? null
                                : () async {
                                    try {
                                      await ApiService.instance.markNotificationRead(n.id);
                                      setDialogState(() => n.read = true);
                                    } catch (_) {}
                                  },
                          );
                        },
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
    _refreshCount();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: _unread > 0 ? '$_unread unread notification(s)' : 'Notifications',
      onPressed: _openList,
      icon: Badge(
        isLabelVisible: _unread > 0,
        label: Text(_unread > 99 ? '99+' : '$_unread'),
        child: const Icon(Icons.notifications_outlined, color: Colors.black87),
      ),
    );
  }
}

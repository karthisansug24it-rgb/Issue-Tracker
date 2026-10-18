import 'package:flutter/material.dart';

class TeamsScreen extends StatelessWidget {
  const TeamsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final departments = [
      {'name': 'Engineering', 'code': 'ENG', 'teams': 'Web Development Team, Mobile & Cloud Team'},
      {'name': 'Quality Assurance', 'code': 'QA', 'teams': 'Core QA & Automation Team'},
      {'name': 'Operations & Support', 'code': 'OPS', 'teams': 'Platform Operations, IT Support'},
    ];

    final teams = [
      {'name': 'Web Development Team', 'dept': 'Engineering', 'lead': 'Arun Kumar', 'members': 'Karthi Raman, Priya Sharma'},
      {'name': 'Mobile & Cloud Team', 'dept': 'Engineering', 'lead': 'Arun Kumar', 'members': 'Karthi Raman'},
      {'name': 'Core QA Team', 'dept': 'Quality Assurance', 'lead': 'Vijay Tester', 'members': 'Vijay Tester'},
    ];

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Departments & Teams', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Organizational structure and team composition', style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 24),

            // Departments Section
            const Text('Departments', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: departments.map((d) => Expanded(
                child: Card(
                  margin: const EdgeInsets.only(right: 16),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(d['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Chip(label: Text(d['code']!, style: const TextStyle(fontSize: 11))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Teams: ${d['teams']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: 28),

            // Teams Section
            const Text('Active Teams', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Expanded(
              child: Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: ListView.separated(
                  itemCount: teams.length,
                  separatorBuilder: (context, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final t = teams[index];
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.indigo,
                        child: Icon(Icons.group, color: Colors.white, size: 20),
                      ),
                      title: Text(t['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Department: ${t['dept']} · Lead: ${t['lead']} · Members: ${t['members']}'),
                      trailing: const Chip(label: Text('ACTIVE', style: TextStyle(fontSize: 11))),
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

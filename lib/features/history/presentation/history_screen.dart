import 'package:flutter/material.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Attendance History')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SearchBar(hintText: 'Search attendance'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Present'),
                  selected: true,
                  onSelected: (_) {},
                ),
                ActionChip(label: const Text('Export PDF'), onPressed: () {}),
                ActionChip(label: const Text('Export Excel'), onPressed: () {}),
              ],
            ),
            const ListTile(
              leading: Icon(Icons.verified),
              title: Text('Today'),
              subtitle: Text('Status • Location • Device'),
            ),
          ],
        ),
      );
}

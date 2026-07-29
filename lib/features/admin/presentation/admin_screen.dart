import 'package:flutter/material.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Admin Panel')),
    body: GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(16),
      children: const [
        Card(child: Center(child: Text('Create / Rotate QR'))),
        Card(child: Center(child: Text('View Attendance'))),
        Card(child: Center(child: Text('Search Employees'))),
        Card(child: Center(child: Text('Reports & Charts'))),
      ],
    ),
  );
}

import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _biometricEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SwitchListTile(
            title: const Text('Dark Mode'),
            value: Theme.of(context).brightness == Brightness.dark,
            onChanged: (val) {
              // Implementation requires ThemeProvider setup
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Theme switching not yet wired to Riverpod')),
              );
            },
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Biometric Login'),
            value: _biometricEnabled,
            onChanged: (val) {
              setState(() => _biometricEnabled = val);
            },
          ),
        ],
      ),
    );
  }
}

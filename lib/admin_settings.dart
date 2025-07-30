import 'package:flutter/material.dart';
import 'widgets/password_change_dialog.dart';

class AdminSettingsPage extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onDarkModeChanged;

  const AdminSettingsPage({
    super.key,
    required this.isDarkMode,
    required this.onDarkModeChanged,
  });

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  late bool _isDarkMode;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.black, // Dark text/icons on purple background
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // 🔒 Change Password
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('Change Password'),
            onTap: () async {
              await showDialog(
                context: context,
                builder: (context) => const PasswordChangeDialog(),
              );
            },
          ),

          const Divider(),

          // 🌓 Dark Mode Toggle
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode),
            title: const Text('Dark Mode'),
            value: _isDarkMode,
            onChanged: (value) {
              setState(() => _isDarkMode = value);
              widget.onDarkModeChanged(value); // Notify main.dart
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(value ? 'Dark mode enabled' : 'Dark mode disabled'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),

          const Divider(),

          // 👤 View Profile Info
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('View Profile Info'),
            onTap: () {
              Navigator.pushNamed(context, '/admin/profile');
            },
          ),
        ],
      ),
    );
  }


}

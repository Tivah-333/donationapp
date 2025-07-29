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
  String selectedLanguage = 'English';

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),

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
            },
          ),

          const Divider(),

          // 🌍 Language Selection
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Language'),
            subtitle: Text(selectedLanguage),
            onTap: () {
              _showLanguageDialog(context);
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

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              value: 'English',
              groupValue: selectedLanguage,
              title: const Text('English'),
              onChanged: (value) {
                setState(() => selectedLanguage = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              value: 'Swahili',
              groupValue: selectedLanguage,
              title: const Text('Swahili'),
              onChanged: (value) {
                setState(() => selectedLanguage = value!);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

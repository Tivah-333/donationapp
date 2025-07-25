import 'package:flutter/material.dart';

class DonorNotificationSetting extends StatefulWidget {
  const DonorNotificationSetting({super.key});

  @override
  State<DonorNotificationSetting> createState() => _DonorNotificationSettingState();
}

class _DonorNotificationSettingState extends State<DonorNotificationSetting> {
  bool notificationsEnabled = true; // default ON

  void _toggleNotifications(bool value) {
    setState(() {
      notificationsEnabled = value;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          notificationsEnabled
              ? 'Notifications enabled'
              : 'Notifications disabled',
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    // TODO: Save preference to backend or local storage if needed
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        backgroundColor: Colors.deepPurple
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Enable Notifications'),
            trailing: Switch(
              value: notificationsEnabled,
              onChanged: _toggleNotifications,
            ),
          ),
          const Divider(),
          Expanded(
            child: Center(
              child: notificationsEnabled
                  ? const Text(
                'You have no notifications yet.',
                style: TextStyle(fontSize: 16),
              )
                  : const Text(
                'Notifications are disabled.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

class OrganizationSettingsPage extends StatefulWidget {
  const OrganizationSettingsPage({super.key});

  @override
  State<OrganizationSettingsPage> createState() => _OrganizationSettingsPageState();
}

class _OrganizationSettingsPageState extends State<OrganizationSettingsPage> {
  bool emailNotifications = true;
  String? location;
  final user = FirebaseAuth.instance.currentUser;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController contactController = TextEditingController();

  String? profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _getLocation();
  }

  Future<void> _loadUserData() async {
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      final data = doc.data();
      if (data != null) {
        nameController.text = data['name'] ?? '';
        contactController.text = data['contact'] ?? '';
        emailNotifications = data['emailNotifications'] ?? true;
        profileImageUrl = data['profileImageUrl'];
        setState(() {});
      }
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
      'name': nameController.text.trim(),
      'contact': contactController.text.trim(),
      'emailNotifications': emailNotifications,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated successfully')),
    );
  }

  Future<void> _changePassword() async {
    final TextEditingController passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: TextField(
          controller: passwordController,
          decoration: const InputDecoration(labelText: 'New Password'),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await user!.updatePassword(passwordController.text.trim());
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password changed successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: ${e.toString()}')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text('Are you sure you want to permanently delete your account? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldDelete == true && user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user!.uid).delete();
        await user!.delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account deleted successfully')),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting account: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _getLocation() async {
    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() => location = 'Location permission denied');
        return;
      }

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        location = '📍 ${position.latitude.toStringAsFixed(2)}, ${position.longitude.toStringAsFixed(2)}';
      });

      await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
        'location': GeoPoint(position.latitude, position.longitude),
      });
    } catch (e) {
      setState(() => location = 'Failed to get location');
    }
  }

  Future<void> _changeProfilePicture() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null && user != null) {
      final ref = FirebaseStorage.instance.ref().child('profile_pics').child('${user!.uid}.jpg');
      await ref.putFile(File(picked.path));
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
        'profileImageUrl': url,
      });

      setState(() => profileImageUrl = url);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile picture updated')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Account Management', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          // Profile Picture
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage: profileImageUrl != null ? NetworkImage(profileImageUrl!) : null,
                  child: profileImageUrl == null
                      ? const Icon(Icons.person, size: 50)
                      : null,
                ),
                TextButton(
                  onPressed: _changeProfilePicture,
                  child: const Text('Change Profile Picture'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Organization Name'),
                  validator: (value) => value!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: contactController,
                  decoration: const InputDecoration(labelText: 'Contact Info'),
                  validator: (value) => value!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Save Changes'),
                  onPressed: _updateProfile,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.lock),
                  label: const Text('Change Password'),
                  onPressed: _changePassword,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.delete),
                  label: const Text('Delete Account'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _deleteAccount,
                ),
              ],
            ),
          ),

          const Divider(height: 32),

          const Text('Notification Preferences', style: TextStyle(fontWeight: FontWeight.bold)),
          SwitchListTile(
            title: const Text('Email Notifications'),
            value: emailNotifications,
            onChanged: (val) {
              setState(() => emailNotifications = val);
            },
          ),

          const Divider(height: 32),

          const Text('Location Settings', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(location ?? 'Getting location...'),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _getLocation,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

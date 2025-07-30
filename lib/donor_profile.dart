import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class DonorProfilePage extends StatefulWidget {
  const DonorProfilePage({super.key});

  @override
  State<DonorProfilePage> createState() => _DonorProfilePageState();
}

class _DonorProfilePageState extends State<DonorProfilePage> {
  final user = FirebaseAuth.instance.currentUser;

  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController contactController = TextEditingController();

  String? profileImageUrl;
  String? email;

  int totalDonations = 0;
  DateTime? lastDonationDate;
  List<String> badgesEarned = [];

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    email = user?.email; // Get email directly from FirebaseAuth user on init
    _loadUserData();
    _loadDonationStats();
  }

  Future<void> _loadUserData() async {
    if (user == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
    final data = doc.data();

    if (data != null) {
      setState(() {
        nameController.text = data['name'] ?? '';
        contactController.text = data['contact'] ?? '';
        profileImageUrl = data['profileImageUrl'];
        // email already set from FirebaseAuth, no need to update from Firestore
      });
    }
  }

  Future<void> _loadDonationStats() async {
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('donations')
          .where('donorId', isEqualTo: user!.uid)
          .orderBy('timestamp', descending: true)
          .get();

      int count = snapshot.docs.length;
      DateTime? lastDate;

      if (count > 0) {
        final firstDonation = snapshot.docs.first.data();
        lastDate = (firstDonation['timestamp'] as Timestamp).toDate();
      }

      setState(() {
        totalDonations = count;
        lastDonationDate = lastDate;
        badgesEarned = _calculateBadges(count);
      });
    } catch (e) {
      // Handle errors if needed
    }
  }

  List<String> _calculateBadges(int donationCount) {
    final badges = <String>[];
    if (donationCount >= 5) badges.add('Bronze Donor');
    if (donationCount >= 15) badges.add('Silver Donor');
    if (donationCount >= 30) badges.add('Gold Donor');
    return badges;
  }

  Future<void> _changeProfilePicture() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null && user != null) {
      setState(() => isLoading = true);

      final ref = FirebaseStorage.instance.ref().child('profile_pics').child('${user!.uid}.jpg');
      await ref.putFile(File(picked.path));
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
        'profileImageUrl': url,
      });

      setState(() {
        profileImageUrl = url;
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture updated')),
      );
    }
  }

  Future<void> _deleteProfilePicture() async {
    if (user == null || profileImageUrl == null) return;

    // Show confirmation dialog
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Profile Picture'),
        content: const Text('Are you sure you want to delete your profile picture?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    setState(() => isLoading = true);

    try {
      // Delete from Firebase Storage
      final ref = FirebaseStorage.instance.ref().child('profile_pics').child('${user!.uid}.jpg');
      await ref.delete();

      // Update Firestore to remove the profile image URL
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
        'profileImageUrl': null,
      });

      setState(() {
        profileImageUrl = null;
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture deleted')),
      );
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting profile picture: $e')),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (user == null) return;

    setState(() => isLoading = true);

    await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
      'name': nameController.text.trim(),
      'contact': contactController.text.trim(),
    });

    setState(() => isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated successfully')),
    );
  }

  Widget _buildBadgeChip(String badge) {
    Color bgColor = Colors.grey.shade300;
    Color textColor = Colors.black;
    IconData icon = Icons.emoji_events_outlined;

    switch (badge) {
      case 'Bronze Donor':
        bgColor = const Color(0xFFCD7F32);
        icon = Icons.emoji_events;
        break;
      case 'Silver Donor':
        bgColor = Colors.grey.shade400;
        icon = Icons.emoji_events_outlined;
        break;
      case 'Gold Donor':
        bgColor = Colors.amber;
        icon = Icons.workspace_premium;
        break;
    }

    return Chip(
      label: Text(badge, style: TextStyle(color: textColor)),
      backgroundColor: bgColor,
      avatar: Icon(icon, color: textColor),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    contactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lastDonationText = lastDonationDate != null
        ? '${lastDonationDate!.toLocal().toString().split(' ')[0]}'
        : 'No donations yet';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.deepPurple,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Center(
              child: Column(
                children: [
                  // Profile Picture with subtle edit indicator
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundImage: profileImageUrl != null
                            ? NetworkImage(profileImageUrl!)
                            : null,
                        child: profileImageUrl == null
                            ? const Icon(Icons.person, size: 60)
                            : null,
                      ),
                      // Subtle edit indicator
                      if (profileImageUrl != null)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.edit,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Action buttons below the image
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _changeProfilePicture,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Change Photo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      if (profileImageUrl != null) ...[
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _deleteProfilePicture,
                          icon: const Icon(Icons.delete),
                          label: const Text('Remove'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name input
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                    (value == null || value.trim().isEmpty)
                        ? 'Name is required'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Email displayed as read-only text with label
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Email (read-only)',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      email ?? 'No email found',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Contact info input
                  TextFormField(
                    controller: contactController,
                    decoration: const InputDecoration(
                      labelText: 'Contact Info',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                    (value == null || value.trim().isEmpty)
                        ? 'Contact info is required'
                        : null,
                  ),
                  const SizedBox(height: 24),

                  // Donation stats
                  Text(
                    'Donation Stats:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text('Total Donations Made: $totalDonations'),
                  const SizedBox(height: 8),
                  Text('Last Donation Date: $lastDonationText'),
                  const SizedBox(height: 16),

                  Wrap(
                    spacing: 8,
                    children:
                    badgesEarned.map((badge) => _buildBadgeChip(badge)).toList(),
                  ),

                  const SizedBox(height: 32),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveProfile,
                      child: const Text('Save Changes'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

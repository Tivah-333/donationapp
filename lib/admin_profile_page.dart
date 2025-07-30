import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'widgets/password_change_dialog.dart';

class AdminProfilePage extends StatefulWidget {
  const AdminProfilePage({Key? key}) : super(key: key);

  @override
  State<AdminProfilePage> createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends State<AdminProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? user;
  String? profileImageUrl;
  String? phoneNumber = 'Not set';
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    user = _auth.currentUser;
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      final data = doc.data();
      
      if (data != null) {
        setState(() {
          profileImageUrl = data['profileImageUrl'];
          phoneNumber = data['phoneNumber'] ?? 'Not set';
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    
    if (picked != null && user != null) {
      setState(() => isLoading = true);

      try {
        print('🖼️ Starting image upload for user: ${user!.uid}');
        
        // Create a unique filename with timestamp
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = '${user!.uid}_$timestamp.jpg';
        
        // Upload to Firebase Storage
        final ref = FirebaseStorage.instance.ref().child('profile_pics').child(fileName);
        print('📁 Storage reference: ${ref.fullPath}');
        
        // Upload the file
        final uploadTask = ref.putFile(File(picked.path));
        print('📤 Upload task started');
        
        // Wait for upload to complete
        final snapshot = await uploadTask;
        print('✅ Upload completed, bytes transferred: ${snapshot.bytesTransferred}');
        
        // Get download URL
        final url = await ref.getDownloadURL();
        print('🔗 Download URL: $url');

        // Update Firestore
        await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
          'profileImageUrl': url,
        });
        print('📝 Firestore updated successfully');

        setState(() {
          profileImageUrl = url;
          isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated')),
        );
      } catch (e) {
        print('❌ Error uploading image: $e');
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile picture: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
      print('🗑️ Starting profile picture deletion for user: ${user!.uid}');
      
      // Extract filename from URL if possible, otherwise use default
      String fileName = '${user!.uid}.jpg';
      if (profileImageUrl!.contains('/profile_pics/')) {
        final urlParts = profileImageUrl!.split('/profile_pics/');
        if (urlParts.length > 1) {
          fileName = urlParts[1].split('?')[0]; // Remove query parameters
        }
      }
      
      // Delete from Firebase Storage
      final ref = FirebaseStorage.instance.ref().child('profile_pics').child(fileName);
      print('📁 Storage reference to delete: ${ref.fullPath}');
      
      try {
        await ref.delete();
        print('✅ File deleted from Firebase Storage');
      } catch (deleteError) {
        print('⚠️ Could not delete file from storage (may not exist): $deleteError');
        // Continue with Firestore update even if file doesn't exist
      }

      // Update Firestore to remove the profile image URL
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
        'profileImageUrl': null,
      });
      print('📝 Firestore updated - profile image URL removed');

      setState(() {
        profileImageUrl = null;
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile picture deleted'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('❌ Error deleting profile picture: $e');
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting profile picture: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _changePassword() async {
    await showDialog(
      context: context,
      builder: (context) => const PasswordChangeDialog(),
    );
  }

  Future<void> _logoutAllDevices() async {
    try {
      await _auth.signOut();
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to logout. Please try again.')),
      );
    }
  }

  String _getFormattedLastLogin() {
    final metadata = user?.metadata;
    if (metadata == null) return 'Unknown';
    final lastSignIn = metadata.lastSignInTime;
    if (lastSignIn == null) return 'Unknown';
    return '${lastSignIn.day}/${lastSignIn.month}/${lastSignIn.year} ${lastSignIn.hour}:${lastSignIn.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Profile'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Column(
                    children: [
                      // Profile Picture with subtle edit indicator
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundImage: profileImageUrl != null
                                ? NetworkImage(profileImageUrl!)
                                : null,
                            child: profileImageUrl == null
                                ? const Icon(Icons.person, size: 50)
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
                            onPressed: _pickImage,
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Change Photo'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
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
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('Full Name'),
                  subtitle: Text(user?.displayName ?? 'Not set'),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.email),
                  title: const Text('Email'),
                  subtitle: Text(user?.email ?? 'Not set'),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.phone),
                  title: const Text('Phone Number'),
                  subtitle: Text(phoneNumber ?? 'Not set'),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.lock),
                  title: const Text('Change Password'),
                  onTap: _changePassword,
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.access_time),
                  title: const Text('Last Login'),
                  subtitle: Text(_getFormattedLastLogin()),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Logout of All Devices'),
                  onTap: _logoutAllDevices,
                ),
              ],
            ),
    );
  }
}

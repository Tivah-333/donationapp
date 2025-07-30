import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfilePictureWidget extends StatefulWidget {
  final double size;
  final VoidCallback? onTap;
  final String? userId;

  const ProfilePictureWidget({
    Key? key,
    this.size = 32,
    this.onTap,
    this.userId,
  }) : super(key: key);

  @override
  State<ProfilePictureWidget> createState() => _ProfilePictureWidgetState();
}

class _ProfilePictureWidgetState extends State<ProfilePictureWidget> {
  String? profileImageUrl;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    try {
      final userId = widget.userId ?? FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        setState(() => isLoading = false);
        return;
      }

      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      final data = doc.data();
      
      if (mounted) {
        setState(() {
          profileImageUrl = data?['profileImageUrl'];
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: const CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: CircleAvatar(
        radius: widget.size / 2,
        backgroundImage: profileImageUrl != null ? NetworkImage(profileImageUrl!) : null,
        backgroundColor: Colors.grey.shade300,
        child: profileImageUrl == null
            ? Icon(
                Icons.person,
                size: widget.size * 0.6,
                color: Colors.grey.shade600,
              )
            : null,
      ),
    );
  }
} 
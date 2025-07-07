import 'package:flutter/material.dart';

import 'donor_home.dart';
import 'organization_home.dart';
import 'admin_home.dart';

class HomeRouter extends StatelessWidget {
  final String userRole;

  const HomeRouter({super.key, required this.userRole});

  @override
  Widget build(BuildContext context) {
    if (userRole == 'Donor') return const DonorHome();
    if (userRole == 'Organization') return const OrganizationHome();
    if (userRole == 'Administrator') return const AdminHome();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacementNamed(context, '/login');
    });

    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

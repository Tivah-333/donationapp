import 'package:flutter/material.dart';

class HelpFAQPage extends StatefulWidget {
  const HelpFAQPage({super.key});

  @override
  State<HelpFAQPage> createState() => _HelpFAQPageState();
}

class _HelpFAQPageState extends State<HelpFAQPage> {
  final List<Map<String, dynamic>> _faqs = [
    {
      'question': 'How do I request donations as an organization?',
      'answer': 'Go to "Create Donation Request", fill in the details of what you need, and submit. Admin will review and assign donations to you based on location and availability.',
    },
    {
      'question': 'How do I know when donations are assigned to me?',
      'answer': 'You will receive notifications when admin assigns donations to your organization. Check your notifications page for updates.',
    },
    {
      'question': 'How do I view assigned donations?',
      'answer': 'Go to "Assigned Donations" in your dashboard to see all donations assigned to your organization.',
    },
    {
      'question': 'What should I do when I receive an assigned donation?',
      'answer': 'Review the donation details, contact the donor if needed, and update the status to "Picked Up" or "Delivered" once you receive it.',
    },
    {
      'question': 'How do I update donation status?',
      'answer': 'In your assigned donations page, you can mark donations as "Picked Up" or "Delivered" to track their progress.',
    },
    {
      'question': 'What if I need to report a problem?',
      'answer': 'Use the "Report a Problem" feature in your dashboard. Admin will review and respond to your report.',
    },
    {
      'question': 'How do I contact support?',
      'answer': 'Use the "Contact Support" feature in your dashboard. Admin will respond to your support request.',
    },
    {
      'question': 'How do I update my organization profile?',
      'answer': 'Go to Settings/Profile page to update your organization information, change password, or modify notification preferences.',
    },
    {
      'question': 'What if I forgot my password?',
      'answer': 'Use the "Forgot Password" option on the login screen to reset your password via email.',
    },
    {
      'question': 'How does location matching work?',
      'answer': 'For pickup donations, organizations near the pickup station are matched. For drop-off donations, organizations in the same location as the donor are matched.',
    },
    {
      'question': 'How long does it take to get approved as an organization?',
      'answer': 'Admin reviews organization registrations within 24-48 hours. You will receive a notification when approved or rejected.',
    },
    {
      'question': 'Can I see donation statistics?',
      'answer': 'Yes! Check your "Donation Statistics" page to see pending, picked up, and delivered donations with detailed information.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & FAQ'),
        backgroundColor: Colors.deepPurple,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _faqs.length,
        itemBuilder: (context, index) {
          final faq = _faqs[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              title: Text(
                faq['question'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    faq['answer'],
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
} 
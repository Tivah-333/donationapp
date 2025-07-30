import 'package:flutter/material.dart';

class HelpFAQPage extends StatefulWidget {
  final String? userType; // 'donor' or 'organization'
  
  const HelpFAQPage({super.key, this.userType});

  @override
  State<HelpFAQPage> createState() => _HelpFAQPageState();
}

class _HelpFAQPageState extends State<HelpFAQPage> {
  List<Map<String, dynamic>> get _faqs {
    if (widget.userType == 'donor') {
      return [
        {
          'question': 'How do I make a donation?',
          'answer': 'Go to "Make a Donation" in your dashboard, fill in the details of what you want to donate, and submit. Organizations will be matched based on your location and their needs.',
        },
        {
          'question': 'How do I know when my donation is assigned?',
          'answer': 'You will receive notifications when admin assigns your donation to an organization. Check your notifications page for updates.',
        },
        {
          'question': 'What delivery options are available?',
          'answer': 'You can choose between "Pickup" (organizations pick up from a designated station) or "Drop-off" (you deliver to the organization directly).',
        },
        {
          'question': 'How do I track my donation status?',
          'answer': 'Check your "Donation History" page to see the status of all your donations - pending, picked up, or delivered.',
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
          'question': 'How do I update my profile?',
          'answer': 'Go to Settings/Profile page to update your information, change password, or modify notification preferences.',
        },
        {
          'question': 'What if I forgot my password?',
          'answer': 'Use the "Forgot Password" option on the login screen to reset your password via email.',
        },
        {
          'question': 'How does location matching work?',
          'answer': 'For pickup donations, organizations near the pickup station are matched. For drop-off donations, organizations in the same location as you are matched.',
        },
        {
          'question': 'Can I see my donation history?',
          'answer': 'Yes! Check your "Donation History" page to see all your past and current donations with detailed information.',
        },
        {
          'question': 'What types of items can I donate?',
          'answer': 'You can donate various items including clothes, food supplies, medical supplies, school supplies, hygiene products, electronics, furniture, and more.',
        },
        {
          'question': 'How do I know if my donation was received?',
          'answer': 'You will receive notifications when your donation is picked up or delivered by the organization.',
        },
      ];
    } else {
      // Organization FAQ
      return [
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userType == 'donor' ? 'Donor Help & FAQ' : 'Organization Help & FAQ'),
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
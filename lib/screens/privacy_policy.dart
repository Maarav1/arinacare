import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentDate = DateTime.now();
    final formattedDate = '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'Privacy Policy',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 20),
            
            // Last Updated
            Text(
              'Last Updated: $formattedDate',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 30),

            // Introduction
            _buildSection(
              title: '1. Introduction',
              content: 'Welcome to Arina Cave. We are committed to protecting your personal information and your right to privacy. If you have any questions or concerns about this privacy policy, or our practices with regards to your personal information, please contact us.',
            ),

            // Information We Collect
            _buildSection(
              title: '2. Information We Collect',
              content: 'We collect personal information that you voluntarily provide to us when you register on the app, express an interest in obtaining information about us or our products and services, or otherwise when you contact us.',
            ),

            // Personal Information
            _buildSection(
              title: '2.1 Personal Information',
              content: 'The personal information we collect may include:\n\n• Name and contact data (first name, last name, email address)\n• Profile information (gender, interests, relationship status, occupation, education)\n• Location data (country, city)\n• Profile pictures\n• Hobbies and preferences',
            ),

            // How We Use Your Information
            _buildSection(
              title: '3. How We Use Your Information',
              content: 'We use personal information collected via our app for a variety of business purposes described below:\n\n• To facilitate account creation and login process\n• To provide and maintain our service\n• To manage your account\n• To enable user-to-user connections\n• For business transfers\n• For other business purposes',
            ),

            // Information Sharing
            _buildSection(
              title: '4. Will Your Information Be Shared With Anyone?',
              content: 'We only share information with your consent, to comply with laws, to provide you with services, to protect your rights, or to fulfill business obligations.\n\nWe do not sell your personal information to third parties.',
            ),

            // Data Security
            _buildSection(
              title: '5. How Do We Keep Your Information Safe?',
              content: 'We have implemented appropriate technical and organizational security measures designed to protect the security of any personal information we process. However, please also remember that we cannot guarantee that the internet itself is 100% secure.',
            ),

            // Your Privacy Rights
            _buildSection(
              title: '6. What Are Your Privacy Rights?',
              content: 'You have the right to:\n\n• Request access to your personal information\n• Request correction of your personal information\n• Request deletion of your personal information\n• Withdraw your consent at any time\n• Object to processing of your personal information',
            ),

            // Data Retention
            _buildSection(
              title: '7. How Long Do We Keep Your Information?',
              content: 'We will only keep your personal information for as long as it is necessary for the purposes set out in this privacy policy, unless a longer retention period is required or permitted by law.',
            ),

            // Updates to This Policy
            _buildSection(
              title: '8. Updates to This Policy',
              content: 'We may update this privacy policy from time to time. The updated version will be indicated by an updated "Last Updated" date and the updated version will be effective as soon as it is accessible.',
            ),

            // Contact Us
            _buildSection(
              title: '9. Contact Us',
              content: 'If you have questions or comments about this policy, you may contact us at:\n\nEmail: privacy@arinacave.com\n\nAddress: [Your Company Address]',
            ),

            const SizedBox(height: 40),
            
            // Agree Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.pop(),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'I Understand',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required String content}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
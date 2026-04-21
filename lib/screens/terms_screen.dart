import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentDate = DateTime.now();
    final formattedDate =
        '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Service'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Last Updated: $formattedDate',
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 20),
            const Text(
              'Welcome to our dating app. By using our service, you agree to these Terms of Service. Please read them carefully.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('1. Eligibility'),
            _buildSectionContent(
              'You must be at least 18 years old to use this app. By creating an account, you represent and warrant that you meet this age requirement.',
            ),
            const SizedBox(height: 20),
            _buildSectionTitle('2. User Conduct'),
            _buildSectionContent(
              'You agree not to engage in any of the following prohibited activities:',
            ),
            _buildBulletPoint(
              'Posting nudity, pornography, or sexually explicit content',
            ),
            _buildBulletPoint('Harassment, bullying, or threats of any kind'),
            _buildBulletPoint(
              'Hate speech or discrimination based on race, gender, religion, etc.',
            ),
            _buildBulletPoint('Sharing personal information (yours or others)'),
            _buildBulletPoint('Impersonating any person or entity'),
            _buildBulletPoint('Any illegal activity or solicitation'),
            const SizedBox(height: 20),
            _buildSectionTitle('3. Account Use'),
            _buildSectionContent(
              'You are responsible for maintaining the confidentiality of your login credentials and for all activities that occur under your account.',
            ),
            _buildBulletPoint(
              'You must use your real identity on your profile',
            ),
            _buildBulletPoint(
              'You may not create multiple accounts or share your account with others',
            ),
            _buildBulletPoint(
              'You must provide accurate and current information',
            ),
            const SizedBox(height: 20),
            _buildSectionTitle('4. Content'),
            _buildSectionContent(
              'We reserve the right to remove any content that violates these Terms or that we deem inappropriate in our sole discretion.',
            ),
            _buildBulletPoint(
              'You retain ownership of content you post, but grant us a license to use it',
            ),
            _buildBulletPoint(
              'We are not responsible for user-generated content',
            ),
            const SizedBox(height: 20),
            _buildSectionTitle('5. Privacy'),
            _buildSectionContent(
              'Your personal data will be handled in accordance with our Privacy Policy. By using this app, you consent to the collection and use of your information as described in the Privacy Policy.',
            ),
            const SizedBox(height: 20),
            _buildSectionTitle('6. Termination'),
            _buildSectionContent(
              'We reserve the right to suspend or terminate your account at any time without notice if we believe you have violated these Terms of Service or for any other reason in our sole discretion.',
            ),
            const SizedBox(height: 20),
            _buildSectionTitle('7. Changes to Terms'),
            _buildSectionContent(
              'We may modify these Terms at any time. We will notify you of significant changes, and your continued use of the app constitutes acceptance of the updated Terms.',
            ),
            const SizedBox(height: 20),
            _buildSectionTitle('8. Disclaimer'),
            _buildSectionContent(
              'This app is provided "as is" without warranties of any kind. We do not guarantee that the app will be secure or available at any particular time or location.',
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => _onAgreePressed(context),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('I Agree to the Terms of Service'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildSectionContent(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(text, style: const TextStyle(fontSize: 16)),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, top: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• '),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  void _onAgreePressed(BuildContext context) {
    // Return to signup screen with agreement status
    // This assumes you're pushing this screen from signup
    // and want to return with a result
    Navigator.of(context).pop(true);

    // If using GoRouter and you need to go back to a specific route:
    // context.go('/signup');
    // or if you want to replace the current route:
    // context.replace('/signup');
  }
}

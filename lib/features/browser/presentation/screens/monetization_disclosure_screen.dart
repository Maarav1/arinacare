// lib/features/browser/presentation/screens/monetization_disclosure_screen.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:arina_cave/features/browser/domain/models/browser_settings.dart';

class MonetizationDisclosureScreen extends StatelessWidget {
  const MonetizationDisclosureScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Monetization Disclosure'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Clear header
            const Text(
              'How This Browser is Funded',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Search disclosure
            Card(
              color: Colors.grey[900],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.search, color: Colors.blue),
                        const SizedBox(width: 10),
                        const Text(
                          'Search Results',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'This browser may earn compensation when you use search features. '
                      'Search results come from third-party providers who may pay for placement.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.blue[900],
                      child: const Text(
                        '🔍 Search results marked as "Sponsored" are paid placements',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Ads disclosure
            Card(
              color: Colors.grey[900],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.ads_click, color: Colors.amber),
                        const SizedBox(width: 10),
                        const Text(
                          'Advertising',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'This browser shows advertisements to support free development. '
                      'Ads are clearly labeled and come from Google AdMob.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.amber[900],
                      child: const Text(
                        '📢 All ads are clearly marked. You can adjust ad frequency in settings.',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Privacy section
            Card(
              color: Colors.grey[900],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.privacy_tip, color: Colors.green),
                        const SizedBox(width: 10),
                        const Text(
                          'Your Privacy',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'We track anonymous usage metrics to improve the browser. '
                      'You can disable analytics in settings.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'We do NOT track:',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 5),
                    const Row(
                      children: [
                        Icon(Icons.check, color: Colors.green, size: 16),
                        SizedBox(width: 8),
                        Text('Search queries', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                    const Row(
                      children: [
                        Icon(Icons.check, color: Colors.green, size: 16),
                        SizedBox(width: 8),
                        Text('Browsing history', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                    const Row(
                      children: [
                        Icon(Icons.check, color: Colors.green, size: 16),
                        SizedBox(width: 8),
                        Text('Personal data', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Acknowledge button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () {
                  _recordDisclosureAcknowledgment();
                  Navigator.pop(context);
                },
                child: const Text(
                  'I Understand',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
            
            const SizedBox(height: 10),
            
            TextButton(
              onPressed: () {
                // Open privacy policy
              },
              child: const Text(
                'View Full Privacy Policy',
                style: TextStyle(color: Colors.blue),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _recordDisclosureAcknowledgment() async {
    final settingsBox = await Hive.openBox<BrowserSettings>('browser_settings');
    var settings = settingsBox.get('main');
    
    settings ??= BrowserSettings();
    
    settings.recordMonetizationDisclosure();
    await settingsBox.put('main', settings);
  }
}
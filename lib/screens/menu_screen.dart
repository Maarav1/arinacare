import 'package:arina_cave/screens/home_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User profile section
          if (currentUser != null)
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUser.uid)
                  .get(),
              builder: (context, snapshot) {
                String userName = 'User';
                String? profileImageUrl;
                
                if (snapshot.hasData && snapshot.data!.exists) {
                  final userData = snapshot.data!;
                  userName = userData['fullName'] ?? 
                            userData['email']?.toString().split('@')[0] ?? 
                            'User';
                  profileImageUrl = userData['profilePictureUrl'];
                }

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundImage: profileImageUrl != null
                          ? CachedNetworkImageProvider(profileImageUrl)
                          : null,
                      backgroundColor: Colors.blue.shade100,
                      child: profileImageUrl == null
                          ? Text(
                              userName[0].toUpperCase(),
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    title: Text(
                      userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Text(currentUser.email ?? ''),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/profile'),
                  ),
                );
              },
            ),

          const SizedBox(height: 20),
          
          // Main Menu Items
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Features',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          _buildMenuItem(
            context,
            icon: Icons.smart_toy,
            iconColor: Colors.purple,
            title: 'AI Assistant',
            subtitle: 'Get help from AI assistant',
            route: '/ai',
          ),
          
          _buildMenuItem(
  context,
  icon: Icons.newspaper,
  iconColor: Colors.grey, // Different color
  title: 'Web News',
  subtitle: 'Browse news websites',
  route: '/news', // This goes to WebView news
),

_buildMenuItem(
  context,
  icon: Icons.public,
  iconColor: Colors.blue,  // Browser color
  title: 'ArinaCave Browser',
  subtitle: 'Browse the web with ArinaCave browser',
  route: '/browser',
),

// New NewsAPI Screen
_buildMenuItem(
  context,
  icon: Icons.article,
  iconColor: Colors.blueAccent, // Different color
  title: 'Smart News',
  subtitle: 'Fast news from multiple sources',
  route: '/news-api', // This goes to NewsAPI screen
),
          
          // Add Radio menu item here
          _buildMenuItem(
            context,
            icon: Icons.radio,
            iconColor: Colors.red, // Radio icon color
            title: 'Radio',
            subtitle: 'Listen to radio stations',
            route: '/radio', // Add this route to your GoRouter configuration
          ),
          
          _buildMenuItem(
            context,
            icon: Icons.settings,
            iconColor: Colors.grey,
            title: 'Settings',
            subtitle: 'App settings and preferences',
            route: '/settings',
          ),
          
          _buildMenuItem(
            context,
            icon: Icons.help,
            iconColor: Colors.orange,
            title: 'Help & Support',
            subtitle: 'Get help and contact support',
            route: '/help',
          ),
          
          _buildMenuItem(
            context,
            icon: Icons.info,
            iconColor: Colors.teal,
            title: 'About',
            subtitle: 'About ArinaCave app',
            route: '/about',
          ),
          _buildMenuItem(
  context,
  icon: Icons.storage,
  iconColor: Colors.deepPurple,
  title: 'SQL Database',
  subtitle: 'Manage local SQL database',
  route: '/sql',
),
          
          _buildMenuItem(
            context,
            icon: Icons.privacy_tip,
            iconColor: Colors.green,
            title: 'Privacy Policy',
            subtitle: 'View our privacy policy',
            route: '/privacy',
          ),
          
          _buildMenuItem(
            context,
            icon: Icons.description,
            iconColor: Colors.indigo,
            title: 'Terms of Service',
            subtitle: 'Read terms and conditions',
            route: '/terms',
          ),
          
          const SizedBox(height: 20),
          
          // Coming Soon Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Coming Soon',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🚀 More Features Coming Soon!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'We\'re cooking up something amazing for you! '
                    'Stay tuned for exciting updates and new functionalities.',
                    style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.5),
                  ),
                  const SizedBox(height: 15),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('We\'ll notify you when new features arrive!'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.notifications_active),
                    label: const Text('Notify Me'),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 30),
          
          // Sign Out Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              onPressed: () async {
                try {
                  if (currentUser != null) {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUser.uid)
                        .update({
                      'isOnline': false,
                      'lastSeen': DateTime.now(),
                    });
                  }
                  
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    context.go('/login');
                  }
                } catch (e) {
                  if (context.mounted) {
                    AppUtils.showSnackBar(context, 'Error signing out', isError: true);
                  }
                }
              },
              icon: const Icon(Icons.exit_to_app),
              label: const Text('Sign Out'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.red,
                backgroundColor: Colors.red.shade50,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Version info
          Center(
            child: Text(
              'ArinaCave v1.0.0',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String route,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withValues(), 
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () => context.push(route),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_functions/cloud_functions.dart';

class NewMessageScreen extends StatefulWidget {
  const NewMessageScreen({super.key});

  @override
  State<NewMessageScreen> createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends State<NewMessageScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  bool _isLoading = false;
  String? _errorMessage;

  Future<List<Map<String, dynamic>>> _getMatchedUsers() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      setState(() {
        _errorMessage = "User not authenticated";
      });
      return [];
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Use Cloud Function to get matched users
      final HttpsCallable callable = _functions.httpsCallable(
        'getMatchedUsers',
      );
      final result = await callable.call();

      if (result.data['success'] == true) {
        final List<dynamic> matchedUsers = result.data['matchedUsers'];
        return matchedUsers.map((user) {
          return {
            'id': user['id'] ?? '',
            'name': user['name'] ?? 'Unknown',
            'avatarUrl': user['avatarUrl'] ?? '',
          };
        }).toList();
      } else {
        setState(() {
          _errorMessage =
              'Failed to get matched users: ${result.data['message']}';
        });
        return [];
      }
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.message}';
      });
      return [];
    } catch (e) {
      setState(() {
        _errorMessage = 'Unexpected error: $e';
      });
      return [];
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _refreshMatchedUsers() {
    setState(() {
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Message'),
        actions: [
          if (_errorMessage != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshMatchedUsers,
              tooltip: 'Retry',
            ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _refreshMatchedUsers,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              )
              : FutureBuilder<List<Map<String, dynamic>>>(
                future: _getMatchedUsers(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading matches: ${snapshot.error}',
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontSize: 16,
                        ),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text(
                        'No matches yet.',
                        style: TextStyle(fontSize: 16),
                      ),
                    );
                  }

                  final users = snapshot.data!;

                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    separatorBuilder: (_, __) => const Divider(),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];

                      return ListTile(
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundImage:
                              user['avatarUrl'].isNotEmpty
                                  ? CachedNetworkImageProvider(
                                    user['avatarUrl'],
                                  )
                                  : null,
                          backgroundColor: theme.colorScheme.primary,
                          child:
                              user['avatarUrl'].isEmpty
                                  ? Text(
                                    user['name'].isNotEmpty
                                        ? user['name']
                                            .substring(0, 1)
                                            .toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  )
                                  : null,
                        ),
                        title: Text(
                          user['name'],
                          style: const TextStyle(fontSize: 16),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          final route =
                              '/chat/${user['id']}/${Uri.encodeComponent(user['name'])}';
                          context.push(route);
                        },
                      );
                    },
                  );
                },
              ),
    );
  }
}

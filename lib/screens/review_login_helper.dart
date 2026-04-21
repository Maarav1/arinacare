import 'package:flutter/material.dart';

class ReviewLoginHelper {
  // Prefill credentials for reviewers during development
  static void prefillReviewerCredentials(
    TextEditingController emailController,
    TextEditingController passwordController,
  ) {
    // Only prefill in debug mode for safety
    assert(() {
      emailController.text = 'reviewer@example.com';
      passwordController.text = 'review123';
      return true;
    }());
  }

  // Build a reviewer login button that appears only in debug mode
  static Widget buildReviewerLoginButton(
    BuildContext context,
    TextEditingController emailController,
    TextEditingController passwordController,
    VoidCallback? onLoginPressed,
  ) {
    return Builder(
      builder: (context) {
        // Only show in debug mode
        bool isDebug = false;
        assert(() {
          isDebug = true;
          return true;
        }());

        if (!isDebug) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(),
            border: Border.all(color: Colors.orange),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Text(
                'Reviewer Quick Access',
                style: TextStyle(
                  color: Colors.orange[800],
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    emailController.text = 'reviewer@example.com';
                    passwordController.text = 'review123';
                    // Optionally trigger login immediately
                    if (onLoginPressed != null) {
                      onLoginPressed();
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: BorderSide(color: Colors.orange),
                  ),
                  child: const Text(
                    'Fill Reviewer Credentials',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
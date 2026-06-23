// lib/widgets/responsive_scaffold.dart
import 'package:flutter/material.dart';

class ResponsiveScaffold extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;
  final bool useSafeArea;

  const ResponsiveScaffold({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
    this.useSafeArea = true,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    // Determine which layout to show
    Widget child;
    if (width >= 1200 && desktop != null) {
      child = desktop!;
    } else if (width >= 600 && tablet != null) {
      child = tablet!;
    } else {
      child = mobile;
    }

    if (useSafeArea) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 1200, // Max width on desktop
              ),
              child: child,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: child,
        ),
      ),
    );
  }
}

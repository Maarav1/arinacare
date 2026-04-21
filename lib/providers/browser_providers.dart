// lib/providers/browser_providers.dart
import 'package:flutter/material.dart';
import 'package:arina_cave/features/browser/presentation/controllers/web_tab_manager.dart';
import 'package:arina_cave/features/browser/engagement/services/ad_service.dart';
import 'package:provider/provider.dart';

class BrowserProviders extends StatelessWidget {
  final Widget child;
  
  const BrowserProviders({super.key, required this.child});
  
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => WebTabManager(),
          lazy: false,
        ),
        Provider(
          create: (_) => AdService(),
          lazy: false,
        ),
      ],
      child: child,
    );
  }
}
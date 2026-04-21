// lib/features/browser/domain/models/browser_tab.dart
import 'package:hive/hive.dart';

part 'browser_tab.g.dart';

@HiveType(typeId: 100)
class BrowserTab extends HiveObject {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String? initialUrl;
  
  @HiveField(2)
  final bool isIncognito;
  
  @HiveField(3)
  DateTime createdAt;
  
  @HiveField(4)
  DateTime lastAccessedAt;
  
  @HiveField(5)
  String? title;
  
  @HiveField(6)
  String? faviconUrl;
  
  @HiveField(7)
  double scrollPosition;
  
  BrowserTab({
    required this.id,
    this.initialUrl,
    this.isIncognito = false,
    this.title,
    this.faviconUrl,
    this.scrollPosition = 0.0,
  })  : createdAt = DateTime.now(),
        lastAccessedAt = DateTime.now();

  void updateLastAccess() {
    lastAccessedAt = DateTime.now();
    save();
  }
}
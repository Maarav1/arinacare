// lib/features/browser/domain/models/browser_settings.dart
import 'package:hive/hive.dart';

part 'browser_settings.g.dart';

@HiveType(typeId: 101)
class BrowserSettings extends HiveObject {
  @HiveField(0)
  bool showAds = true;
  
  @HiveField(1)
  String defaultSearchEngine = 'google';
  
  @HiveField(2)
  bool enableAdBlock = true;
  
  @HiveField(3)
  bool allowAnalytics = false;
  
  @HiveField(4)
  bool acceptTerms = false;
  
  @HiveField(5)
  DateTime? termsAcceptedDate;
  
  @HiveField(6)
  bool seenMonetizationDisclosure = false;
  
  @HiveField(7)
  bool desktopMode = false;
  
  @HiveField(8)
  bool javascriptEnabled = true;
  
  @HiveField(9)
  bool cookiesEnabled = true;
  
  @HiveField(10)
  String userAgent = 'default';
  
  // Policy compliance methods
  void acceptTermsAndConditions() {
    acceptTerms = true;
    termsAcceptedDate = DateTime.now();
    save();
  }
  
  void recordMonetizationDisclosure() {  // This is the missing method!
    seenMonetizationDisclosure = true;
    save();
  }
  
  void toggleAds() {
    showAds = !showAds;
    save();
  }
  
  void toggleAdBlock() {
    enableAdBlock = !enableAdBlock;
    save();
  }
  
  void toggleAnalytics() {
    allowAnalytics = !allowAnalytics;
    save();
  }
}
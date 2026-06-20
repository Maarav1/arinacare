// lib/main_web.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'main.dart' as app;

void main() {
  // Disable platform-specific features on web
  if (kIsWeb) {
    // Override or disable web-incompatible features
  }
  app.main();
}

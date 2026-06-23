import 'dart:async';
import 'dart:typed_data';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:flutter/foundation.dart' show kDebugMode;

/// Helper class for picking images on web platform using package:web
class WebImageHelper {
  /// Picks an image from the user's device on web
  static Future<Uint8List?> pickImage() async {
    try {
      final completer = Completer<Uint8List?>();

      // Create file input element
      final input = web.HTMLInputElement();
      input.type = 'file';
      input.accept = 'image/*';
      input.style.display = 'none';
      web.document.body?.append(input);

      // Handle file selection using addEventListener
      input.addEventListener(
        'change',
        ((JSAny? _) {
          final files = input.files;
          if (files != null && files.length > 0) {
            final file = files.item(0);
            if (file != null) {
              final reader = web.FileReader();

              reader.addEventListener(
                'load',
                ((JSAny? _) {
                  final result = reader.result;
                  if (result != null) {
                    try {
                      final bytes = _arrayBufferToUint8List(result);
                      completer.complete(bytes);
                    } catch (e) {
                      completer.complete(null);
                    }
                  } else {
                    completer.complete(null);
                  }
                  input.remove();
                }).toJS,
              );

              reader.addEventListener(
                'error',
                ((JSAny? _) {
                  completer.complete(null);
                  input.remove();
                }).toJS,
              );

              reader.readAsArrayBuffer(file);
            } else {
              completer.complete(null);
              input.remove();
            }
          } else {
            completer.complete(null);
            input.remove();
          }
        }).toJS,
      );

      // Trigger file picker
      input.click();

      return await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          input.remove();
          return null;
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error picking web image: $e');
      }
      return null;
    }
  }

  /// Converts JS ArrayBuffer to Dart Uint8List
  static Uint8List _arrayBufferToUint8List(dynamic arrayBuffer) {
    final buffer = arrayBuffer as JSArrayBuffer;
    return buffer.toDart.asUint8List();
  }
}

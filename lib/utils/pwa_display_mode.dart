import 'dart:html' as html show window;
// flutter pub add web - then import 'package:web/web.dart' for web-only features
import 'package:flutter/foundation.dart';

class PwaDisplayModeProvider extends ChangeNotifier {
  bool _isStandalone = false;
  bool get isStandalone => _isStandalone;

  PwaDisplayModeProvider() {
    _detectDisplayMode();
    // Listen for display mode changes
    if (kIsWeb) {
      html.window.matchMedia('(display-mode: standalone)').addEventListener('change', (_) {
        _detectDisplayMode();
      });
    }
  }

  void _detectDisplayMode() {
    if (kIsWeb) {
      _isStandalone = html.window.matchMedia('(display-mode: standalone)').matches ||
          html.window.matchMedia('(display-mode: fullscreen)').matches ||
          html.window.matchMedia('(display-mode: minimal-ui)').matches;
      notifyListeners();
    }
  }
}
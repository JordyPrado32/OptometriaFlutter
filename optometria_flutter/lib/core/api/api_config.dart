import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _dartDefineBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    if (_dartDefineBaseUrl.trim().isNotEmpty) {
      return _dartDefineBaseUrl.trim();
    }

    if (kIsWeb) {
      return 'http://localhost:3000';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:3000';
      default:
        return 'http://localhost:3000';
    }
  }
}

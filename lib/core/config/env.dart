import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

enum Environment { development, staging, production }

/// What the `.env.*` file the entry point names says: where the services
/// are, and the per-flavor switches. Nothing secret lives here — the app's
/// services take no token.
class Env {
  static late Environment _environment;
  static Environment get environment => _environment;

  Env._();

  static Future<void> init(Environment environment) async {
    _environment = environment;
    final fileName = switch (environment) {
      Environment.development => '.env.development',
      Environment.staging => '.env.staging',
      Environment.production => '.env.production',
    };

    await dotenv.load(fileName: fileName);
    _logConfiguration(fileName);
  }

  static void _logConfiguration(String fileName) {
    if (kReleaseMode && !enableLogs) return;

    final flavor = _environment.name.toUpperCase();
    final banner =
        '''
╔══════════════════════════════════════════════════════════╗
║  🚀 App launched — flavor: $flavor
╠══════════════════════════════════════════════════════════╣
║  env file        : $fileName
║  API_BASE_URL    : $apiBaseUrl
║  ENABLE_LOGS     : $enableLogs
║  ENABLE_ANALYTICS: $enableAnalytics
║  ENABLE_CRASH    : $enableCrashReporting
╚══════════════════════════════════════════════════════════╝''';

    debugPrint(banner);
  }

  /// The host every endpoint in `ApiEndpoints` is on, with no trailing
  /// slash. Throws rather than guesses when the file leaves it out: every
  /// request would go to the wrong place, and the first one is the time to
  /// find out.
  static String get apiBaseUrl {
    final url = dotenv.env['API_BASE_URL']?.trim();
    if (url == null || url.isEmpty) {
      throw StateError('API_BASE_URL is not set in the env file');
    }
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  static bool get enableLogs => dotenv.env['ENABLE_LOGS'] == 'true';
  static bool get enableAnalytics => dotenv.env['ENABLE_ANALYTICS'] == 'true';
  static bool get enableCrashReporting =>
      dotenv.env['ENABLE_CRASH_REPORTING'] == 'true';

  static bool get isDevelopment => _environment == Environment.development;
  static bool get isStaging => _environment == Environment.staging;
  static bool get isProduction => _environment == Environment.production;
}

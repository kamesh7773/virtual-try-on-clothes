class AppConstants {
  AppConstants._();

  static const String appName = 'Mirror';

  // Design reference size for ScreenUtil
  static const double designWidth = 375;
  static const double designHeight = 812;

  // Network
  static const Duration connectionTimeout = Duration(seconds: 300);
  static const Duration receiveTimeout = Duration(seconds: 300);
  static const Duration sendTimeout = Duration(seconds: 300);
}

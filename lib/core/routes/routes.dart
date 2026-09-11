class Routes {
  Routes._();

  /// The two-option front door.
  static const String home = '/';

  static const String tryOn = '/try-on';

  /// The in-app browser. Takes a `WebViewScreenArgs`.
  static const String webView = '/web-view';

  /// Every page the in-app browser has opened.
  static const String urlHistory = '/url-history';

  /// One visit in full. Takes a `UrlVisitDetailArgs`.
  static const String urlVisitDetail = '/url-visit';
}

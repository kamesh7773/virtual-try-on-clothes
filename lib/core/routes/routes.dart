class Routes {
  Routes._();

  /// The browser and history, listed. Not on any path a shopper takes.
  static const String home = '/';

  /// The in-app browser. Takes a `WebViewScreenArgs`.
  static const String webView = '/web-view';

  /// Every page the in-app browser has opened.
  static const String urlHistory = '/url-history';

  /// One visit in full. Takes a `UrlVisitDetailArgs`.
  static const String urlVisitDetail = '/url-visit';

  // ─── Style Me (the Dick's kiosk flow) ──────────────────────────────

  /// The model video and STYLE ME. What the app opens on.
  static const String styleIntro = '/style';

  /// The body snapshot: camera, MEN'S / WOMEN'S, capture.
  static const String styleGetReady = '/style/get-ready';

  /// The five departments, after the photo is taken.
  static const String styleExplore = '/style/explore';

  /// The apparel shelves.
  static const String styleApparel = '/style/apparel';

  /// The four looks styled from the photo.
  static const String stylePreviews = '/style/previews';
}

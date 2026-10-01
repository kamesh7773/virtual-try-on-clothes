import '../config/env.dart';

/// Every service the app talks to. All on [Env.apiBaseUrl], all full URLs
/// — the Dio client has no base URL, since the repositories also fetch from
/// retailers' image CDNs through it — and none of them takes a token.
class ApiEndpoints {
  ApiEndpoints._();

  static String _url(String path) => '${Env.apiBaseUrl}$path';

  /// Try-on service the in-app browser posts products to.
  ///
  /// POST, `multipart/form-data` — `image` (the product shot as a file),
  /// `category` (one of the four; the scene only) and `photo_id` (the
  /// shopper's upload from [stylePhoto]). Answers `{ image, url }`, or
  /// `404 photo_expired` when the id is gone.
  static String get tryOn => _url('/api/tryon');

  // The Style Me app API, documented in `docs/app-api.md`.

  /// Uploads the shopper's snapshot once, for a `photo_id` good for six
  /// hours. POST, `multipart/form-data` — `photo` (the file). Answers
  /// `{ photo_id, expires_at, expires_in, ... }`.
  ///
  /// Also the base of `GET`/`DELETE /{photo_id}`.
  static String get stylePhoto => _url('/api/app/photo');

  /// Styles the uploaded photo into one look.
  ///
  /// POST, `application/json` — `{ photo_id, category, variant, dept }`.
  /// Answers `{ image, shop_url, cached, test, ... }`. Slow: a fresh look
  /// takes 12–50s, and the server gives its provider 150s.
  static String get styleLook => _url('/api/app/generate');

  /// Where a finished browsing flow is reported.
  ///
  /// POST, `application/json` — the envelope documented in
  /// `docs/url-history-payload.md`, carrying the visits of one flow.
  static String get history => _url('/api/history');
}

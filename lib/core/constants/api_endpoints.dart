import '../config/env.dart';

class ApiEndpoints {
  ApiEndpoints._();

  /// Decart REST base URL — `https://api.decart.ai` (set per flavor).
  static String get baseUrl => Env.apiBaseUrl;

  /// Decart signalling base URL — `wss://api.decart.ai`. The native SDKs take
  /// this directly; nothing in Dart opens this socket itself.
  static String get wsBaseUrl => Env.apiWsBaseUrl;

  /// POST — mints a short-lived client token. Authenticated with the
  /// long-lived key via the `x-api-key` header, and returns
  /// `{ apiKey, token, expiresAt, permissions, constraints }`.
  ///
  /// Decart rejects this call when authenticated with a client token
  /// (403), so it can only be made from a trusted context: a dev build
  /// holding the real key, or the backend named by [Env.tokenEndpoint].
  static const String createClientToken = '/v1/client/tokens';

  /// Header carrying the long-lived Decart API key.
  static const String apiKeyHeader = 'x-api-key';

  /// Try-on service the in-app browser posts products to. A full URL, not a
  /// path: it is a different host from Decart's, the same one in every
  /// flavor.
  ///
  /// POST, `multipart/form-data` — `category` (one of the four the service
  /// accepts) and `image` (the product shot as a file). Takes no token, and
  /// answers with the URL of the page to open.
  static const String tryOn = 'https://mirror.maxaix.com/api/tryon';
}

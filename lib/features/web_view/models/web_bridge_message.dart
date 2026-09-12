import 'dart:convert';

import 'web_product.dart';
import 'web_tap_report.dart';

/// Something the page told the app over the JavaScript bridge.
///
/// The bridge is reachable by every script on the page, so parsing is total:
/// anything that is not one of these shapes is dropped rather than trusted.
sealed class WebBridgeMessage {
  const WebBridgeMessage();

  static WebBridgeMessage? tryParse(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;

    if (decoded['type'] == 'product') {
      // A page that no longer shows a product says so, so the overlay can go
      // away without waiting for a navigation.
      return WebProductMessage(WebProduct.tryParse(decoded));
    }

    final report = WebTapReport.tryParse(decoded);
    return report == null ? null : WebTapMessage(report);
  }
}

/// The user tapped something.
final class WebTapMessage extends WebBridgeMessage {
  final WebTapReport report;

  const WebTapMessage(this.report);
}

/// The page is, or is no longer, showing a product.
final class WebProductMessage extends WebBridgeMessage {
  /// Null when the page has nothing to offer.
  final WebProduct? product;

  const WebProductMessage(this.product);
}

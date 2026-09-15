import 'dart:convert';

import 'web_product.dart';
import 'web_purchase_options.dart';
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

    if (decoded['type'] == 'options') {
      final options = WebPurchaseOptions.tryParse(decoded);
      return options == null ? null : WebOptionsMessage(options);
    }

    if (decoded['type'] == 'checkout') {
      final status = WebCheckoutStatus.fromName(decoded['status']);
      if (status == null) return null;
      final reason = decoded['reason'];
      final cartUrl = decoded['cartUrl'];
      return WebCheckoutMessage(
        status,
        reason: reason is String && reason.trim().isNotEmpty
            ? reason.trim()
            : null,
        cartUrl: cartUrl is String && cartUrl.isNotEmpty ? cartUrl : null,
      );
    }

    if (decoded['type'] == 'painted') {
      final url = decoded['url'];
      final uri = url is String ? Uri.tryParse(url) : null;
      if (uri == null || uri.host.isEmpty) return null;
      return WebPaintedMessage(uri);
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

/// The page has drawn its first content.
///
/// Sent once per document, the moment the browser reports a first
/// contentful paint — or, where it will not say, once the body has a height
/// and a couple of frames have gone by. This is what lifts the loading cover:
/// a retailer's `load` event can be tens of seconds behind its first paint,
/// and a page the user could already be reading is not worth hiding.
final class WebPaintedMessage extends WebBridgeMessage {
  /// Where the page was when it painted, so a report from a document being
  /// left can be told apart from the one being waited for.
  final Uri url;

  const WebPaintedMessage(this.url);
}

/// What the product page offers by way of buying: sizes, an add-to-cart
/// control, a cart link. Sent as the page fills in.
final class WebOptionsMessage extends WebBridgeMessage {
  final WebPurchaseOptions options;

  const WebOptionsMessage(this.options);
}

/// The page's answer to being asked to add the product to its cart.
final class WebCheckoutMessage extends WebBridgeMessage {
  final WebCheckoutStatus status;

  /// The page's own words for a refusal, when it had any.
  final String? reason;

  /// Where the cart is, as the page knew it at the time.
  final String? cartUrl;

  const WebCheckoutMessage(this.status, {this.reason, this.cartUrl});
}

import 'package:flutter/foundation.dart';

/// A product the browser found on the page it is showing.
///
/// Read out of the page's own structured data — the `Product` entry in its
/// JSON-LD, or its OpenGraph tags — rather than guessed at from the layout,
/// which changes with every redesign.
@immutable
class WebProduct {
  /// The page the product was found on.
  final String pageUrl;

  final String title;

  /// The product shot. This is what the try-on API is given.
  final String imageUrl;

  final String? brand;
  final String? sku;
  final String? price;
  final String? currency;

  const WebProduct({
    required this.pageUrl,
    required this.title,
    required this.imageUrl,
    this.brand,
    this.sku,
    this.price,
    this.currency,
  });

  /// Returns null unless the page gave both a name and an image — without
  /// either there is nothing to show in the overlay, and nothing to send.
  static WebProduct? tryParse(Map<String, dynamic> json) {
    final pageUrl = _text(json['url']);
    final title = _text(json['title']);
    final imageUrl = _text(json['image']);
    if (pageUrl == null || title == null || imageUrl == null) return null;
    if (!imageUrl.startsWith('http')) return null;

    return WebProduct(
      pageUrl: pageUrl,
      title: title,
      imageUrl: imageUrl,
      brand: _text(json['brand']),
      sku: _text(json['sku']),
      price: _text(json['price']),
      currency: _text(json['currency']),
    );
  }

  /// The price as it should read, e.g. "USD 79.99". Null when the page did
  /// not say.
  String? get formattedPrice {
    if (price == null) return null;
    return currency == null ? price : '$currency $price';
  }

  static String? _text(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    // The page controls this; a runaway string would be rendered and sent.
    return trimmed.length <= 300 ? trimmed : trimmed.substring(0, 300);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WebProduct &&
          other.pageUrl == pageUrl &&
          other.title == title &&
          other.imageUrl == imageUrl &&
          other.brand == brand &&
          other.sku == sku &&
          other.price == price &&
          other.currency == currency;

  @override
  int get hashCode =>
      Object.hash(pageUrl, title, imageUrl, brand, sku, price, currency);
}

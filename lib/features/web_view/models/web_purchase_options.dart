import 'package:flutter/foundation.dart';

/// One size a product page offers.
@immutable
class WebSizeOption {
  /// As the page writes it: "S", "XL", "32", "10.5".
  final String label;

  /// False for a size the page has crossed out or disabled.
  final bool available;

  /// True for the size the page already has selected, if it shows one.
  final bool selected;

  const WebSizeOption({
    required this.label,
    this.available = true,
    this.selected = false,
  });

  static WebSizeOption? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final label = json['label'];
    if (label is! String) return null;
    final trimmed = label.trim();
    if (trimmed.isEmpty || trimmed.length > 12) return null;
    return WebSizeOption(
      label: trimmed,
      available: json['available'] != false,
      selected: json['selected'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WebSizeOption &&
          other.label == label &&
          other.available == available &&
          other.selected == selected;

  @override
  int get hashCode => Object.hash(label, available, selected);
}

/// One colour a product page offers, as a swatch.
@immutable
class WebColorOption {
  /// As the page names it: "Football Dog Convo Red".
  final String label;

  /// The swatch's own picture, when it has one to show.
  final String? imageUrl;

  final bool available;
  final bool selected;

  const WebColorOption({
    required this.label,
    this.imageUrl,
    this.available = true,
    this.selected = false,
  });

  static WebColorOption? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final label = json['label'];
    if (label is! String) return null;
    final trimmed = label.trim();
    if (trimmed.isEmpty || trimmed.length > 80) return null;

    final image = json['image'];
    final imageUri = image is String ? Uri.tryParse(image) : null;
    final imageIsWeb =
        imageUri != null &&
        imageUri.host.isNotEmpty &&
        (imageUri.scheme == 'http' || imageUri.scheme == 'https');

    return WebColorOption(
      label: trimmed,
      imageUrl: imageIsWeb ? imageUri.toString() : null,
      available: json['available'] != false,
      selected: json['selected'] == true,
    );
  }

  /// Whether this is the colour called [name] — as the page's URL or a
  /// shopper would write it, give or take spacing, case and punctuation.
  bool isCalled(String name) {
    final mine = normalizeOptionName(label);
    final theirs = normalizeOptionName(name);
    if (mine.isEmpty || theirs.isEmpty) return false;
    return mine == theirs || mine.contains(theirs) || theirs.contains(mine);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WebColorOption &&
          other.label == label &&
          other.imageUrl == imageUrl &&
          other.available == available &&
          other.selected == selected;

  @override
  int get hashCode => Object.hash(label, imageUrl, available, selected);
}

/// Lower-cased with everything but letters and digits dropped, so that
/// "Football Dog Convo Red", "football-dog-convo-red" and the swatch's alt
/// text all come out the same.
String normalizeOptionName(String name) =>
    name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// What a product page lets the user do about buying: the colours and sizes
/// it offers, whether it has an add-to-cart control, and where its cart
/// lives.
///
/// Read off the page by the bridge script and sent as it changes — a page
/// that arrives in pieces grows a size row some seconds after its product.
/// Everything here is a best reading of someone else's layout, which is why
/// the checkout built on it falls back to the page itself when a reading
/// comes up empty.
@immutable
class WebPurchaseOptions {
  /// The page these were read from, so options from a page being left are
  /// not taken for the one now showing.
  final String pageUrl;

  /// In the order the page shows them. Empty when the page has no size row,
  /// which is also what a one-size product looks like.
  final List<WebSizeOption> sizes;

  /// The colour swatches, in the page's order. Empty for a page with no
  /// colour to choose, and for one whose swatches could not be read.
  final List<WebColorOption> colors;

  /// Whether the page has an add-to-cart control the script can press.
  final bool canAddToCart;

  /// The page's own link to its cart, when it shows one.
  final String? cartUrl;

  const WebPurchaseOptions({
    required this.pageUrl,
    this.sizes = const [],
    this.colors = const [],
    this.canAddToCart = false,
    this.cartUrl,
  });

  static WebPurchaseOptions? tryParse(Map<String, dynamic> json) {
    final pageUrl = json['url'];
    if (pageUrl is! String || pageUrl.isEmpty) return null;

    final rawSizes = json['sizes'];
    final sizes = rawSizes is List
        ? rawSizes.map(WebSizeOption.tryParse).nonNulls.toList(growable: false)
        : const <WebSizeOption>[];

    final rawColors = json['colors'];
    final colors = rawColors is List
        ? rawColors
              .map(WebColorOption.tryParse)
              .nonNulls
              .toList(growable: false)
        : const <WebColorOption>[];

    final cartUrl = json['cartUrl'];
    final cart = cartUrl is String ? Uri.tryParse(cartUrl) : null;
    final cartIsWeb =
        cart != null &&
        cart.host.isNotEmpty &&
        (cart.scheme == 'http' || cart.scheme == 'https');

    return WebPurchaseOptions(
      pageUrl: pageUrl,
      sizes: sizes,
      colors: colors,
      canAddToCart: json['addToCart'] == true,
      cartUrl: cartIsWeb ? cart.toString() : null,
    );
  }

  /// The size the page has selected already, if it shows one.
  WebSizeOption? get selectedSize {
    for (final size in sizes) {
      if (size.selected) return size;
    }
    return null;
  }

  /// Whether the user has to pick a size before the page will add to cart.
  bool get needsSize => sizes.isNotEmpty && selectedSize == null;

  WebColorOption? get selectedColor {
    for (final color in colors) {
      if (color.selected) return color;
    }
    return null;
  }

  /// The colour the page's own address asks for, e.g. `?color=Red` — which
  /// is the colour the product shot, and so the try-on, was of.
  String? get colorInUrl {
    final query = Uri.tryParse(pageUrl)?.queryParameters;
    if (query == null) return null;
    for (final key in const ['color', 'colour', 'colorName', 'dwvar_color']) {
      final value = query[key]?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  /// The colour to buy without asking: the one the page has selected, or
  /// failing that the one its address names, if it is on offer. Null when
  /// the page offers colours and neither settles it.
  WebColorOption? get resolvedColor {
    final selected = selectedColor;
    if (selected != null) return selected;
    final wanted = colorInUrl;
    if (wanted == null) return null;
    for (final color in colors) {
      if (color.available && color.isCalled(wanted)) return color;
    }
    return null;
  }

  /// Whether the user has to be asked for a colour.
  bool get needsColor => colors.isNotEmpty && resolvedColor == null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WebPurchaseOptions &&
          other.pageUrl == pageUrl &&
          listEquals(other.sizes, sizes) &&
          listEquals(other.colors, colors) &&
          other.canAddToCart == canAddToCart &&
          other.cartUrl == cartUrl;

  @override
  int get hashCode => Object.hash(
    pageUrl,
    Object.hashAll(sizes),
    Object.hashAll(colors),
    canAddToCart,
    cartUrl,
  );
}

/// How the page answered a request to add the product to its cart.
enum WebCheckoutStatus {
  /// The cart took it.
  added,

  /// The page said no — no size chosen, out of stock, a control missing.
  failed,

  /// Nothing said either way within the time allowed. Usually the item is
  /// in the cart and the page just did not announce it.
  timeout;

  static WebCheckoutStatus? fromName(Object? name) {
    for (final status in values) {
      if (status.name == name) return status;
    }
    return null;
  }
}

import 'package:flutter/foundation.dart';

/// One value a product page offers for one of its attributes: a size, a
/// colour, an inseam length, a shoe width.
@immutable
class WebOptionValue {
  /// As the page writes it: "S", "XL", "32", "Football Dog Convo Red".
  final String label;

  /// The value's own picture, when the page draws it as a swatch.
  final String? imageUrl;

  /// False for a value the page has crossed out or disabled.
  final bool available;

  /// True for the value the page already has selected, if it shows one.
  final bool selected;

  const WebOptionValue({
    required this.label,
    this.imageUrl,
    this.available = true,
    this.selected = false,
  });

  static WebOptionValue? tryParse(Object? json) {
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

    return WebOptionValue(
      label: trimmed,
      imageUrl: imageIsWeb ? imageUri.toString() : null,
      available: json['available'] != false,
      selected: json['selected'] == true,
    );
  }

  /// Whether this is the value called [name] — as the page's URL or a
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
      other is WebOptionValue &&
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

/// One attribute the page wants settled before it will sell: "Color",
/// "Size", "Inseam", "Width". Whatever the page calls it, with the values it
/// offers in the page's order.
///
/// Pages differ in which of these they have — a polo has colour and size, a
/// pair of trousers adds an inseam, a shoe a width — which is why they are
/// read as a list rather than as two fixed fields.
@immutable
class WebOptionGroup {
  /// As the page heads the row: "Color", "Size", "Inseam".
  final String name;

  final List<WebOptionValue> values;

  const WebOptionGroup({required this.name, required this.values});

  static WebOptionGroup? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final name = json['name'];
    if (name is! String) return null;
    final trimmed = name.replaceAll(RegExp(r'\s*:\s*$'), '').trim();
    if (trimmed.isEmpty || trimmed.length > 30) return null;

    final raw = json['values'];
    final values = raw is List
        ? raw.map(WebOptionValue.tryParse).nonNulls.toList(growable: false)
        : const <WebOptionValue>[];
    if (values.isEmpty) return null;

    return WebOptionGroup(name: trimmed, values: values);
  }

  /// Whether this is the page's colour row, under whatever spelling.
  bool get isColor => RegExp(r'^colou?r', caseSensitive: false).hasMatch(name);

  /// Whether the page draws these as pictures rather than words. Decided
  /// by the values, not the name: a "Pattern" row of swatches is one too.
  bool get isSwatch =>
      values.where((v) => v.imageUrl != null).length * 2 >= values.length;

  /// The value the page has selected already, if it shows one.
  WebOptionValue? get selected {
    for (final value in values) {
      if (value.selected) return value;
    }
    return null;
  }

  /// The value called [name], if it is on offer: the one spelt the same
  /// first, and only failing that one that contains it — "L" must not find
  /// "XL" just because it comes earlier in the row.
  WebOptionValue? find(String name) {
    final wanted = normalizeOptionName(name);
    for (final value in values) {
      if (normalizeOptionName(value.label) == wanted) return value;
    }
    for (final value in values) {
      if (value.isCalled(name)) return value;
    }
    return null;
  }

  /// Whether this is the group called [other], give or take case, spacing
  /// and a trailing colon.
  bool isNamed(String other) =>
      normalizeOptionName(name) == normalizeOptionName(other);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WebOptionGroup &&
          other.name == name &&
          listEquals(other.values, values);

  @override
  int get hashCode => Object.hash(name, Object.hashAll(values));
}

/// What a product page lets the user do about buying: the attributes it
/// wants chosen, whether it has an add-to-cart control, and where its cart
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

  /// The attributes the page asks for, in the order the page shows them —
  /// which is the order it wants them chosen in. Empty for a page with
  /// nothing to choose, and for one whose controls could not be read.
  final List<WebOptionGroup> groups;

  /// Whether the page has an add-to-cart control the script can press.
  final bool canAddToCart;

  /// The page's own link to its cart, when it shows one.
  final String? cartUrl;

  const WebPurchaseOptions({
    required this.pageUrl,
    this.groups = const [],
    this.canAddToCart = false,
    this.cartUrl,
  });

  static WebPurchaseOptions? tryParse(Map<String, dynamic> json) {
    final pageUrl = json['url'];
    if (pageUrl is! String || pageUrl.isEmpty) return null;

    final raw = json['groups'];
    final parsed = raw is List
        ? raw.map(WebOptionGroup.tryParse).nonNulls
        : const Iterable<WebOptionGroup>.empty();
    // Two rows under the same heading are one reading gone wrong; the
    // first is kept, as the one nearer the top of the page.
    final groups = <WebOptionGroup>[];
    for (final group in parsed) {
      if (groups.any((g) => g.isNamed(group.name))) continue;
      groups.add(group);
    }

    final cartUrl = json['cartUrl'];
    final cart = cartUrl is String ? Uri.tryParse(cartUrl) : null;
    final cartIsWeb =
        cart != null &&
        cart.host.isNotEmpty &&
        (cart.scheme == 'http' || cart.scheme == 'https');

    return WebPurchaseOptions(
      pageUrl: pageUrl,
      groups: List.unmodifiable(groups),
      canAddToCart: json['addToCart'] == true,
      cartUrl: cartIsWeb ? cart.toString() : null,
    );
  }

  WebOptionGroup? group(String name) {
    for (final group in groups) {
      if (group.isNamed(name)) return group;
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

  /// The value of [group] that can be bought without asking: the one the
  /// page has selected, or for the colour row the one the address names,
  /// if it is on offer. Null when the user has to be asked.
  WebOptionValue? resolved(WebOptionGroup group) {
    final selected = group.selected;
    if (selected != null) return selected;
    if (!group.isColor) return null;
    final wanted = colorInUrl;
    if (wanted == null) return null;
    final named = group.find(wanted);
    return named != null && named.available ? named : null;
  }

  /// The choices that need no asking, by group name, in the page's order.
  Map<String, String> get settledChoices => {
    for (final group in groups)
      if (resolved(group) case final value?) group.name: value.label,
  };

  /// The first group [choices] leaves open, in the page's order; null when
  /// every group has an answer.
  WebOptionGroup? nextToChoose(Map<String, String> choices) {
    for (final group in groups) {
      if (!choices.keys.any(group.isNamed)) return group;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WebPurchaseOptions &&
          other.pageUrl == pageUrl &&
          listEquals(other.groups, groups) &&
          other.canAddToCart == canAddToCart &&
          other.cartUrl == cartUrl;

  @override
  int get hashCode =>
      Object.hash(pageUrl, Object.hashAll(groups), canAddToCart, cartUrl);
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

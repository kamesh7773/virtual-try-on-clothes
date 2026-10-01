import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'try_on_category.dart';

/// Who the mirror styled its cards for. Picked on the site — the MEN'S /
/// WOMEN'S switch over the camera, or the YOUTH APPAREL row — and sent with
/// every link, because the same card leads somewhere different for each.
enum ShopVariant {
  men("Men's"),
  women("Women's"),
  boys("Boys'"),
  girls("Girls'");

  const ShopVariant(this.label);

  /// As the site's own headings spell it.
  final String label;

  String get wireName => name;

  /// Null rather than a guess, for the same reason as
  /// [TryOnCategory.fromWireName].
  static ShopVariant? fromWireName(String? wireName) {
    for (final variant in values) {
      if (variant.wireName == wireName) return variant;
    }
    return null;
  }
}

/// Which shelf the cards sat on. The four cards are the same on both; the
/// links behind them are not.
enum ShopDept {
  apparel('Apparel'),
  shoes('Shoes');

  const ShopDept(this.label);

  final String label;

  String get wireName => name;

  static ShopDept? fromWireName(String? wireName) {
    for (final dept in values) {
      if (dept.wireName == wireName) return dept;
    }
    return null;
  }
}

/// A retailer link the mirror hands to the app instead of opening itself.
///
/// The four style cards used to open a browser of their own — a BACK /
/// title / OPEN bar over an embedded frame the app had to break out of.
/// They now navigate nowhere and post this instead, so the app has the real
/// link at the moment of the tap and opens the retailer as a full page.
///
/// Posted as JSON over a channel the site names:
/// `{"category": "golf", "variant": "women", "dept": "shoes",
/// "url": "https://www.dickssportinggoods.com/..."}`.
///
/// The link is the site's to choose — it keeps the table of which card leads
/// where for men, women, boys and girls, apparel and shoes. The rest of the
/// message only says what was tapped, for the history.
@immutable
class ShopLink {
  final Uri url;

  /// Which card was tapped. Null when the site sends a name this app does
  /// not know — the link is still worth opening, only the label is poorer.
  final TryOnCategory? category;

  /// Null for a name this app does not know, or none at all.
  final ShopVariant? variant;

  /// Null for a name this app does not know, or none at all.
  final ShopDept? dept;

  const ShopLink({required this.url, this.category, this.variant, this.dept});

  /// Returns null for anything that is not a usable shop link.
  ///
  /// Parsing is total: the channel is reachable by every script on the page,
  /// so a message is proven to be a link before it is followed. It needs a
  /// host — `https:///f/golf` parses happily and goes nowhere — and a scheme
  /// that is the web: `javascript:` and `file:` are not links to a shop.
  static ShopLink? tryParse(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    final Map<String, dynamic> message = decoded;

    final url = message['url'];
    if (url is! String) return null;

    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;

    String? name(String key) {
      final value = message[key];
      return value is String ? value : null;
    }

    return ShopLink(
      url: uri,
      category: TryOnCategory.fromWireName(name('category')),
      variant: ShopVariant.fromWireName(name('variant')),
      dept: ShopDept.fromWireName(name('dept')),
    );
  }

  /// What the history calls this tap — "Golf shoes". The card carried no
  /// other words worth recording: its own read "GET THIS STYLE" on all four.
  String get label {
    final name = category?.wireName;
    if (name == null) return 'Shop link';
    final card = '${name[0].toUpperCase()}${name.substring(1)}';
    final shelf = dept?.label.toLowerCase();
    return shelf == null ? card : '$card $shelf';
  }

  /// What the card sat under — "Women's Shoes". Null when the site named
  /// neither half of it.
  String? get context {
    final words = [variant?.label, dept?.label].nonNulls.join(' ');
    return words.isEmpty ? null : words;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShopLink &&
          other.url == url &&
          other.category == category &&
          other.variant == variant &&
          other.dept == dept;

  @override
  int get hashCode => Object.hash(url, category, variant, dept);
}

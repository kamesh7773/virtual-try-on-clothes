import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'try_on_category.dart';

/// A retailer link the mirror hands to the app instead of opening itself.
///
/// The four apparel cards used to open a browser of their own — a BACK /
/// title / OPEN bar over an embedded frame the app had to break out of.
/// They now navigate nowhere and post this instead, so the app has the real
/// link at the moment of the tap and opens the retailer as a full page.
///
/// Posted as JSON over a channel the site names:
/// `{"category": "golf", "url": "https://www.dickssportinggoods.com/..."}`.
@immutable
class ShopLink {
  final Uri url;

  /// Which card was tapped. Null when the site sends a name this app does
  /// not know — the link is still worth opening, only the label is poorer.
  final TryOnCategory? category;

  const ShopLink({required this.url, this.category});

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

    final url = decoded['url'];
    if (url is! String) return null;

    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;

    final category = decoded['category'];
    return ShopLink(
      url: uri,
      category: TryOnCategory.fromWireName(
        category is String ? category : null,
      ),
    );
  }

  /// What the history calls this tap. The card carried no other words worth
  /// recording — its own read "GET THIS STYLE" on all four.
  String get label {
    final name = category?.wireName;
    if (name == null) return 'Shop link';
    return '${name[0].toUpperCase()}${name.substring(1)} apparel';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShopLink && other.url == url && other.category == category;

  @override
  int get hashCode => Object.hash(url, category);
}

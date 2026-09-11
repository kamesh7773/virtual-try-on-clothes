import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'visit_trigger.dart';

/// What the page says about a tap, sent over the browser's JavaScript bridge.
///
/// The page is the only place this is knowable: by the time a navigation
/// reaches the app, the card that was tapped and the words on it are gone.
@immutable
class WebTapReport {
  /// Whether the app should navigate to [url] itself, or the page is only
  /// reporting a tap it is handling on its own.
  final bool promote;

  final String url;

  /// The words on whatever was tapped, e.g. "GET THIS STYLE".
  final String? label;

  /// The heading the tapped thing sits under, e.g. "MEN'S APPAREL".
  final String? context;

  /// The page the tap happened on.
  final String? sourceUrl;
  final String? sourceTitle;

  final VisitTrigger trigger;

  const WebTapReport({
    required this.promote,
    required this.url,
    required this.trigger,
    this.label,
    this.context,
    this.sourceUrl,
    this.sourceTitle,
  });

  /// Returns null for anything that is not a report this app sent itself —
  /// the bridge is reachable by any script on the page.
  static WebTapReport? tryParse(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;

      final url = json['url'];
      if (url is! String || url.isEmpty) return null;

      return WebTapReport(
        promote: json['promote'] == true,
        url: url,
        trigger: VisitTrigger.fromName(json['trigger'] as String?),
        label: _clean(json['label']),
        context: _clean(json['context']),
        sourceUrl: _clean(json['sourceUrl']),
        sourceTitle: _clean(json['sourceTitle']),
      );
    } catch (_) {
      return null;
    }
  }

  static String? _clean(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    // The page controls this text; a runaway string would be carried into the
    // history and rendered forever.
    return trimmed.length <= 200 ? trimmed : '${trimmed.substring(0, 199)}…';
  }
}

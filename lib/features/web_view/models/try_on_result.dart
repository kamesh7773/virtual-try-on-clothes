import 'package:flutter/foundation.dart';

/// What the try-on service answers with: a page to open.
@immutable
class TryOnResult {
  /// Absolute, or a path to be completed against the service's own host.
  final String url;

  const TryOnResult({required this.url});

  /// Reads the link out of the shapes such a service answers in, rather than
  /// pinning the app to one field name it does not own. Returns null when the
  /// body carries no link at all — a queued job, an error envelope.
  static TryOnResult? tryParse(Object? body) {
    final url = _find(body, depth: 0);
    return url == null ? null : TryOnResult(url: url);
  }

  static const List<String> _urlKeys = [
    'url',
    'tryOnUrl',
    'resultUrl',
    'redirectUrl',
    'link',
    'result',
    'path',
  ];

  static String? _find(Object? body, {required int depth}) {
    if (depth > 3) return null;
    if (body is String) return _asUrl(body);
    if (body is! Map) return null;

    for (final key in _urlKeys) {
      final value = _asUrl(body[key]);
      if (value != null) return value;
    }

    final data = body['data'];
    if (data is Map || data is String) return _find(data, depth: depth + 1);
    return null;
  }

  static String? _asUrl(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    // Absolute, or a path the service's own host can complete.
    return trimmed.startsWith('http') || trimmed.startsWith('/')
        ? trimmed
        : null;
  }

  Map<String, dynamic> toJson() => {'url': url};

  TryOnResult copyWith({String? url}) => TryOnResult(url: url ?? this.url);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is TryOnResult && other.url == url);

  @override
  int get hashCode => url.hashCode;
}

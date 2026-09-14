import 'package:flutter/foundation.dart';

import 'visit_trigger.dart';

/// One page load inside the in-app browser.
///
/// A visit is written the moment a page starts loading, then completed when
/// it finishes or fails — so a row exists even for a page that never came
/// back, which is exactly the case worth seeing in the history.
@immutable
class UrlVisit {
  /// Unique per visit. The same URL opened twice is two rows, not one with a
  /// counter: when a page was hit is the point of the record.
  final String id;

  final String url;

  /// Which [WebDestination] the browsing session started from.
  final String destinationId;

  /// When the page started loading.
  final DateTime openedAt;

  /// The page's own title. Null while loading, and for pages that failed.
  final String? title;

  /// Start to finish. Null while loading, and for pages that failed.
  final Duration? loadTime;

  /// Null unless the main frame failed.
  final String? error;

  /// How the page was reached.
  final VisitTrigger trigger;

  /// The words on whatever was tapped to get here, when a tap is what it was.
  final String? tappedLabel;

  /// The heading that tapped thing sat under.
  final String? tappedContext;

  /// The page the tap happened on.
  final String? sourceUrl;
  final String? sourceTitle;

  const UrlVisit({
    required this.id,
    required this.url,
    required this.destinationId,
    required this.openedAt,
    this.title,
    this.loadTime,
    this.error,
    this.trigger = VisitTrigger.direct,
    this.tappedLabel,
    this.tappedContext,
    this.sourceUrl,
    this.sourceTitle,
  });

  factory UrlVisit.fromJson(Map<String, dynamic> json) => UrlVisit(
    id: json['id'] as String,
    url: json['url'] as String,
    destinationId: json['destinationId'] as String? ?? '',
    // Written as UTC; read back as local so the history screen shows the
    // time the user was actually browsing. Rows written before this carry no
    // zone and parse as local already, which is what they were.
    openedAt:
        DateTime.tryParse(json['openedAt'] as String? ?? '')?.toLocal() ??
        DateTime.now(),
    title: json['title'] as String?,
    loadTime: json['loadTimeMs'] == null
        ? null
        : Duration(milliseconds: json['loadTimeMs'] as int),
    error: json['error'] as String?,
    trigger: VisitTrigger.fromName(json['trigger'] as String?),
    tappedLabel: json['tappedLabel'] as String?,
    tappedContext: json['tappedContext'] as String?,
    sourceUrl: json['sourceUrl'] as String?,
    sourceTitle: json['sourceTitle'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    'destinationId': destinationId,
    // UTC, with the zone on it: this JSON is both the local store and what
    // goes to the backend, and a wall-clock time with no zone is not a time.
    'openedAt': openedAt.toUtc().toIso8601String(),
    if (title != null) 'title': title,
    if (loadTime != null) 'loadTimeMs': loadTime!.inMilliseconds,
    if (error != null) 'error': error,
    'trigger': trigger.name,
    if (tappedLabel != null) 'tappedLabel': tappedLabel,
    if (tappedContext != null) 'tappedContext': tappedContext,
    if (sourceUrl != null) 'sourceUrl': sourceUrl,
    if (sourceTitle != null) 'sourceTitle': sourceTitle,
  };

  String get host => Uri.tryParse(url)?.host ?? url;

  /// Everything after the host — what distinguishes two rows on one site.
  String get path {
    final uri = Uri.tryParse(url);
    if (uri == null) return '';
    final query = uri.query.isEmpty ? '' : '?${uri.query}';
    return '${uri.path}$query';
  }

  bool get isLoading => loadTime == null && error == null;
  bool get didFail => error != null;

  /// The query as pairs, for the detail view — this is where a retail URL
  /// keeps the category, the search term and the filters.
  Map<String, String> get queryParameters =>
      Uri.tryParse(url)?.queryParameters ?? const {};

  List<String> get pathSegments =>
      Uri.tryParse(url)?.pathSegments.where((s) => s.isNotEmpty).toList() ??
      const [];

  /// The source page's host, for showing where a tap came from.
  String? get sourceHost {
    final uri = sourceUrl == null ? null : Uri.tryParse(sourceUrl!);
    final host = uri?.host;
    return host == null || host.isEmpty ? null : host;
  }

  UrlVisit copyWith({String? title, Duration? loadTime, String? error}) =>
      UrlVisit(
        id: id,
        url: url,
        destinationId: destinationId,
        openedAt: openedAt,
        title: title ?? this.title,
        loadTime: loadTime ?? this.loadTime,
        error: error ?? this.error,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UrlVisit &&
          other.id == id &&
          other.url == url &&
          other.destinationId == destinationId &&
          other.openedAt == openedAt &&
          other.title == title &&
          other.loadTime == loadTime &&
          other.error == error &&
          other.trigger == trigger &&
          other.tappedLabel == tappedLabel &&
          other.tappedContext == tappedContext &&
          other.sourceUrl == sourceUrl &&
          other.sourceTitle == sourceTitle;

  @override
  int get hashCode => Object.hash(
    id,
    url,
    destinationId,
    openedAt,
    title,
    loadTime,
    error,
    trigger,
    tappedLabel,
    tappedContext,
    sourceUrl,
    sourceTitle,
  );
}

import 'package:flutter/foundation.dart';

import 'url_visit.dart';

/// What the app was when it browsed.
@immutable
class AppInfo {
  final String id;
  final String version;
  final String build;

  /// `development`, `staging` or `production`.
  final String flavor;

  const AppInfo({
    required this.id,
    required this.version,
    required this.build,
    required this.flavor,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'version': version,
    'build': build,
    'flavor': flavor,
  };
}

/// What it was browsing on. Best effort — nothing here identifies a person.
@immutable
class DeviceInfo {
  /// `android` or `ios`.
  final String platform;
  final String osVersion;

  const DeviceInfo({required this.platform, required this.osVersion});

  Map<String, dynamic> toJson() => {
    'platform': platform,
    'osVersion': osVersion,
  };
}

/// One finished browsing flow, as the backend receives it.
///
/// A batch rather than a message per page: a flow is only worth reporting
/// once it is over, and by then every page in it has its title and its
/// timings. The shape is documented for the backend in
/// `docs/url-history-payload.md`.
@immutable
class HistoryPayload {
  /// Bumped only when a field changes meaning, so the backend can tell an
  /// old app's batch from a new one's.
  static const int schemaVersion = 1;

  final DateTime sentAt;
  final AppInfo app;
  final DeviceInfo device;

  /// Newest first, as the history itself is kept.
  final List<UrlVisit> visits;

  const HistoryPayload({
    required this.sentAt,
    required this.app,
    required this.device,
    required this.visits,
  });

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'sentAt': sentAt.toUtc().toIso8601String(),
    'app': app.toJson(),
    'device': device.toJson(),
    'visits': visits.map((visit) => visit.toJson()).toList(growable: false),
  };
}

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/services/storage_service.dart';
import '../models/url_visit.dart';

part 'url_history_repository.g.dart';

@riverpod
UrlHistoryRepository urlHistoryRepository(Ref ref) =>
    UrlHistoryRepository(ref.read(storageServiceProvider.notifier));

/// Where browsing history lives between runs.
///
/// Local only, on purpose: the history is a debugging and recall aid, not
/// something the app has any reason to send anywhere.
class UrlHistoryRepository {
  final StorageService _storage;

  const UrlHistoryRepository(this._storage);

  static const String storageKey = 'web_view.url_history';

  /// Beyond this the oldest visits are dropped. A phone that browses for
  /// months should not carry an unbounded string in shared preferences.
  static const int maxEntries = 200;

  /// Newest first. An unreadable store is treated as an empty one — losing
  /// history is a smaller failure than refusing to browse.
  Future<List<UrlVisit>> load() async {
    final raw = await _storage.getString(storageKey);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(UrlVisit.fromJson)
          .toList(growable: false);
    } catch (e) {
      debugPrint('UrlHistoryRepository.load decode error: $e');
      return const [];
    }
  }

  Future<void> save(List<UrlVisit> visits) async {
    final capped = visits.take(maxEntries).toList(growable: false);
    await _storage.setString(
      storageKey,
      jsonEncode(capped.map((visit) => visit.toJson()).toList()),
    );
  }

  Future<void> clear() => _storage.remove(storageKey);
}

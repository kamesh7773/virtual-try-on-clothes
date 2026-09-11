import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/url_visit.dart';
import '../models/visit_trigger.dart';
import '../repositories/url_history_repository.dart';
import 'url_history_state.dart';

part 'url_history_view_model.g.dart';

/// Every page the in-app browser has opened, newest first.
///
/// Kept alive for the app's lifetime: the browser writes to it from a page
/// callback, and the history screen reads it much later. A provider that
/// disposed with either one would lose whatever the other had not yet saved.
@Riverpod(keepAlive: true)
class UrlHistoryViewModel extends _$UrlHistoryViewModel {
  /// Guards against re-reading the store on every screen that opens.
  bool _hasLoaded = false;

  /// Two pages can start loading inside the same microsecond, and an id that
  /// repeats would complete the wrong row.
  int _sequence = 0;

  @override
  UrlHistoryState build() => const UrlHistoryState();

  UrlHistoryRepository get _repo => ref.read(urlHistoryRepositoryProvider);

  Future<void> load({bool force = false}) async {
    if (_hasLoaded && !force) return;
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, clearError: true);

    final stored = await _repo.load();
    if (!ref.mounted) return;

    // Anything recorded while the store was being read is newer than what it
    // held, so it keeps its place at the front instead of being overwritten.
    final pending = state.visits;
    final storedIds = pending.map((visit) => visit.id).toSet();
    _hasLoaded = true;
    state = state.copyWith(
      visits: [
        ...pending,
        ...stored.where((visit) => !storedIds.contains(visit.id)),
      ],
      isLoading: false,
    );
  }

  /// Records a page that has started loading and returns its id, which
  /// [markLoaded] and [markFailed] use to complete the row.
  String record({
    required String url,
    required String destinationId,
    VisitTrigger trigger = VisitTrigger.direct,
    String? tappedLabel,
    String? tappedContext,
    String? sourceUrl,
    String? sourceTitle,
  }) {
    final openedAt = DateTime.now();
    final visit = UrlVisit(
      id: '${openedAt.microsecondsSinceEpoch}-${_sequence++}',
      url: url,
      destinationId: destinationId,
      openedAt: openedAt,
      trigger: trigger,
      tappedLabel: tappedLabel,
      tappedContext: tappedContext,
      sourceUrl: sourceUrl,
      sourceTitle: sourceTitle,
    );

    state = state.copyWith(
      visits: [
        visit,
        ...state.visits,
      ].take(UrlHistoryRepository.maxEntries).toList(growable: false),
    );
    _persist();
    return visit.id;
  }

  void markLoaded(String id, {String? title, Duration? loadTime}) {
    _update(id, (visit) => visit.copyWith(title: title, loadTime: loadTime));
  }

  void markFailed(String id, String error) {
    _update(id, (visit) => visit.copyWith(error: error));
  }

  Future<void> clear() async {
    state = state.copyWith(visits: const []);
    await _repo.clear();
  }

  void _update(String id, UrlVisit Function(UrlVisit visit) transform) {
    final index = state.visits.indexWhere((visit) => visit.id == id);
    // The row can be gone already — the cap drops the oldest, and a busy page
    // can push its own start off the end before it finishes.
    if (index == -1) return;

    final updated = [...state.visits];
    updated[index] = transform(updated[index]);
    state = state.copyWith(visits: updated);
    _persist();
  }

  /// Fire and forget: a failed write costs the history, never the browsing.
  void _persist() {
    _repo.save(state.visits);
  }
}

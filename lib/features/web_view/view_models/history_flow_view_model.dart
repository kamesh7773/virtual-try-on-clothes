import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/url_visit.dart';
import '../repositories/history_repository.dart';
import 'history_flow_state.dart';
import 'url_history_view_model.dart';

part 'history_flow_view_model.g.dart';

/// Watches one journey through the browser and reports it once it is over.
///
/// A flow begins on the mirror, and only counts once the user has followed a
/// card out to a retailer — a visit to the front page and back is nobody's
/// journey. It ends when they come back to the mirror to start another, or
/// when they put the app down.
///
/// Kept alive for the app's lifetime: the flow outlives any one page, and a
/// provider disposed with the screen would drop a journey mid-way.
@Riverpod(keepAlive: true)
class HistoryFlowViewModel extends _$HistoryFlowViewModel {
  @override
  HistoryFlowState build() => const HistoryFlowState();

  /// Called as each page begins loading, with where it is.
  ///
  /// Landing back on the mirror with a journey behind it ends that journey
  /// before this page starts the next one.
  Future<void> noteVisit(String visitId, {required bool isOwnSite}) async {
    if (isOwnSite && state.reachedRetailer) {
      await completeFlow();
    }

    state = state.copyWith(
      visitIds: [...state.visitIds, visitId],
      reachedRetailer: state.reachedRetailer || !isOwnSite,
    );
  }

  /// Reports the flow if there is one, and starts a fresh one either way.
  ///
  /// A flow that never left the mirror is dropped rather than sent: it is
  /// still in the local history, and the backend asked for journeys.
  Future<void> completeFlow() async {
    if (state.isSending) return;

    if (!state.isReportable) {
      state = state.copyWith(visitIds: const [], reachedRetailer: false);
      return;
    }

    // Read from the history rather than kept here, so each visit carries the
    // title and the timings it only has once the page has finished.
    final ids = state.visitIds.toSet();
    final visits = ref
        .read(urlHistoryViewModelProvider)
        .visits
        .where((visit) => ids.contains(visit.id))
        .toList(growable: false);

    if (visits.isEmpty) {
      state = state.copyWith(visitIds: const [], reachedRetailer: false);
      return;
    }

    state = state.copyWith(isSending: true, clearError: true);
    final response = await ref.read(historyRepositoryProvider).send(visits);
    if (!ref.mounted) return;

    state = HistoryFlowState(
      sentFlows: state.sentFlows + (response.isSuccess ? 1 : 0),
      error: response.isSuccess ? null : response.error,
    );
  }

  /// Visits in the flow being followed, oldest first — for tests and for
  /// anything that wants to show what is about to be reported.
  List<UrlVisit> get pending {
    final ids = state.visitIds.toSet();
    return ref
        .read(urlHistoryViewModelProvider)
        .visits
        .where((visit) => ids.contains(visit.id))
        .toList(growable: false);
  }
}

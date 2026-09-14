import 'package:flutter/foundation.dart';

/// One journey through the browser, as far as it has got.
///
/// A flow is the point of the report: not every page the app has ever
/// opened, but one run from the mirror out to a retailer and back.
@immutable
class HistoryFlowState {
  /// The visits in the flow being followed, by id, in the order they began.
  final List<String> visitIds;

  /// Whether the flow has left the mirror for a retailer. Until it has,
  /// there is no journey to report — only someone looking at the front page.
  final bool reachedRetailer;

  final bool isSending;

  /// Why the last flow could not be reported. The flow itself is already
  /// safe in the local history, so this is worth showing and not retrying.
  final String? error;

  /// How many flows this run of the app has reported.
  final int sentFlows;

  const HistoryFlowState({
    this.visitIds = const [],
    this.reachedRetailer = false,
    this.isSending = false,
    this.error,
    this.sentFlows = 0,
  });

  /// Whether there is a journey here worth sending.
  bool get isReportable => reachedRetailer && visitIds.isNotEmpty;

  HistoryFlowState copyWith({
    List<String>? visitIds,
    bool? reachedRetailer,
    bool? isSending,
    String? error,
    int? sentFlows,
    bool clearError = false,
  }) => HistoryFlowState(
    visitIds: visitIds ?? this.visitIds,
    reachedRetailer: reachedRetailer ?? this.reachedRetailer,
    isSending: isSending ?? this.isSending,
    error: clearError ? null : (error ?? this.error),
    sentFlows: sentFlows ?? this.sentFlows,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HistoryFlowState &&
          listEquals(other.visitIds, visitIds) &&
          other.reachedRetailer == reachedRetailer &&
          other.isSending == isSending &&
          other.error == error &&
          other.sentFlows == sentFlows;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(visitIds),
    reachedRetailer,
    isSending,
    error,
    sentFlows,
  );
}

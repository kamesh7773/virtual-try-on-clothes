import 'package:flutter/foundation.dart';

import '../models/url_visit.dart';

@immutable
class UrlHistoryState {
  /// Newest first.
  final List<UrlVisit> visits;
  final bool isLoading;
  final String? error;

  const UrlHistoryState({
    this.visits = const [],
    this.isLoading = false,
    this.error,
  });

  bool get isEmpty => visits.isEmpty;
  int get total => visits.length;

  UrlHistoryState copyWith({
    List<UrlVisit>? visits,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) => UrlHistoryState(
    visits: visits ?? this.visits,
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UrlHistoryState &&
          listEquals(visits, other.visits) &&
          isLoading == other.isLoading &&
          error == other.error;

  @override
  int get hashCode => Object.hash(Object.hashAll(visits), isLoading, error);
}

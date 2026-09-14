// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'history_flow_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Watches one journey through the browser and reports it once it is over.
///
/// A flow begins on the mirror, and only counts once the user has followed a
/// card out to a retailer — a visit to the front page and back is nobody's
/// journey. It ends when they come back to the mirror to start another, or
/// when they put the app down.
///
/// Kept alive for the app's lifetime: the flow outlives any one page, and a
/// provider disposed with the screen would drop a journey mid-way.

@ProviderFor(HistoryFlowViewModel)
final historyFlowViewModelProvider = HistoryFlowViewModelProvider._();

/// Watches one journey through the browser and reports it once it is over.
///
/// A flow begins on the mirror, and only counts once the user has followed a
/// card out to a retailer — a visit to the front page and back is nobody's
/// journey. It ends when they come back to the mirror to start another, or
/// when they put the app down.
///
/// Kept alive for the app's lifetime: the flow outlives any one page, and a
/// provider disposed with the screen would drop a journey mid-way.
final class HistoryFlowViewModelProvider
    extends $NotifierProvider<HistoryFlowViewModel, HistoryFlowState> {
  /// Watches one journey through the browser and reports it once it is over.
  ///
  /// A flow begins on the mirror, and only counts once the user has followed a
  /// card out to a retailer — a visit to the front page and back is nobody's
  /// journey. It ends when they come back to the mirror to start another, or
  /// when they put the app down.
  ///
  /// Kept alive for the app's lifetime: the flow outlives any one page, and a
  /// provider disposed with the screen would drop a journey mid-way.
  HistoryFlowViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'historyFlowViewModelProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$historyFlowViewModelHash();

  @$internal
  @override
  HistoryFlowViewModel create() => HistoryFlowViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HistoryFlowState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HistoryFlowState>(value),
    );
  }
}

String _$historyFlowViewModelHash() =>
    r'764592f1d636296ae97c74f3dd65aee5ed5160ba';

/// Watches one journey through the browser and reports it once it is over.
///
/// A flow begins on the mirror, and only counts once the user has followed a
/// card out to a retailer — a visit to the front page and back is nobody's
/// journey. It ends when they come back to the mirror to start another, or
/// when they put the app down.
///
/// Kept alive for the app's lifetime: the flow outlives any one page, and a
/// provider disposed with the screen would drop a journey mid-way.

abstract class _$HistoryFlowViewModel extends $Notifier<HistoryFlowState> {
  HistoryFlowState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<HistoryFlowState, HistoryFlowState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<HistoryFlowState, HistoryFlowState>,
              HistoryFlowState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Owns the live Decart session.
///
/// Knows which garment is on screen only because the caller passes it in —
/// the catalog stays independent so it keeps working with no session at all.

@ProviderFor(SessionViewModel)
final sessionViewModelProvider = SessionViewModelProvider._();

/// Owns the live Decart session.
///
/// Knows which garment is on screen only because the caller passes it in —
/// the catalog stays independent so it keeps working with no session at all.
final class SessionViewModelProvider
    extends $NotifierProvider<SessionViewModel, SessionState> {
  /// Owns the live Decart session.
  ///
  /// Knows which garment is on screen only because the caller passes it in —
  /// the catalog stays independent so it keeps working with no session at all.
  SessionViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionViewModelHash();

  @$internal
  @override
  SessionViewModel create() => SessionViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionState>(value),
    );
  }
}

String _$sessionViewModelHash() => r'87fbfcc4c1c78bc064f6539c802e1f287250a316';

/// Owns the live Decart session.
///
/// Knows which garment is on screen only because the caller passes it in —
/// the catalog stays independent so it keeps working with no session at all.

abstract class _$SessionViewModel extends $Notifier<SessionState> {
  SessionState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<SessionState, SessionState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SessionState, SessionState>,
              SessionState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'style_session_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The Style Me session: the snapshot, who it is styled for, and the four
/// looks made from it.
///
/// The photo is uploaded as soon as it is taken — that is cheap, and it
/// means the id is ready by the time it is needed. The looks are not: each
/// one costs the service a generation, so they are only asked for by the
/// screen that shows them, through [showLooks], and only for the shopper
/// and shelf it is showing. A shopper who takes a photo and leaves costs
/// nothing more than the upload.
///
/// Kept alive across the flow's screens, so the looks go on arriving while
/// the shopper is on another one. The intro screen resets it.

@ProviderFor(StyleSessionViewModel)
final styleSessionViewModelProvider = StyleSessionViewModelProvider._();

/// The Style Me session: the snapshot, who it is styled for, and the four
/// looks made from it.
///
/// The photo is uploaded as soon as it is taken — that is cheap, and it
/// means the id is ready by the time it is needed. The looks are not: each
/// one costs the service a generation, so they are only asked for by the
/// screen that shows them, through [showLooks], and only for the shopper
/// and shelf it is showing. A shopper who takes a photo and leaves costs
/// nothing more than the upload.
///
/// Kept alive across the flow's screens, so the looks go on arriving while
/// the shopper is on another one. The intro screen resets it.
final class StyleSessionViewModelProvider
    extends $NotifierProvider<StyleSessionViewModel, StyleSessionState> {
  /// The Style Me session: the snapshot, who it is styled for, and the four
  /// looks made from it.
  ///
  /// The photo is uploaded as soon as it is taken — that is cheap, and it
  /// means the id is ready by the time it is needed. The looks are not: each
  /// one costs the service a generation, so they are only asked for by the
  /// screen that shows them, through [showLooks], and only for the shopper
  /// and shelf it is showing. A shopper who takes a photo and leaves costs
  /// nothing more than the upload.
  ///
  /// Kept alive across the flow's screens, so the looks go on arriving while
  /// the shopper is on another one. The intro screen resets it.
  StyleSessionViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'styleSessionViewModelProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$styleSessionViewModelHash();

  @$internal
  @override
  StyleSessionViewModel create() => StyleSessionViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StyleSessionState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StyleSessionState>(value),
    );
  }
}

String _$styleSessionViewModelHash() =>
    r'bb48f6202c73de68607f15344df2d323a059b8df';

/// The Style Me session: the snapshot, who it is styled for, and the four
/// looks made from it.
///
/// The photo is uploaded as soon as it is taken — that is cheap, and it
/// means the id is ready by the time it is needed. The looks are not: each
/// one costs the service a generation, so they are only asked for by the
/// screen that shows them, through [showLooks], and only for the shopper
/// and shelf it is showing. A shopper who takes a photo and leaves costs
/// nothing more than the upload.
///
/// Kept alive across the flow's screens, so the looks go on arriving while
/// the shopper is on another one. The intro screen resets it.

abstract class _$StyleSessionViewModel extends $Notifier<StyleSessionState> {
  StyleSessionState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<StyleSessionState, StyleSessionState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<StyleSessionState, StyleSessionState>,
              StyleSessionState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

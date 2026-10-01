// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'camera_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Owns camera access for the body snapshot.
///
/// Only the permission gate lives here — the preview and the capture are the
/// `GetReadyScreen`'s, through the camera plugin. This view model decides
/// whether that preview may be opened at all.

@ProviderFor(CameraViewModel)
final cameraViewModelProvider = CameraViewModelProvider._();

/// Owns camera access for the body snapshot.
///
/// Only the permission gate lives here — the preview and the capture are the
/// `GetReadyScreen`'s, through the camera plugin. This view model decides
/// whether that preview may be opened at all.
final class CameraViewModelProvider
    extends $NotifierProvider<CameraViewModel, CameraState> {
  /// Owns camera access for the body snapshot.
  ///
  /// Only the permission gate lives here — the preview and the capture are the
  /// `GetReadyScreen`'s, through the camera plugin. This view model decides
  /// whether that preview may be opened at all.
  CameraViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cameraViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cameraViewModelHash();

  @$internal
  @override
  CameraViewModel create() => CameraViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CameraState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CameraState>(value),
    );
  }
}

String _$cameraViewModelHash() => r'f519b7d9fa2df9df6449698cb50ad659aedfccdb';

/// Owns camera access for the body snapshot.
///
/// Only the permission gate lives here — the preview and the capture are the
/// `GetReadyScreen`'s, through the camera plugin. This view model decides
/// whether that preview may be opened at all.

abstract class _$CameraViewModel extends $Notifier<CameraState> {
  CameraState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<CameraState, CameraState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CameraState, CameraState>,
              CameraState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

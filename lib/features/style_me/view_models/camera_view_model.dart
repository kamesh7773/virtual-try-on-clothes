import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/services/permission_service.dart';
import 'camera_state.dart';

part 'camera_view_model.g.dart';

/// Owns camera access for the try-on session.
///
/// Only the permission gate lives here — the preview itself is a native view
/// (see `CameraPreviewView`), and from phase 4 the Decart SDK owns the capture
/// session. This view model decides whether that view should be shown at all.
@riverpod
class CameraViewModel extends _$CameraViewModel {
  @override
  CameraState build() => const CameraState();

  PermissionService get _permissions =>
      ref.read(permissionServiceProvider.notifier);

  /// Reads the current status without showing a dialog. Safe to call on
  /// every resume.
  Future<void> refresh() async {
    final status = await _permissions.status(Permission.camera);
    if (!ref.mounted) return;
    state = state.copyWith(permission: _map(status));
  }

  /// Shows the system dialog when that can still help, and routes to Settings
  /// when it cannot.
  Future<void> request() async {
    if (state.isRequesting) return;
    state = state.copyWith(isRequesting: true);

    final granted = await _permissions.request(Permission.camera);
    if (!ref.mounted) return;

    if (granted) {
      state = state.copyWith(
        permission: CameraPermission.granted,
        isRequesting: false,
      );
      return;
    }

    // A denial that iOS will not prompt for again has to be distinguished
    // here, otherwise the button silently stops doing anything.
    final permanently =
        await _permissions.isPermanentlyDenied(Permission.camera);
    if (!ref.mounted) return;

    state = state.copyWith(
      permission: permanently
          ? CameraPermission.permanentlyDenied
          : CameraPermission.denied,
      isRequesting: false,
    );
  }

  Future<void> openSettings() => _permissions.openSettings();

  CameraPermission _map(PermissionStatus status) => switch (status) {
        PermissionStatus.granted ||
        PermissionStatus.limited ||
        PermissionStatus.provisional =>
          CameraPermission.granted,
        PermissionStatus.permanentlyDenied ||
        PermissionStatus.restricted =>
          CameraPermission.permanentlyDenied,
        PermissionStatus.denied => CameraPermission.denied,
      };
}

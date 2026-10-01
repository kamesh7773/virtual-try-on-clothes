import 'package:flutter/foundation.dart';

enum CameraPermission {
  /// Not checked yet — render nothing rather than flashing a denied state.
  unknown,
  granted,

  /// Denied this time; asking again will show the system dialog.
  denied,

  /// Denied for good. Only the Settings app can undo this.
  permanentlyDenied,
}

@immutable
class CameraState {
  final CameraPermission permission;
  final bool isRequesting;

  const CameraState({
    this.permission = CameraPermission.unknown,
    this.isRequesting = false,
  });

  bool get isGranted => permission == CameraPermission.granted;
  bool get isUnknown => permission == CameraPermission.unknown;

  /// Re-prompting is pointless once permanently denied — send the user to
  /// Settings instead.
  bool get needsSettings => permission == CameraPermission.permanentlyDenied;

  CameraState copyWith({
    CameraPermission? permission,
    bool? isRequesting,
  }) =>
      CameraState(
        permission: permission ?? this.permission,
        isRequesting: isRequesting ?? this.isRequesting,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CameraState &&
          permission == other.permission &&
          isRequesting == other.isRequesting;

  @override
  int get hashCode => Object.hash(permission, isRequesting);
}

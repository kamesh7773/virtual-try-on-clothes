import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../view_models/camera_state.dart';

/// Shown in place of the preview until the camera is available.
///
/// A permanent denial cannot be undone in-app, so the call to action switches
/// to Settings rather than re-prompting into a dialog iOS will never show.
class CameraPermissionGate extends StatelessWidget {
  final CameraState state;
  final VoidCallback onRequest;
  final VoidCallback onOpenSettings;

  const CameraPermissionGate({
    super.key,
    required this.state,
    required this.onRequest,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final needsSettings = state.needsSettings;

    return ColoredBox(
      color: AppColors.stageSurface,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 36.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.photo_camera_outlined,
                size: 36.r,
                color: AppColors.onStageFaint,
              ),
              SizedBox(height: 18.h),
              Text(
                'CAMERA ACCESS NEEDED',
                style: TextStyle(
                  fontSize: 11.sp,
                  color: AppColors.onStageSecondary,
                  letterSpacing: 2.4,
                ),
              ),
              SizedBox(height: 10.h),
              Text(
                needsSettings
                    ? 'Camera access is turned off. Enable it in Settings to try garments on.'
                    : 'Mirror needs your camera to show garments on you.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.sp,
                  height: 1.5,
                  color: AppColors.onStageMuted,
                ),
              ),
              SizedBox(height: 26.h),
              _GateButton(
                label: needsSettings ? 'OPEN SETTINGS' : 'ALLOW CAMERA',
                isBusy: state.isRequesting,
                onPressed: needsSettings ? onOpenSettings : onRequest,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GateButton extends StatelessWidget {
  final String label;
  final bool isBusy;
  final VoidCallback onPressed;

  const _GateButton({
    required this.label,
    required this.isBusy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isBusy ? null : onPressed,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 13.h),
        color: AppColors.onStagePrimary,
        child: isBusy
            ? SizedBox(
                width: 13.r,
                height: 13.r,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: AppColors.stageBackground,
                ),
              )
            : Text(
                label,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: AppColors.stageBackground,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w500,
                ),
              ),
      ),
    );
  }
}

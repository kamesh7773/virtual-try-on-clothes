import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_colors.dart';

/// The way back on the dark stage screens, which carry a masthead instead of
/// an app bar — a bright Material one sits badly against the stage.
///
/// Sized to fit inside a masthead without stretching it, so it costs the
/// content below no height when stacked over one.
class StageBackButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const StageBackButton({super.key, this.onPressed});

  static const double _size = 32;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size.r,
      height: _size.r,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed ?? () => Navigator.of(context).maybePop(),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 16.sp,
            color: AppColors.onStageFaint,
          ),
        ),
      ),
    );
  }
}

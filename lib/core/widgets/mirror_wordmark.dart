import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_colors.dart';

/// "Mirror", the app's masthead.
///
/// Shared rather than owned by a feature: it is the app signing its own
/// name, and it does that on the stage, on the front door, and over a page
/// the browser is still fetching.
class MirrorWordmark extends StatelessWidget {
  final double fontSize;

  const MirrorWordmark({super.key, this.fontSize = 22});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Mirror',
      style: TextStyle(
        fontSize: fontSize.sp,
        color: AppColors.onStagePrimary,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        height: 1.1,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_colors.dart';

/// "LiveLook" set in two weights, matching the web app's masthead.
///
/// Shared rather than owned by a feature: it is the app signing its own
/// name, and it does that on the stage, on the front door, and over a page
/// the browser is still fetching.
class LiveLookWordmark extends StatelessWidget {
  final double fontSize;

  const LiveLookWordmark({super.key, this.fontSize = 22});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: fontSize.sp,
          color: AppColors.onStagePrimary,
          letterSpacing: -0.5,
          height: 1.1,
        ),
        children: const [
          TextSpan(text: 'Live', style: TextStyle(fontWeight: FontWeight.w300)),
          TextSpan(text: 'Look', style: TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/mirror_wordmark.dart';

/// What the user looks at while a page is on its way.
///
/// A web view paints nothing until the page it is loading has something to
/// show, and a retailer's page takes seconds to get there — long enough that
/// the empty view reads as the app having broken rather than as waiting.
/// This covers that gap with the app signing its own name, so the wait
/// belongs to the app instead of looking like its absence.
///
/// Translucent, and deliberately so. The cover lifts on the page's first
/// paint, but a page that never reports one sits under it until the limit —
/// and through a translucent cover that page is already readable, so the
/// wait costs nothing but a dimming. On the way from one page to the next
/// the page being left shows through dimmed, which reads as the site
/// changing rather than the app going dark.
class WebLoadingCover extends HookWidget {
  /// The cover's own colours: the stage palette, let through enough to
  /// see the page under it. Dark enough at the edge to keep the wordmark
  /// legible over a white retail page.
  static const Color _centre = Color(0xCC171717);
  static const Color _edge = Color(0xE6000000);

  const WebLoadingCover({super.key});

  @override
  Widget build(BuildContext context) {
    // A loop that never settles is exactly what a user who has asked for
    // less motion does not want, and a still line reads as waiting too.
    final still = MediaQuery.disableAnimationsOf(context);

    final shuttle = useAnimationController(
      duration: const Duration(milliseconds: 1300),
    );

    useEffect(() {
      if (still) {
        shuttle.value = 0.5;
      } else {
        shuttle.repeat(reverse: true);
      }
      return null;
    }, [still]);

    return DecoratedBox(
      // Lit from the middle rather than flat: the same black everywhere
      // reads as a screen that is off.
      decoration: const BoxDecoration(
        gradient: RadialGradient(radius: 0.85, colors: [_centre, _edge]),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MirrorWordmark(fontSize: 26),
            SizedBox(height: 20.h),
            _Shuttle(animation: shuttle),
            SizedBox(height: 16.h),
            Text(
              'ONE MOMENT',
              style: TextStyle(
                fontSize: 9.sp,
                color: AppColors.onStageFaint,
                letterSpacing: 3,
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A lit segment travelling back and forth along a dim track.
///
/// Deliberately not a spinner: a page load has no progress to report — the
/// web view will not say how far along it is — and a bar that fills would be
/// inventing one. This says only that something is still happening.
class _Shuttle extends StatelessWidget {
  final Animation<double> animation;

  const _Shuttle({required this.animation});

  static const double _trackWidth = 140;
  static const double _segmentWidth = 48;
  static const double _height = 3;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _trackWidth.w,
      height: _height.h,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.stageBorder,
          borderRadius: BorderRadius.circular(_height.h),
        ),
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, child) => Align(
            // -1 is hard against the left end, 1 against the right, and the
            // curve slows the segment as it turns rather than snapping back.
            alignment: Alignment(
              Curves.easeInOut.transform(animation.value) * 2 - 1,
              0,
            ),
            child: child,
          ),
          // Both dimensions given: inside an `Align` the child is free to be
          // as small as it likes, and a box with no height is a box with
          // nothing to see.
          child: Container(
            width: _segmentWidth.w,
            height: _height.h,
            decoration: BoxDecoration(
              color: AppColors.onStagePrimary,
              borderRadius: BorderRadius.circular(_height.h),
            ),
          ),
        ),
      ),
    );
  }
}

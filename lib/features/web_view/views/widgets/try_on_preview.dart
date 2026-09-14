import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import 'web_overlay_button.dart';

/// The try-on the service sent back, shown over the page the product is on.
///
/// The service answers with an image rather than a page to visit, so there
/// is nothing for the browser to navigate to — and navigating would cost the
/// user the product page they were reading. This lies over it instead, and
/// closing it puts them back exactly where they were.
class TryOnPreview extends StatelessWidget {
  final String imageUrl;
  final VoidCallback onClose;

  const TryOnPreview({
    super.key,
    required this.imageUrl,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      // Not quite black: enough of the page shows through to say this is
      // something laid over it rather than a screen the user was sent to.
      color: const Color(0xF2000000),
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              // A garment is worth looking closely at, and the answer comes
              // as a single flat image with no other way in.
              child: InteractiveViewer(
                maxScale: 4,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    final expected = progress.expectedTotalBytes;
                    return _Waiting(
                      progress: expected == null || expected == 0
                          ? null
                          : progress.cumulativeBytesLoaded / expected,
                    );
                  },
                  errorBuilder: (context, _, _) => const _Unavailable(),
                ),
              ),
            ),
            Positioned(
              top: 8.h,
              right: 12.w,
              child: WebOverlayButton(
                icon: Icons.close_rounded,
                label: 'Close try-on',
                onTap: onClose,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Waiting extends StatelessWidget {
  /// Null until the image says how big it is.
  final double? progress;

  const _Waiting({this.progress});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 28.r,
        height: 28.r,
        child: CircularProgressIndicator(
          value: progress,
          strokeWidth: 2,
          valueColor: const AlwaysStoppedAnimation<Color>(
            AppColors.onStageSecondary,
          ),
        ),
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Text(
          'This try-on could not be shown.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.sp,
            color: AppColors.onStageSecondary,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

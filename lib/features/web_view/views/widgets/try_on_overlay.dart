import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/try_on_category.dart';
import '../../models/web_product.dart';

/// The offer that sits over a product page: try this on.
///
/// A pill rather than a bar — the page underneath is the thing the user came
/// for, and the offer should not take a strip of it away.
class TryOnOverlay extends StatelessWidget {
  final WebProduct product;
  final bool isLoading;
  final VoidCallback onTap;

  /// What the product will be tried on as. Shown because the service takes
  /// four categories and the product's own name is not one of them — seeing
  /// which one was picked is the only way to notice a bad guess.
  final TryOnCategory category;

  const TryOnOverlay({
    super.key,
    required this.product,
    required this.isLoading,
    required this.onTap,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
      child: Material(
        color: AppColors.stageElevated,
        child: InkWell(
          onTap: isLoading ? null : onTap,
          child: Container(
            padding: EdgeInsets.fromLTRB(10.w, 9.h, 16.w, 9.h),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.stageBorderActive),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Thumbnail(imageUrl: product.imageUrl),
                SizedBox(width: 12.w),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'TRY THIS ON · ${category.wireName.toUpperCase()}',
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: AppColors.onStagePrimary,
                          letterSpacing: 2,
                        ),
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        product.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9.sp,
                          color: AppColors.onStageFaint,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12.w),
                SizedBox(
                  width: 16.r,
                  height: 16.r,
                  child: isLoading
                      ? const CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: AppColors.onStageSecondary,
                        )
                      : Icon(
                          Icons.arrow_forward_rounded,
                          size: 16.sp,
                          color: AppColors.onStageSecondary,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final String imageUrl;

  const _Thumbnail({required this.imageUrl});

  static const double _size = 36;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size.r,
      height: _size.r,
      child: ColoredBox(
        // Product shots are cut out on white; a dark tile behind one would
        // show as a border around it.
        color: Colors.white,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          // The page's own image, loaded again by the app. A broken one is
          // not worth an error state — the offer still stands.
          errorBuilder: (_, _, _) => Icon(
            Icons.checkroom_rounded,
            size: 18.sp,
            color: AppColors.textHint,
          ),
        ),
      ),
    );
  }
}

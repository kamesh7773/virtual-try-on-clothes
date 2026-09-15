import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/web_purchase_options.dart';
import '../../view_models/product_try_on_state.dart';
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

  /// Whether to offer a checkout under the picture. The offer is made
  /// whenever there is a product to buy; how much of the buying the app
  /// can do for the user is decided when they take it.
  final bool canCheckout;

  final CheckoutStep step;

  /// The attribute being asked about while [step] is
  /// [CheckoutStep.picking] — a colour, a size, an inseam, whatever the
  /// page wants settled — with the values it offers.
  final WebOptionGroup? choosing;

  final VoidCallback? onCheckout;

  /// The user picked a value for [choosing].
  final ValueChanged<String>? onPicked;

  /// Back from a question to the picture, nothing sent.
  final VoidCallback? onCancelPick;

  const TryOnPreview({
    super.key,
    required this.imageUrl,
    required this.onClose,
    this.canCheckout = false,
    this.step = CheckoutStep.none,
    this.choosing,
    this.onCheckout,
    this.onPicked,
    this.onCancelPick,
  });

  @override
  Widget build(BuildContext context) {
    final group = choosing;
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
            // Under the picture, where the eye lands last: the picture is
            // the answer, and this is the question it raises.
            if (canCheckout && onCheckout != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: step == CheckoutStep.picking && group != null
                    ? _OptionSheet(
                        title: 'SELECT ${group.name.toUpperCase()}',
                        onCancel: onCancelPick ?? () {},
                        child: group.isSwatch
                            ? _SwatchRow(
                                values: group.values,
                                onPick: onPicked ?? (_) {},
                              )
                            : _ChipRow(
                                values: group.values,
                                onPick: onPicked ?? (_) {},
                              ),
                      )
                    : _CheckoutBar(
                        adding: step == CheckoutStep.adding,
                        onTap: onCheckout!,
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

/// The way from the picture to the cart.
class _CheckoutBar extends StatelessWidget {
  /// True while the page is being asked; the bar says so and takes no tap.
  final bool adding;
  final VoidCallback onTap;

  const _CheckoutBar({required this.adding, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
      child: Material(
        color: AppColors.onStagePrimary,
        child: InkWell(
          onTap: adding ? null : onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 15.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (adding) ...[
                  SizedBox(
                    width: 12.r,
                    height: 12.r,
                    child: const CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: AppColors.stageBackground,
                    ),
                  ),
                  SizedBox(width: 12.w),
                ],
                Text(
                  adding ? 'ADDING TO CART' : 'CHECKOUT',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: AppColors.stageBackground,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!adding) ...[
                  SizedBox(width: 10.w),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 14.sp,
                    color: AppColors.stageBackground,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A question asked under the picture — which colour, which size, which
/// inseam — with a way back to the picture that sends nothing.
class _OptionSheet extends StatelessWidget {
  final String title;
  final VoidCallback onCancel;
  final Widget child;

  const _OptionSheet({
    required this.title,
    required this.onCancel,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 20.h),
      decoration: const BoxDecoration(
        color: AppColors.stageElevated,
        border: Border(top: BorderSide(color: AppColors.stageBorderActive)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: AppColors.onStagePrimary,
                    letterSpacing: 3,
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: 'Back to the try-on',
                child: InkWell(
                  onTap: onCancel,
                  child: Padding(
                    padding: EdgeInsets.all(4.r),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16.sp,
                      color: AppColors.onStageSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          child,
        ],
      ),
    );
  }
}

/// The page's values as words — sizes, inseams, widths — offered here so
/// the user need not leave the picture to pick one. Values the page has
/// crossed out are shown crossed out too, and take no tap: offering them
/// would only bring back the page's refusal.
class _ChipRow extends StatelessWidget {
  final List<WebOptionValue> values;
  final ValueChanged<String> onPick;

  const _ChipRow({required this.values, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: [
        for (final value in values)
          _Chip(
            value: value,
            onTap: value.available ? () => onPick(value.label) : null,
          ),
      ],
    );
  }
}

/// The page's values as the page draws them when they are colours: a
/// picture each, named underneath, in a row that scrolls when there are
/// many.
class _SwatchRow extends StatelessWidget {
  final List<WebOptionValue> values;
  final ValueChanged<String> onPick;

  const _SwatchRow({required this.values, required this.onPick});

  static const double _tile = 64;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final value in values) ...[
            _Swatch(
              value: value,
              size: _tile.r,
              onTap: value.available ? () => onPick(value.label) : null,
            ),
            SizedBox(width: 10.w),
          ],
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final WebOptionValue value;
  final double size;
  final VoidCallback? onTap;

  const _Swatch({required this.value, required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final available = onTap != null;
    final image = value.imageUrl;
    return Semantics(
      button: true,
      label: value.label,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: size + 12.w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                    color: available
                        ? AppColors.stageBorderActive
                        : AppColors.stageBorder,
                  ),
                ),
                child: image == null
                    ? Icon(
                        Icons.palette_outlined,
                        size: 18.sp,
                        color: AppColors.textHint,
                      )
                    : Image.network(
                        image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.palette_outlined,
                          size: 18.sp,
                          color: AppColors.textHint,
                        ),
                      ),
              ),
              SizedBox(height: 6.h),
              Text(
                value.label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 8.sp,
                  height: 1.3,
                  color: available
                      ? AppColors.onStageSecondary
                      : AppColors.onStageFaint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final WebOptionValue value;
  final VoidCallback? onTap;

  const _Chip({required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final available = onTap != null;
    return Material(
      color: AppColors.stageElevated,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minWidth: 52.w),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
          decoration: BoxDecoration(
            border: Border.all(
              color: available
                  ? AppColors.stageBorderActive
                  : AppColors.stageBorder,
            ),
          ),
          child: Text(
            value.label.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.sp,
              letterSpacing: 1,
              color: available
                  ? AppColors.onStagePrimary
                  : AppColors.onStageFaint,
              decoration: available
                  ? TextDecoration.none
                  : TextDecoration.lineThrough,
              decorationColor: AppColors.onStageFaint,
            ),
          ),
        ),
      ),
    );
  }
}

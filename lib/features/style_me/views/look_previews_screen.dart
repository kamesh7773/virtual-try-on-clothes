import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/routes/route_arguments.dart';
import '../../../core/routes/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../web_view/models/web_destination.dart';
import '../models/look_preview.dart';
import '../models/style_catalog.dart';
import '../view_models/style_session_view_model.dart';
import 'widgets/style_stage.dart';

/// SEE YOURSELF STYLED: the photo styled into the four looks, each one a
/// way into the matching shelf on Dick's — on the shelves Dick's has one
/// for. Under ACCESSORIES or FAN SHOP the looks are only looked at.
///
/// The looks are made for this screen, not before it: opening it is what
/// asks the service for them, so a shopper who never gets this far costs
/// nothing to style.
class LookPreviewsScreen extends HookConsumerWidget {
  const LookPreviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(styleSessionViewModelProvider);
    final photo = session.photo;

    useEffect(() {
      // Touching a provider during build throws, so the ask waits a frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          ref.read(styleSessionViewModelProvider.notifier).showLooks();
        }
      });
      return null;
    }, const []);

    void shop(StyleLook look) {
      // The service names the shelf with each look it makes; the table in
      // the app stands in for a look it did not.
      final url =
          session.previewFor(look.category).shopUrl ??
          StyleCatalog.shopUrl(look.category, session.variant, session.dept);
      debugPrint('[style-me] shop ${look.category.wireName} → $url');
      Navigator.of(context).pushNamed(
        Routes.webView,
        arguments: WebViewScreenArgs(
          destination: WebDestinations.dicksSportingGoods,
          initialUrl: url.toString(),
        ),
      );
    }

    final looks = StyleCatalog.looks;

    return StyleStage(
      children: [
        StyleMasthead(
          trailing: photo == null
              ? null
              : Container(
                  width: 36.r,
                  height: 36.r,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                      width: 2,
                    ),
                    image: DecorationImage(
                      image: MemoryImage(photo.bytes),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
        ),
        SizedBox(height: 28.r),
        Text(
          'SEE YOURSELF STYLED',
          textAlign: TextAlign.center,
          style: styleText(
            9,
            weight: FontWeight.w600,
            tracking: 0.4,
            color: AppColors.styleTeal,
          ),
        ),
        SizedBox(height: 8.r),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                session.heading,
                textAlign: TextAlign.center,
                style: styleText(
                  30,
                  weight: FontWeight.w700,
                  tracking: -0.025,
                  height: 1,
                  shadows: styleTextShadow,
                ),
              ),
            ),
            SizedBox(width: 12.r),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.r, vertical: 4.r),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Text(
                '${session.readyCount}/${looks.length}',
                style: styleText(
                  10,
                  weight: FontWeight.w600,
                  tracking: 0.1,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 20.r),
        for (var i = 0; i < looks.length; i += 2) ...[
          if (i > 0) SizedBox(height: 14.r),
          Row(
            children: [
              for (var j = i; j < i + 2 && j < looks.length; j++) ...[
                if (j > i) SizedBox(width: 14.r),
                Expanded(
                  child: _LookCard(
                    look: looks[j],
                    preview: session.previewFor(looks[j].category),
                    onTap: session.shops ? () => shop(looks[j]) : null,
                  ),
                ),
              ],
            ],
          ),
        ],
        const Spacer(),
        SizedBox(height: 16.r),
        Text(
          'AI PREVIEWS · SAME PHOTO STYLED INTO ALL FOUR LOOKS',
          textAlign: TextAlign.center,
          style: styleText(
            9,
            weight: FontWeight.w500,
            tracking: 0.22,
            color: Colors.white.withValues(alpha: 0.35),
          ),
        ),
      ],
    );
  }
}

class _LookCard extends HookWidget {
  final StyleLook look;
  final LookPreview preview;

  /// Null on a shelf with nothing on Dick's behind it: the look is shown,
  /// without the button that would lead there.
  final VoidCallback? onTap;

  const _LookCard({
    required this.look,
    required this.preview,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // A result that will not load falls back to the stock photo, once.
    final broken = useState(false);
    useEffect(() {
      broken.value = false;
      return null;
    }, [preview.image]);

    final radius = BorderRadius.circular(20);

    Widget? result;
    if (preview.isDone && !broken.value) {
      result = Image.network(
        preview.image!,
        fit: BoxFit.cover,
        errorBuilder: (_, error, _) {
          debugPrint(
            '[style-me] ${look.category.wireName} image failed: $error',
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) broken.value = true;
          });
          return const SizedBox.shrink();
        },
        frameBuilder: (context, child, frame, synchronous) => AnimatedOpacity(
          opacity: frame == null && !synchronous ? 0 : 1,
          duration: const Duration(milliseconds: 400),
          child: child,
        ),
      );
    }

    return StylePressable(
      onTap: preview.isLoading ? null : onTap,
      pressedScale: 0.98,
      child: Semantics(
        button: onTap != null,
        enabled: onTap != null && !preview.isLoading,
        label: '${look.label} look',
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: Container(
            foregroundDecoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: ColoredBox(
                color: AppColors.styleCard,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(look.image, fit: BoxFit.cover),
                    ?result,
                    if (preview.isLoading) const _Generating(),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Color(0xD9000000),
                            Color(0x0D000000),
                            Color(0x40000000),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 14.r,
                      right: 14.r,
                      bottom: 14.r,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            look.label,
                            style: styleText(
                              18,
                              weight: FontWeight.w700,
                              tracking: -0.025,
                              height: 1,
                            ),
                          ),
                          SizedBox(height: 4.r),
                          Text(
                            look.tagline.toUpperCase(),
                            style: styleText(
                              9,
                              weight: FontWeight.w600,
                              tracking: 0.18,
                              color: look.accent,
                            ),
                          ),
                          if (preview.isDone && onTap != null) ...[
                            SizedBox(height: 8.r),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10.r,
                                vertical: 4.r,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.styleTeal,
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x40000000),
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Text(
                                'GET THIS STYLE →',
                                style: styleText(
                                  10,
                                  weight: FontWeight.w700,
                                  tracking: 0.025,
                                  color: AppColors.styleOnTeal,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A teal band sweeping down the card over a pulsing spinner, while the
/// look is being made.
class _Generating extends HookWidget {
  const _Generating();

  @override
  Widget build(BuildContext context) {
    final sweep = useAnimationController(
      duration: const Duration(milliseconds: 2400),
    );
    final ping = useAnimationController(duration: const Duration(seconds: 1));
    useEffect(() {
      sweep.repeat();
      ping.repeat();
      return null;
    }, const []);

    return ColoredBox(
      color: const Color(0x4D000000),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: sweep,
            builder: (context, _) {
              final t = const Cubic(0.4, 0, 0.6, 1).transform(sweep.value);
              // The band starts above the card and leaves below it.
              return Align(
                alignment: Alignment(0, -1.6 + 3.2 * t),
                child: SizedBox(
                  height: 64.r,
                  width: double.infinity,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x0016E0C9),
                          Color(0x8016E0C9),
                          Color(0x0016E0C9),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          Center(
            child: SizedBox(
              width: 36.r,
              height: 36.r,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedBuilder(
                    animation: ping,
                    builder: (context, _) => Transform.scale(
                      scale: 1 + ping.value,
                      child: Opacity(
                        opacity: 1 - ping.value,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0x4016E0C9),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const CircularProgressIndicator(
                    strokeWidth: 3,
                    color: AppColors.styleTeal,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

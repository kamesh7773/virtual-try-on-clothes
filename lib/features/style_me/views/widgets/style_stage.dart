import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/style_catalog.dart';

/// Montserrat, sized the way the web mirror sized it: [tracking] is CSS
/// letter-spacing in ems, so it scales with the text.
TextStyle styleText(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = Colors.white,
  double tracking = 0,
  double? height,
  List<Shadow>? shadows,
  FontStyle? fontStyle,
}) => TextStyle(
  fontFamily: 'Montserrat',
  fontSize: size.sp,
  fontWeight: weight,
  color: color,
  letterSpacing: tracking * size.sp,
  height: height,
  shadows: shadows,
  fontStyle: fontStyle,
);

/// The dark drop shadow the site puts under text that sits on a photo.
const List<Shadow> styleTextShadow = [
  Shadow(color: Color(0xBF000000), offset: Offset(0, 3), blurRadius: 14),
];

/// The backdrop and frame every Style Me screen sits in.
///
/// The content scrolls when it is taller than the screen, and otherwise
/// fills it — so a [Spacer] in [children] pins what follows it to the
/// bottom, the way the site's `mt-auto` footers sit.
class StyleStage extends StatelessWidget {
  final List<Widget> children;

  /// What fills the screen behind the content. The slowly drifting store
  /// photo when null.
  final Widget? background;

  /// The shade laid over [background] so text on it stays readable.
  final Gradient overlay;

  /// The teal glow the browsing screens add over the shade.
  final bool glow;

  /// Off for a screen that always fits. The scrolling layout measures its
  /// children's intrinsic heights, which a `LayoutBuilder` cannot report.
  final bool scrollable;

  const StyleStage({
    super.key,
    required this.children,
    this.background,
    this.overlay = browseShade,
    this.glow = true,
    this.scrollable = true,
  });

  static const LinearGradient browseShade = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xE0000000), Color(0x6B000000), Color(0xEB000000)],
  );

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final top = (padding.top + 32).clamp(56.0, double.infinity);
    final bottom = (padding.bottom + 16).clamp(32.0, double.infinity);
    final insets = EdgeInsets.fromLTRB(28.w, top, 28.w, bottom);
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.styleStage,
      ),
      child: Scaffold(
        backgroundColor: AppColors.styleStage,
        body: Stack(
          fit: StackFit.expand,
          children: [
            background ?? const DriftingBackdrop(),
            DecoratedBox(decoration: BoxDecoration(gradient: overlay)),
            if (glow) const _Glow(),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: scrollable
                    ? CustomScrollView(
                        slivers: [
                          SliverPadding(
                            padding: insets,
                            sliver: SliverFillRemaining(
                              hasScrollBody: false,
                              child: column,
                            ),
                          ),
                        ],
                      )
                    : Padding(padding: insets, child: column),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The store photo behind the browsing screens, on a pan so slow it reads as
/// a living backdrop rather than motion.
class DriftingBackdrop extends HookWidget {
  const DriftingBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final controller = useAnimationController(
      duration: const Duration(seconds: 16),
    );
    useEffect(() {
      if (!reduceMotion) controller.repeat(reverse: true);
      return null;
    }, [reduceMotion]);

    final image = Image.asset(
      StyleCatalog.stageBackdrop,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
    );

    return ClipRect(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(controller.value);
          final size = MediaQuery.sizeOf(context);
          return Transform.translate(
            offset: Offset(-0.016 * size.width * t, -0.012 * size.height * t),
            child: Transform.scale(scale: 1.08 + 0.07 * t, child: child),
          );
        },
        child: image,
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -1.2),
                radius: 0.9,
                colors: [Color(0x2E16E0C9), Color(0x0016E0C9)],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.85, 1.08),
                radius: 0.8,
                colors: [Color(0x57006554), Color(0x00006554)],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 1.1,
                stops: [0.42, 1],
                colors: [Color(0x00000000), Color(0x99000000)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DicksLogo extends StatelessWidget {
  final double height;

  const DicksLogo({super.key, required this.height});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SvgPicture.asset(
        StyleCatalog.logo,
        height: height,
        semanticsLabel: "DICK'S Sporting Goods",
      ),
    );
  }
}

/// The top of every screen after the intro: the way back, and the brand.
class StyleMasthead extends StatelessWidget {
  final VoidCallback? onBack;

  /// Sits opposite the back control — the shopper's photo, a tagline.
  final Widget? trailing;

  const StyleMasthead({super.key, this.onBack, this.trailing});

  @override
  Widget build(BuildContext context) {
    // As tall as the tallest of its parts, so a long tagline on a small
    // screen pushes the content down rather than spilling into it.
    return Stack(
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DicksLogo(height: 40.r),
              SizedBox(height: 6.r),
              Text(
                'SPORTING GOODS',
                style: styleText(
                  7.5,
                  weight: FontWeight.w600,
                  tracking: 0.5,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.topLeft,
          child: StyleBackButton(onPressed: onBack),
        ),
        if (trailing != null)
          Align(alignment: Alignment.topRight, child: trailing),
      ],
    );
  }
}

/// A ringed arrow over the word BACK, as the site drew it.
class StyleBackButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const StyleBackButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed ?? () => Navigator.of(context).maybePop(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40.r,
              height: 40.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.35),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                size: 17.r,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 4.r),
            Text(
              'BACK',
              style: styleText(
                7,
                weight: FontWeight.w600,
                tracking: 0.25,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A line of small caps between two short fading rules.
class StyleFooterRule extends StatelessWidget {
  final String text;
  final Color ruleColor;
  final TextStyle? style;

  const StyleFooterRule({
    super.key,
    required this.text,
    this.ruleColor = const Color(0x59FFFFFF),
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    Widget rule(bool leading) => Container(
      width: 34.r,
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: leading
              ? [ruleColor.withValues(alpha: 0), ruleColor]
              : [ruleColor, ruleColor.withValues(alpha: 0)],
        ),
      ),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        rule(true),
        SizedBox(width: 12.r),
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style:
                style ??
                styleText(
                  8,
                  weight: FontWeight.w600,
                  tracking: 0.38,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
          ),
        ),
        SizedBox(width: 12.r),
        rule(false),
      ],
    );
  }
}

/// The ringed arrow the tiles end in.
class StyleArrowBadge extends StatelessWidget {
  final double size;
  final Color background;
  final Color border;

  const StyleArrowBadge({
    super.key,
    required this.size,
    this.background = const Color(0x33FFFFFF),
    this.border = const Color(0x59FFFFFF),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: background,
        border: Border.all(color: border),
      ),
      child: Icon(
        Icons.arrow_forward_rounded,
        size: size * 0.45,
        color: Colors.white,
      ),
    );
  }
}

/// A brief shrink under the finger, as the site's `active:scale` gave.
class StylePressable extends HookWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  const StylePressable({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.97,
  });

  @override
  Widget build(BuildContext context) {
    final pressed = useState(false);
    final enabled = onTap != null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => pressed.value = true : null,
      onTapUp: enabled ? (_) => pressed.value = false : null,
      onTapCancel: enabled ? () => pressed.value = false : null,
      onTap: onTap,
      child: AnimatedScale(
        scale: pressed.value ? pressedScale : 1,
        duration: const Duration(milliseconds: 120),
        child: child,
      ),
    );
  }
}

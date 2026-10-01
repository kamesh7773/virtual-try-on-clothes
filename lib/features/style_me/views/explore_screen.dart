import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/routes/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../models/style_catalog.dart';
import '../view_models/style_session_view_model.dart';
import 'widgets/style_stage.dart';

/// SEE YOURSELF STYLED: the five departments, shown while the looks are
/// still being made from the photo just taken.
class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void open(ExploreTile tile) {
      ref.read(styleSessionViewModelProvider.notifier).chooseExplore(tile);
      Navigator.of(context).pushNamed(
        tile.opensApparel ? Routes.styleApparel : Routes.stylePreviews,
      );
    }

    final tiles = StyleCatalog.explore;
    // Two to a row; an odd one out takes a whole row of its own.
    final rows = <List<ExploreTile>>[
      for (var i = 0; i < tiles.length; i += 2)
        tiles.sublist(i, i + 2 > tiles.length ? tiles.length : i + 2),
    ];

    return StyleStage(
      children: [
        const StyleMasthead(trailing: _Motto()),
        SizedBox(height: 28.r),
        Text.rich(
          TextSpan(
            text: 'SEE YOURSELF ',
            children: const [
              TextSpan(
                text: 'STYLED',
                style: TextStyle(color: AppColors.styleTeal),
              ),
            ],
          ),
          textAlign: TextAlign.center,
          style: styleText(
            27,
            weight: FontWeight.w700,
            tracking: 0.01,
            height: 1,
            shadows: styleTextShadow,
          ),
        ),
        SizedBox(height: 10.r),
        Text(
          'Choose a category to get started.',
          textAlign: TextAlign.center,
          style: styleText(
            13,
            height: 1.35,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        SizedBox(height: 20.r),
        for (var r = 0; r < rows.length; r++) ...[
          if (r > 0) SizedBox(height: 12.r),
          Row(
            children: [
              for (var c = 0; c < rows[r].length; c++) ...[
                if (c > 0) SizedBox(width: 12.r),
                Expanded(
                  child: _ExploreCard(
                    tile: rows[r][c],
                    wide: rows[r].length == 1,
                    onTap: () => open(rows[r][c]),
                  ),
                ),
              ],
            ],
          ),
        ],
        SizedBox(height: 16.r),
        const _AiPreviewNote(),
        const Spacer(),
        SizedBox(height: 20.r),
        const StyleFooterRule(text: 'SPORTS BRING US TOGETHER™'),
      ],
    );
  }
}

class _Motto extends StatelessWidget {
  const _Motto();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'SPORT\nSTYLE\nLIFE\nTOGETHER',
          textAlign: TextAlign.right,
          style: styleText(
            7,
            weight: FontWeight.w600,
            tracking: 0.24,
            height: 1.9,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
        SizedBox(height: 6.r),
        Container(
          width: 28.r,
          height: 2,
          decoration: BoxDecoration(
            color: AppColors.styleTeal,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

class _ExploreCard extends StatelessWidget {
  final ExploreTile tile;
  final bool wide;
  final VoidCallback onTap;

  const _ExploreCard({
    required this.tile,
    required this.wide,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // One line, shrunk to fit beside the arrow: a department name
        // broken mid-word reads as two words.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            tile.label,
            maxLines: 1,
            style: styleText(
              17,
              weight: FontWeight.w700,
              tracking: 0.025,
              height: 1,
            ),
          ),
        ),
        SizedBox(height: 6.r),
        Text(
          tile.sub,
          style: styleText(
            9,
            weight: FontWeight.w600,
            tracking: 0.16,
            color: Colors.white.withValues(alpha: 0.65),
          ),
        ),
      ],
    );
    final badge = ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: StyleArrowBadge(size: 36.r),
      ),
    );

    return StylePressable(
      onTap: onTap,
      pressedScale: 0.98,
      child: Semantics(
        button: true,
        label: tile.label,
        child: Container(
          height: wide ? 96.r : 178.r,
          foregroundDecoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(tile.image, fit: BoxFit.cover),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: wide ? _wideShade : _tallShade,
                  ),
                ),
                Padding(
                  padding: wide
                      ? EdgeInsets.symmetric(horizontal: 20.r)
                      : EdgeInsets.fromLTRB(16.r, 0, 16.r, 14.r),
                  child: Row(
                    crossAxisAlignment: wide
                        ? CrossAxisAlignment.center
                        : CrossAxisAlignment.end,
                    children: [
                      Expanded(child: label),
                      SizedBox(width: 8.r),
                      badge,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const LinearGradient _wideShade = LinearGradient(
    stops: [0, 0.26, 0.5, 0.74, 1],
    colors: [
      Color(0xF5000000),
      Color(0xEB000000),
      Color(0x94000000),
      Color(0x2E000000),
      Color(0x52000000),
    ],
  );

  /// Dark under the label and clear above it. The site measured the stops
  /// in points up a 178-point card.
  static const LinearGradient _tallShade = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    stops: [0, 58 / 178, 92 / 178, 132 / 178],
    colors: [
      Color(0xF7000000),
      Color(0xE6000000),
      Color(0x73000000),
      Color(0x00000000),
    ],
  );
}

class _AiPreviewNote extends StatelessWidget {
  const _AiPreviewNote();

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: radius,
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.auto_awesome_outlined,
                size: 28.r,
                color: AppColors.styleTeal,
              ),
              SizedBox(width: 14.r),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI-STYLED PREVIEW',
                      style: styleText(
                        10,
                        weight: FontWeight.w700,
                        tracking: 0.2,
                      ),
                    ),
                    SizedBox(height: 6.r),
                    Text(
                      'Looks are AI-generated and may not perfectly '
                      'represent actual fit, colour, or appearance.',
                      style: styleText(
                        11.5,
                        height: 1.35,
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                    SizedBox(height: 12.r),
                    Row(
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 14.r,
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                        SizedBox(width: 8.r),
                        Flexible(
                          child: Text(
                            'Your photo is never stored or saved.',
                            style: styleText(
                              10,
                              weight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.r),
              Transform.rotate(
                angle: -11 * math.pi / 180,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'REAL\nPEOPLE\nREAL\nPOSSIBILITIES',
                      textAlign: TextAlign.center,
                      style: styleText(
                        9.5,
                        weight: FontWeight.w700,
                        fontStyle: FontStyle.italic,
                        tracking: 0.02,
                        height: 1.3,
                      ),
                    ),
                    SizedBox(height: 4.r),
                    Container(
                      width: 70.r,
                      height: 2,
                      decoration: BoxDecoration(
                        color: AppColors.styleTeal,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

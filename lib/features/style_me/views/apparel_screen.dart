import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/routes/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../models/style_catalog.dart';
import '../view_models/style_session_view_model.dart';
import 'widgets/style_stage.dart';

/// STYLE ME · APPAREL: the shelves, each restyling the looks for who and
/// what it names.
class ApparelScreen extends ConsumerWidget {
  const ApparelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adult = ref.watch(
      styleSessionViewModelProvider.select((s) => s.adult),
    );

    void open(ApparelTile tile) {
      ref.read(styleSessionViewModelProvider.notifier).chooseApparel(tile);
      Navigator.of(context).pushNamed(Routes.stylePreviews);
    }

    return StyleStage(
      children: [
        const StyleMasthead(),
        SizedBox(height: 24.r),
        Text(
          'STYLE ME',
          textAlign: TextAlign.center,
          style: styleText(
            10,
            weight: FontWeight.w500,
            tracking: 0.5,
            color: Colors.white.withValues(alpha: 0.65),
          ),
        ),
        Text(
          'APPAREL',
          textAlign: TextAlign.center,
          style: styleText(
            42,
            weight: FontWeight.w700,
            tracking: -0.025,
            height: 1,
            shadows: styleTextShadow,
          ),
        ),
        SizedBox(height: 8.r),
        Center(
          child: Container(
            width: 56.r,
            height: 3,
            decoration: BoxDecoration(
              color: AppColors.styleTeal,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        SizedBox(height: 28.r),
        for (final tile in StyleCatalog.apparelFor(adult)) ...[
          _ApparelRow(tile: tile, onTap: () => open(tile)),
          SizedBox(height: 12.r),
        ],
        // const Spacer(),
        SizedBox(height: 80.r),
        StyleFooterRule(
          text: 'SELECT A CATEGORY TO CONTINUE',
          ruleColor: AppColors.styleTeal,
          style: styleText(
            9,
            weight: FontWeight.w500,
            tracking: 0.35,
            color: Colors.white.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }
}

class _ApparelRow extends StatelessWidget {
  final ApparelTile tile;
  final VoidCallback onTap;

  const _ApparelRow({required this.tile, required this.onTap});

  static const LinearGradient _shade = LinearGradient(
    stops: [0, 0.28, 0.52, 0.78, 1],
    colors: [
      Color(0xF7060E0C),
      Color(0xED060E0C),
      Color(0x8C060E0C),
      Color(0x38060E0C),
      Color(0x59060E0C),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return StylePressable(
      onTap: onTap,
      pressedScale: 0.99,
      child: Semantics(
        button: true,
        label: tile.label,
        child: Container(
          height: 68.r,
          foregroundDecoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Drawn a little wider than the row, anchored left, so the
                // product sits right of the label rather than under it.
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 1.18,
                  child: Image.asset(tile.image, fit: BoxFit.cover),
                ),
                const DecoratedBox(decoration: BoxDecoration(gradient: _shade)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.r),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          tile.label,
                          style: styleText(
                            16,
                            weight: FontWeight.w600,
                            tracking: 0.025,
                            height: 1,
                          ),
                        ),
                      ),
                      StyleArrowBadge(
                        size: 32.r,
                        background: const Color(0x8C060E0C),
                        border: AppColors.styleTeal,
                      ),
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
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import 'style_stage.dart';

/// The framing guide over the camera: a lit window with teal corners, the
/// rest of the screen dimmed around it, and the two hand-written notes.
class CaptureFrame extends StatelessWidget {
  /// The notes only make sense over a live picture.
  final bool showNotes;

  const CaptureFrame({super.key, required this.showNotes});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        // The frame sits in the middle 62% of the width, as on the site.
        FractionallySizedBox(
          widthFactor: 0.62,
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              const IgnorePointer(child: CustomPaint(painter: _DimPainter())),
              for (final corner in _Corner.values) _CornerMark(corner: corner),
            ],
          ),
        ),
        if (showNotes) ...[
          const _MarkerNote(
            title: 'Step\nback',
            sub: 'Full body\nin frame',
            left: true,
            top: 0.20,
          ),
          const _MarkerNote(
            title: 'Look\nhere',
            sub: 'Stand\nnaturally',
            left: false,
            top: 0.46,
          ),
        ],
      ],
    );
  }
}

/// Darkens everything outside the window, the whole screen over, the way
/// the site's `box-shadow: 0 0 0 100vmax` did. Paints beyond its own box on
/// purpose.
class _DimPainter extends CustomPainter {
  const _DimPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // The window reaches a little past the corner marks on every side.
    final window = RRect.fromRectAndRadius(
      Rect.fromLTRB(-size.width * 0.21, -8, size.width * 1.21, size.height + 8),
      const Radius.circular(32),
    );
    final reach = math.max(size.width, size.height) * 6;
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Rect.fromLTRB(-reach, -reach, reach, reach))
      ..addRRect(window);
    canvas.drawPath(path, Paint()..color = const Color(0x57000000));
  }

  @override
  bool shouldRepaint(_DimPainter oldDelegate) => false;
}

enum _Corner { topLeft, topRight, bottomLeft, bottomRight }

class _CornerMark extends StatelessWidget {
  final _Corner corner;

  const _CornerMark({required this.corner});

  @override
  Widget build(BuildContext context) {
    final flipX = corner == _Corner.topRight || corner == _Corner.bottomRight;
    final flipY = corner == _Corner.bottomLeft || corner == _Corner.bottomRight;
    final size = 64.r;

    return Positioned(
      left: flipX ? null : 0,
      right: flipX ? 0 : null,
      top: flipY ? null : 0,
      bottom: flipY ? 0 : null,
      width: size,
      height: size,
      child: Transform.scale(
        scaleX: flipX ? -1 : 1,
        scaleY: flipY ? -1 : 1,
        child: const CustomPaint(painter: _CornerPainter()),
      ),
    );
  }
}

/// `M54 2H11Q2 2 2 11V54` in a 56-unit box: an L with a rounded elbow.
class _CornerPainter extends CustomPainter {
  const _CornerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 56;
    final path = Path()
      ..moveTo(54 * s, 2 * s)
      ..lineTo(11 * s, 2 * s)
      ..quadraticBezierTo(2 * s, 2 * s, 2 * s, 11 * s)
      ..lineTo(2 * s, 54 * s);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4 * s
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4 * s
        ..strokeCap = StrokeCap.round
        ..color = AppColors.styleTeal.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(path, stroke..color = AppColors.styleTeal);
  }

  @override
  bool shouldRepaint(_CornerPainter oldDelegate) => false;
}

/// A hand-lettered note with a curved arrow pointing into the frame.
class _MarkerNote extends StatelessWidget {
  final String title;
  final String sub;
  final bool left;

  /// From the top of the camera area, as a fraction of its height.
  final double top;

  const _MarkerNote({
    required this.title,
    required this.sub,
    required this.left,
    required this.top,
  });

  static const List<Shadow> _shadow = [
    Shadow(color: Color(0xF2000000), offset: Offset(0, 2), blurRadius: 10),
  ];

  @override
  Widget build(BuildContext context) {
    final lines = title.toUpperCase().split('\n');
    final align = left ? CrossAxisAlignment.start : CrossAxisAlignment.end;

    return Align(
      alignment: Alignment(left ? -1 : 1, top * 2 - 1),
      child: FractionalTranslation(
        // Align places the note's own matching point on the line; the site
        // hung the note from its top edge.
        translation: Offset(0, top),
        child: IgnorePointer(
          child: SizedBox(
            width: 96.r,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: align,
              children: [
                for (var i = 0; i < lines.length; i++)
                  Transform.translate(
                    offset: Offset((left ? 7 : -4) * i.toDouble(), 0),
                    child: Transform.rotate(
                      angle: ((left ? -9 : 7) + i * 1.5) * math.pi / 180,
                      child: Text(
                        lines[i],
                        textAlign: left ? TextAlign.left : TextAlign.right,
                        softWrap: false,
                        overflow: TextOverflow.visible,
                        style: TextStyle(
                          fontFamily: 'CaveatBrush',
                          fontSize: 27.sp,
                          height: 0.92,
                          letterSpacing: 0.03 * 27.sp,
                          color: Colors.white,
                          shadows: _shadow,
                        ),
                      ),
                    ),
                  ),
                Align(
                  alignment: left
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Transform.translate(
                    offset: Offset(left ? 20.r : -20.r, 0),
                    child: Padding(
                      padding: EdgeInsets.only(top: 4.r, bottom: 8.r),
                      child: CustomPaint(
                        size: Size(66.r, 34.r),
                        painter: _ArrowPainter(left: left),
                      ),
                    ),
                  ),
                ),
                Text(
                  sub.toUpperCase(),
                  textAlign: left ? TextAlign.left : TextAlign.right,
                  style: styleText(
                    9.5,
                    weight: FontWeight.w600,
                    tracking: 0.2,
                    height: 1.65,
                    shadows: _shadow,
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

/// The curved arrow from the note into the frame, in the site's 72×44 box.
class _ArrowPainter extends CustomPainter {
  final bool left;

  const _ArrowPainter({required this.left});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 72, size.height / 44);
    final path = left
        ? (Path()
            ..moveTo(5, 9)
            ..cubicTo(24, 6, 45, 14, 62, 34)
            ..moveTo(62, 34)
            ..lineTo(49.4, 30.6)
            ..moveTo(62, 34)
            ..lineTo(58.6, 21.4))
        : (Path()
            ..moveTo(67, 9)
            ..cubicTo(48, 6, 27, 14, 10, 34)
            ..moveTo(10, 34)
            ..lineTo(22.6, 30.6)
            ..moveTo(10, 34)
            ..lineTo(13.4, 21.4));

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xF2000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(path, paint..color = Colors.white);
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) => oldDelegate.left != left;
}

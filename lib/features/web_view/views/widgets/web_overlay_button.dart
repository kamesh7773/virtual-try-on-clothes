import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// A round control that floats over a web page.
///
/// Floating rather than sitting in chrome of its own: the browser screen has
/// none, and a bar across the top would cost every site height for a control
/// only some of them need.
class WebOverlayButton extends StatelessWidget {
  final IconData icon;

  /// What a screen reader calls it — the icon is the only label on screen.
  final String label;

  final VoidCallback onTap;

  const WebOverlayButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  static const double _size = 40;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        // Dark and translucent so it reads against both a retailer's white
        // page and a product shot that fills the width behind it.
        color: const Color(0xB3000000),
        shape: const CircleBorder(side: BorderSide(color: Color(0x33FFFFFF))),
        clipBehavior: Clip.antiAlias,
        elevation: 4,
        shadowColor: const Color(0x66000000),
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: _size.r,
            height: _size.r,
            child: Icon(icon, size: 16.sp, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

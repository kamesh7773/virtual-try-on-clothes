import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../services/internet_service.dart';
import '../theme/app_colors.dart';

/// Wraps any child and overlays a connectivity banner when the device is
/// offline. Place near the root of a screen (e.g. inside `AppScaffold`) or
/// around a feature widget that needs network awareness.
class InternetCheckerWidget extends HookConsumerWidget {
  final Widget child;
  final String offlineMessage;
  final String onlineMessage;
  final bool showOnlineRestored;
  final EdgeInsetsGeometry padding;

  const InternetCheckerWidget({
    super.key,
    required this.child,
    this.offlineMessage = 'No internet connection',
    this.onlineMessage = 'Back online',
    this.showOnlineRestored = false,
    this.padding = const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(internetServiceProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) => SizeTransition(
            sizeFactor: animation,
            alignment: Alignment.topCenter,
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: !isOnline
              ? _StatusBanner(
                  key: const ValueKey('offline'),
                  message: offlineMessage,
                  color: AppColors.error,
                  icon: Icons.wifi_off_rounded,
                  padding: padding,
                )
              : (showOnlineRestored
                  ? _StatusBanner(
                      key: const ValueKey('online'),
                      message: onlineMessage,
                      color: AppColors.success,
                      icon: Icons.wifi_rounded,
                      padding: padding,
                    )
                  : const SizedBox.shrink(key: ValueKey('idle'))),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String message;
  final Color color;
  final IconData icon;
  final EdgeInsetsGeometry padding;

  const _StatusBanner({
    super.key,
    required this.message,
    required this.color,
    required this.icon,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: padding,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 16.sp),
              SizedBox(width: 8.w),
              Text(
                message,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/routes/route_arguments.dart';
import '../../../../core/routes/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../models/web_destination.dart';

/// Opens the list of sites the app can browse without leaving it.
///
/// A sheet rather than a screen: with only a couple of destinations, a whole
/// route would be one extra tap for nothing.
Future<void> showWebDestinationSheet(
  BuildContext context, {
  List<WebDestination> destinations = WebDestinations.all,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.stageSurface,
    shape: const RoundedRectangleBorder(),
    builder: (_) => _DestinationSheet(destinations: destinations),
  );
}

class _DestinationSheet extends StatelessWidget {
  final List<WebDestination> destinations;

  const _DestinationSheet({required this.destinations});

  void _open(BuildContext context, WebDestination destination) {
    final navigator = Navigator.of(context);
    // Close the sheet first so back from the browser lands on the home.
    navigator.pop();
    navigator.pushNamed(
      Routes.webView,
      arguments: WebViewScreenArgs(destination: destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      // Scrollable because the sheet grows with the destination list, and a
      // large text scale can push even this one past a short screen.
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 10.h),
              child: Text(
                'BROWSE',
                style: TextStyle(
                  fontSize: 9.sp,
                  color: AppColors.onStageFaint,
                  letterSpacing: 3,
                ),
              ),
            ),
            for (final destination in destinations)
              _DestinationTile(
                destination: destination,
                onTap: () => _open(context, destination),
              ),
            SizedBox(height: 10.h),
          ],
        ),
      ),
    );
  }
}

class _DestinationTile extends StatelessWidget {
  final WebDestination destination;
  final VoidCallback onTap;

  const _DestinationTile({required this.destination, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
        child: Row(
          children: [
            Icon(
              Icons.language_rounded,
              size: 16.sp,
              color: AppColors.onStageFaint,
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    destination.title.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AppColors.onStagePrimary,
                      letterSpacing: 1.6,
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    destination.host,
                    style: TextStyle(
                      fontSize: 9.sp,
                      color: AppColors.onStageFaint,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 12.sp,
              color: AppColors.onStageFaint,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/routes/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../try_on/views/widgets/live_look_wordmark.dart';
import '../../web_view/models/web_destination.dart';
import '../../web_view/view_models/url_history_view_model.dart';
import '../../web_view/views/widgets/web_destination_menu.dart';
import 'widgets/home_option_tile.dart';

/// The app's front door: what LiveLook can do, and what it has already done.
///
/// The two modes carry no state of their own — the camera, the catalog and
/// the browser each start on the screen that needs them. The history does,
/// so it is read here to show how much of it there is.
class HomeScreen extends HookConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(urlHistoryViewModelProvider);
    final historyViewModel = ref.read(urlHistoryViewModelProvider.notifier);

    useEffect(() {
      // Touching a provider inside initHook throws, so the stored record is
      // read once the frame is done.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => historyViewModel.load(),
      );
      return null;
    }, const []);

    return Scaffold(
      backgroundColor: AppColors.stageBackground,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const LiveLookWordmark(fontSize: 30),
              SizedBox(height: 6.h),
              Text(
                'CHOOSE A MODE',
                style: TextStyle(
                  fontSize: 9.sp,
                  color: AppColors.onStageFaint,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w300,
                ),
              ),
              SizedBox(height: 40.h),
              HomeOptionTile(
                icon: Icons.camera_alt_outlined,
                title: 'VIRTUAL TRY-ON',
                subtitle: 'See a garment on you, live',
                onTap: () => Navigator.of(context).pushNamed(Routes.tryOn),
              ),
              SizedBox(height: 14.h),
              HomeOptionTile(
                icon: Icons.language_rounded,
                title: 'WEB VIEW',
                subtitle:
                    '${WebDestinations.all.length} sites, opened in the app',
                onTap: () => showWebDestinationSheet(context),
              ),
              SizedBox(height: 14.h),
              HomeOptionTile(
                icon: Icons.history_rounded,
                title: 'HISTORY',
                subtitle: history.isEmpty
                    ? 'Every page the browser opens is saved here'
                    : history.total == 1
                    ? '1 page opened'
                    : '${history.total} pages opened',
                onTap: () => Navigator.of(context).pushNamed(Routes.urlHistory),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

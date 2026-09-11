import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/routes/route_arguments.dart';
import '../../../core/routes/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/stage_back_button.dart';
import '../models/url_visit.dart';
import '../utils/visit_format.dart';
import '../view_models/url_history_view_model.dart';

/// Every page the in-app browser has opened, newest first.
///
/// Each row carries what the browser itself no longer shows: the full URL,
/// when it was hit, how long it took, and whether it loaded at all.
class UrlHistoryScreen extends HookConsumerWidget {
  const UrlHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(urlHistoryViewModelProvider);
    final viewModel = ref.read(urlHistoryViewModelProvider.notifier);

    useEffect(() {
      // Touching a provider inside initHook throws, so the first read waits
      // for the frame to finish.
      WidgetsBinding.instance.addPostFrameCallback((_) => viewModel.load());
      return null;
    }, const []);

    return Scaffold(
      backgroundColor: AppColors.stageBackground,
      body: SafeArea(
        child: Column(
          children: [
            _Masthead(
              total: history.total,
              onClear: history.isEmpty ? null : viewModel.clear,
            ),
            Expanded(
              child: history.isEmpty
                  ? const _Empty()
                  : ListView.separated(
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      itemCount: history.visits.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        thickness: 1,
                        color: AppColors.stageBorder,
                        indent: 20.w,
                        endIndent: 20.w,
                      ),
                      itemBuilder: (_, index) =>
                          _VisitRow(visit: history.visits[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Masthead extends StatelessWidget {
  final int total;
  final VoidCallback? onClear;

  const _Masthead({required this.total, this.onClear});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            children: [
              Text(
                'HISTORY',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppColors.onStagePrimary,
                  letterSpacing: 1.8,
                ),
              ),
              SizedBox(height: 3.h),
              Text(
                total == 1 ? '1 visit' : '$total visits',
                style: TextStyle(
                  fontSize: 9.sp,
                  color: AppColors.onStageFaint,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const Positioned(left: 0, child: StageBackButton()),
          if (onClear != null)
            Positioned(
              right: 0,
              child: TextButton(
                onPressed: onClear,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.onStageMuted,
                  padding: EdgeInsets.symmetric(horizontal: 8.w),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'CLEAR',
                  style: TextStyle(fontSize: 9.sp, letterSpacing: 1.4),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VisitRow extends StatelessWidget {
  final UrlVisit visit;

  const _VisitRow({required this.visit});

  /// A row opens the record, not the page. Reopening the page is one tap
  /// further in, where the URL is visible and the choice is deliberate.
  void _openDetail(BuildContext context) {
    Navigator.of(context).pushNamed(
      Routes.urlVisitDetail,
      arguments: UrlVisitDetailArgs(visit: visit),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openDetail(context),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: 2.h),
              child: Icon(
                visit.didFail
                    ? Icons.error_outline_rounded
                    : Icons.language_rounded,
                size: 15.sp,
                color: visit.didFail ? AppColors.error : AppColors.onStageFaint,
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    visit.tappedLabel ??
                        (visit.title?.isNotEmpty == true
                            ? visit.title!
                            : visit.host),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AppColors.onStagePrimary,
                      letterSpacing: 0.4,
                    ),
                  ),
                  if (visit.tappedContext != null) ...[
                    SizedBox(height: 3.h),
                    Text(
                      '${visit.trigger.label} under '
                      '${visit.tappedContext}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.sp,
                        color: AppColors.onStageFaint,
                      ),
                    ),
                  ],
                  SizedBox(height: 4.h),
                  Text(
                    visit.url,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.sp,
                      height: 1.4,
                      color: AppColors.onStageMuted,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    formatVisitStatusLine(visit),
                    style: TextStyle(
                      fontSize: 9.sp,
                      color: visit.didFail
                          ? AppColors.error
                          : AppColors.onStageFaint,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history_rounded,
              size: 30.r,
              color: AppColors.onStageFaint,
            ),
            SizedBox(height: 14.h),
            Text(
              'Nothing opened yet. Every page the browser loads is recorded '
              'here with the time it was hit.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.sp,
                height: 1.5,
                color: AppColors.onStageMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

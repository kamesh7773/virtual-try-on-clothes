import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/routes/route_arguments.dart';
import '../../../core/routes/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/stage_back_button.dart';
import '../models/url_visit.dart';
import '../models/web_destination.dart';
import '../utils/visit_format.dart';

/// Everything recorded about one page the browser opened.
///
/// The browser itself shows no address and no chrome, so this is where the
/// full URL, the tap that led to it and the timings can actually be read.
class UrlVisitDetailScreen extends ConsumerWidget {
  final UrlVisit visit;

  const UrlVisitDetailScreen({super.key, required this.visit});

  void _openAgain(BuildContext context) {
    Navigator.of(context).pushNamed(
      Routes.webView,
      arguments: WebViewScreenArgs(
        destination: WebDestination(
          id: visit.id,
          title: visit.title ?? visit.host,
          url: visit.url,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = visit.queryParameters;

    return Scaffold(
      backgroundColor: AppColors.stageBackground,
      body: SafeArea(
        child: Column(
          children: [
            _Masthead(visit: visit),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 24.h),
                children: [
                  _Section(
                    title: 'THE TAP',
                    rows: [
                      _Row(label: 'How', value: visit.trigger.label),
                      if (visit.tappedLabel != null)
                        _Row(label: 'Tapped', value: visit.tappedLabel!),
                      if (visit.tappedContext != null)
                        _Row(label: 'Under', value: visit.tappedContext!),
                      if (visit.sourceTitle != null)
                        _Row(label: 'From page', value: visit.sourceTitle!),
                      if (visit.sourceUrl != null)
                        _Row(
                          label: 'From URL',
                          value: visit.sourceUrl!,
                          selectable: true,
                        ),
                      if (visit.tappedLabel == null && visit.sourceUrl == null)
                        const _Row(
                          label: 'Tapped',
                          value: 'Nothing — the app opened this page itself',
                        ),
                    ],
                  ),
                  _Section(
                    title: 'WHEN',
                    rows: [
                      _Row(
                        label: 'Hit at',
                        value:
                            '${formatVisitDate(visit.openedAt)}, '
                            '${formatVisitTime(visit.openedAt)}',
                      ),
                      _Row(
                        label: 'That was',
                        value: formatVisitAgo(visit.openedAt),
                      ),
                      _Row(
                        label: 'Outcome',
                        value: formatVisitOutcome(visit),
                        isError: visit.didFail,
                      ),
                      if (visit.loadTime != null)
                        _Row(
                          label: 'Load time',
                          value: formatVisitDuration(visit.loadTime!),
                        ),
                    ],
                  ),
                  _Section(
                    title: 'THE PAGE',
                    rows: [
                      if (visit.title != null)
                        _Row(label: 'Title', value: visit.title!),
                      _Row(label: 'Host', value: visit.host),
                      _Row(label: 'URL', value: visit.url, selectable: true),
                      if (visit.pathSegments.isNotEmpty)
                        _Row(
                          label: 'Path',
                          value: visit.pathSegments.join('  ›  '),
                        ),
                      _Row(label: 'Opened from', value: visit.destinationId),
                    ],
                  ),
                  if (query.isNotEmpty)
                    _Section(
                      title: 'QUERY',
                      rows: [
                        for (final entry in query.entries)
                          _Row(
                            label: entry.key,
                            value: entry.value.isEmpty ? '—' : entry.value,
                          ),
                      ],
                    ),
                  SizedBox(height: 8.h),
                  OutlinedButton(
                    onPressed: () => _openAgain(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.onStagePrimary,
                      side: const BorderSide(
                        color: AppColors.stageBorderActive,
                      ),
                      shape: const RoundedRectangleBorder(),
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                    ),
                    child: Text(
                      'OPEN AGAIN',
                      style: TextStyle(fontSize: 10.sp, letterSpacing: 2),
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

class _Masthead extends StatelessWidget {
  final UrlVisit visit;

  const _Masthead({required this.visit});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40.w),
            child: Column(
              children: [
                Text(
                  visit.tappedLabel ?? visit.title ?? visit.host,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppColors.onStagePrimary,
                    letterSpacing: 1.4,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  visit.host,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.sp,
                    color: AppColors.onStageFaint,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          const Positioned(left: 0, child: StageBackButton()),
          Positioned(
            right: 0,
            child: IconButton(
              icon: Icon(Icons.copy_rounded, size: 16.sp),
              color: AppColors.onStageMuted,
              tooltip: 'Copy URL',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: visit.url));
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  SnackBar(
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: AppColors.stageElevated,
                    duration: const Duration(seconds: 2),
                    shape: const RoundedRectangleBorder(),
                    content: Text(
                      'URL copied',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: AppColors.onStageSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<_Row> rows;

  const _Section({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 18.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 9.sp,
              color: AppColors.onStageFaint,
              letterSpacing: 3,
            ),
          ),
          SizedBox(height: 10.h),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.stageSurface,
              border: Border.all(color: AppColors.stageBorder),
            ),
            child: Column(children: rows),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool selectable;
  final bool isError;

  const _Row({
    required this.label,
    required this.value,
    this.selectable = false,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final valueStyle = TextStyle(
      fontSize: 10.sp,
      height: 1.5,
      color: isError ? AppColors.error : AppColors.onStageSecondary,
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86.w,
            child: Text(
              label,
              style: TextStyle(fontSize: 9.sp, color: AppColors.onStageFaint),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: selectable
                ? SelectableText(value, style: valueStyle)
                : Text(value, style: valueStyle),
          ),
        ],
      ),
    );
  }
}

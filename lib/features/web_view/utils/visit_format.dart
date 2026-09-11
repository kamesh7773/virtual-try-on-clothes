import '../models/url_visit.dart';

const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "11 Sep 2026"
String formatVisitDate(DateTime at) =>
    '${at.day} ${_months[at.month - 1]} ${at.year}';

/// "13:55" — 24-hour, so it reads the same in every locale the app ships in.
String formatVisitTime(DateTime at) =>
    '${at.hour.toString().padLeft(2, '0')}:'
    '${at.minute.toString().padLeft(2, '0')}';

String formatVisitAgo(DateTime at) {
  final elapsed = DateTime.now().difference(at);
  if (elapsed.inMinutes < 1) return 'just now';
  if (elapsed.inHours < 1) return '${elapsed.inMinutes}m ago';
  if (elapsed.inDays < 1) return '${elapsed.inHours}h ago';
  return '${elapsed.inDays}d ago';
}

String formatVisitDuration(Duration duration) => duration.inMilliseconds < 1000
    ? '${duration.inMilliseconds}ms'
    : '${(duration.inMilliseconds / 1000).toStringAsFixed(1)}s';

/// What happened to the page, in the words a row can carry.
String formatVisitOutcome(UrlVisit visit) {
  if (visit.didFail) return visit.error!;
  if (visit.isLoading) return 'did not finish loading';
  return 'loaded in ${formatVisitDuration(visit.loadTime!)}';
}

/// "11 Sep 2026, 13:55 · just now · loaded in 1.2s"
String formatVisitStatusLine(UrlVisit visit) {
  final when =
      '${formatVisitDate(visit.openedAt)}, ${formatVisitTime(visit.openedAt)}';
  return '$when · ${formatVisitAgo(visit.openedAt)} · '
      '${formatVisitOutcome(visit)}';
}

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:virtual_try_on/core/constants/app_constants.dart';
import 'package:virtual_try_on/core/routes/route_arguments.dart';
import 'package:virtual_try_on/core/routes/routes.dart';
import 'package:virtual_try_on/features/web_view/models/url_visit.dart';
import 'package:virtual_try_on/features/web_view/models/visit_trigger.dart';
import 'package:virtual_try_on/features/web_view/views/url_visit_detail_screen.dart';

final _visit = UrlVisit(
  id: 'v1',
  url: 'https://www.dickssportinggoods.com/f/mens-golf-apparel?sort=relevance',
  destinationId: 'mirror',
  openedAt: DateTime.now(),
  title: "Men's Golf Apparel",
  loadTime: const Duration(milliseconds: 1200),
  trigger: VisitTrigger.element,
  tappedLabel: 'GET THIS STYLE',
  tappedContext: "MEN'S APPAREL",
  sourceUrl: 'https://mirror.maxaix.com/',
  sourceTitle: 'LiveLook Mirror',
);

Widget _app({RouteFactory? onGenerateRoute}) => ProviderScope(
  child: MaterialApp(
    onGenerateRoute: onGenerateRoute,
    home: Builder(
      builder: (context) {
        ScreenUtil.init(
          context,
          designSize: const Size(
            AppConstants.designWidth,
            AppConstants.designHeight,
          ),
        );
        return UrlVisitDetailScreen(visit: _visit);
      },
    ),
  ),
);

/// The record is longer than a phone screen, so the rows further down have to
/// be scrolled to before they exist.
Future<void> _scrollTo(WidgetTester tester, Finder target) =>
    tester.scrollUntilVisible(
      target,
      120,
      // The selectable URL rows are scrollable in their own right, so the
      // page's own list has to be named rather than guessed at.
      scrollable: find.byType(Scrollable).first,
    );

void main() {
  testWidgets('shows what was tapped and where it came from', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Tapped a card'), findsOneWidget);
    expect(find.text('GET THIS STYLE'), findsWidgets);
    expect(find.text("MEN'S APPAREL"), findsOneWidget);
    expect(find.text('LiveLook Mirror'), findsOneWidget);
    expect(find.text('https://mirror.maxaix.com/'), findsOneWidget);
  });

  testWidgets('shows when it was hit and how long it took', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('just now'), findsOneWidget);
    expect(find.text('loaded in 1.2s'), findsOneWidget);
    expect(find.text('1.2s'), findsOneWidget);
  });

  testWidgets('breaks the URL into its parts', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('f  ›  mens-golf-apparel'));

    expect(find.text('www.dickssportinggoods.com'), findsWidgets);
    expect(find.text('f  ›  mens-golf-apparel'), findsOneWidget);
    // The query is where a retail URL keeps the sort, the filters and the
    // search term, so each pair gets its own row.
    await _scrollTo(tester, find.text('relevance'));
    expect(find.text('sort'), findsOneWidget);
    expect(find.text('relevance'), findsOneWidget);
  });

  testWidgets('can open the page again', (tester) async {
    RouteSettings? pushed;

    await tester.pumpWidget(
      _app(
        onGenerateRoute: (settings) {
          pushed = settings;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const SizedBox.shrink(),
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('OPEN AGAIN'));

    await tester.tap(find.text('OPEN AGAIN'));
    await tester.pumpAndSettle();

    expect(pushed?.name, Routes.webView);
    final args = pushed?.arguments as WebViewScreenArgs?;
    expect(args?.destination.url, _visit.url);
  });
}

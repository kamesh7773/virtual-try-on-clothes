import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:virtual_try_on/core/constants/app_constants.dart';
import 'package:virtual_try_on/core/routes/route_arguments.dart';
import 'package:virtual_try_on/core/routes/routes.dart';
import 'package:virtual_try_on/features/web_view/models/visit_trigger.dart';
import 'package:virtual_try_on/features/web_view/view_models/url_history_view_model.dart';
import 'package:virtual_try_on/features/web_view/views/url_history_screen.dart';

/// Reopening a row pushes the browser route, which hosts a platform view a
/// widget test cannot build — so the route is intercepted instead.
Widget _app(ProviderContainer container, {RouteFactory? onGenerateRoute}) =>
    UncontrolledProviderScope(
      container: container,
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
            return const UrlHistoryScreen();
          },
        ),
      ),
    );

void main() {
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
    container.listen(
      urlHistoryViewModelProvider,
      (_, _) {},
      fireImmediately: true,
    );
  });
  tearDown(() => container.dispose());

  UrlHistoryViewModel viewModel() =>
      container.read(urlHistoryViewModelProvider.notifier);

  testWidgets('says so when nothing has been opened yet', (tester) async {
    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    expect(find.textContaining('Nothing opened yet'), findsOneWidget);
    expect(find.text('0 visits'), findsOneWidget);
    // Nothing to clear, so the action is not offered.
    expect(find.text('CLEAR'), findsNothing);
  });

  testWidgets('lists a visit with its URL and what happened', (tester) async {
    final id = viewModel().record(
      url: 'https://mirror.maxaix.com/fit',
      destinationId: 'mirror',
    );
    viewModel().markLoaded(
      id,
      title: 'Mirror',
      loadTime: const Duration(milliseconds: 1200),
    );

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    expect(find.text('Mirror'), findsOneWidget);
    expect(find.text('https://mirror.maxaix.com/fit'), findsOneWidget);
    expect(find.textContaining('loaded in 1.2s'), findsOneWidget);
    expect(find.textContaining('just now'), findsOneWidget);
    expect(find.text('1 visit'), findsOneWidget);
  });

  testWidgets('shows the reason a page failed', (tester) async {
    final id = viewModel().record(
      url: 'https://mirror.maxaix.com',
      destinationId: 'mirror',
    );
    viewModel().markFailed(id, 'net::ERR_TIMED_OUT');

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    expect(find.textContaining('net::ERR_TIMED_OUT'), findsOneWidget);
  });

  testWidgets('tapping a visit opens its record', (tester) async {
    viewModel().record(
      url: 'https://mirror.maxaix.com/fit',
      destinationId: 'mirror',
    );
    RouteSettings? pushed;

    await tester.pumpWidget(
      _app(
        container,
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

    await tester.tap(find.text('https://mirror.maxaix.com/fit'));
    await tester.pumpAndSettle();

    expect(pushed?.name, Routes.urlVisitDetail);
    final args = pushed?.arguments as UrlVisitDetailArgs?;
    expect(args?.visit.url, 'https://mirror.maxaix.com/fit');
  });

  testWidgets('a row leads with what was tapped', (tester) async {
    viewModel().record(
      url: 'https://www.dickssportinggoods.com/f/mens-golf-apparel',
      destinationId: 'mirror',
      trigger: VisitTrigger.element,
      tappedLabel: 'GET THIS STYLE',
      tappedContext: "MEN'S APPAREL",
    );

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    expect(find.text('GET THIS STYLE'), findsOneWidget);
    expect(find.text("Tapped a card under MEN'S APPAREL"), findsOneWidget);
  });

  testWidgets('clear empties the list', (tester) async {
    viewModel().record(url: 'https://a.com', destinationId: 'mirror');

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('CLEAR'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Nothing opened yet'), findsOneWidget);
  });
}

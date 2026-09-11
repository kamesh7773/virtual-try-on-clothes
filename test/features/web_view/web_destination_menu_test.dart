import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:virtual_try_on/core/constants/app_constants.dart';
import 'package:virtual_try_on/core/routes/route_arguments.dart';
import 'package:virtual_try_on/core/routes/route_generator.dart';
import 'package:virtual_try_on/core/routes/routes.dart';
import 'package:virtual_try_on/features/web_view/models/web_destination.dart';
import 'package:virtual_try_on/features/web_view/views/widgets/web_destination_menu.dart';

/// The browser screen itself hosts a platform view, which a widget test
/// cannot build — so these tests stop at the route the sheet pushes.
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
        return Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showWebDestinationSheet(context),
              child: const Text('open'),
            ),
          ),
        );
      },
    ),
  ),
);

void main() {
  testWidgets('the sheet lists every destination with its host', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('MIRROR'), findsOneWidget);
    expect(find.text('mirror.maxaix.com'), findsOneWidget);
    expect(find.text("DICK'S SPORTING GOODS"), findsOneWidget);
    expect(find.text('www.dickssportinggoods.com'), findsOneWidget);
  });

  testWidgets('picking a destination pushes it to the browser route', (
    tester,
  ) async {
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

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MIRROR'));
    await tester.pumpAndSettle();

    expect(pushed?.name, Routes.webView);
    final args = pushed?.arguments as WebViewScreenArgs?;
    expect(args?.destination, WebDestinations.mirror);
  });

  testWidgets('the browser route without a destination shows the error page', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: RouteGenerator.generateRoute,
        // Straight to the browser route: `initialRoute` would also build the
        // try-on screen underneath it, which needs a ProviderScope.
        onGenerateInitialRoutes: (_) => [
          RouteGenerator.generateRoute(
            const RouteSettings(name: Routes.webView),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('No destination given for ${Routes.webView}'),
      findsOneWidget,
    );
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:virtual_try_on/core/constants/app_constants.dart';
import 'package:virtual_try_on/core/routes/routes.dart';
import 'package:virtual_try_on/features/home/views/home_screen.dart';
import 'package:virtual_try_on/features/home/views/widgets/home_option_tile.dart';

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
        return const HomeScreen();
      },
    ),
  ),
);

void main() {
  setUp(() {
    // The history tile reads the stored record on mount.
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('offers the two modes and the record', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byType(HomeOptionTile), findsNWidgets(2));
    expect(find.text('WEB VIEW'), findsOneWidget);
    expect(find.text('HISTORY'), findsOneWidget);
  });

  testWidgets('the history tile says how much has been saved', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(
      find.text('Every page the browser opens is saved here'),
      findsOneWidget,
    );
  });

  testWidgets('the history tile opens the record', (tester) async {
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

    await tester.tap(find.text('HISTORY'));
    await tester.pumpAndSettle();

    expect(pushed?.name, Routes.urlHistory);
  });

  testWidgets('the web view option opens the destination sheet', (
    tester,
  ) async {
    await tester.pumpWidget(_app());

    await tester.tap(find.text('WEB VIEW'));
    await tester.pumpAndSettle();

    expect(find.text('BROWSE'), findsOneWidget);
    expect(find.text('MIRROR'), findsOneWidget);
    expect(find.text("DICK'S SPORTING GOODS"), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_try_on/core/constants/app_constants.dart';
import 'package:virtual_try_on/features/web_view/models/try_on_category.dart';
import 'package:virtual_try_on/features/web_view/models/web_product.dart';
import 'package:virtual_try_on/features/web_view/views/widgets/try_on_overlay.dart';

const _product = WebProduct(
  pageUrl: 'https://www.dickssportinggoods.com/p/walter-hagen-polo',
  title: "Walter Hagen Men's Performance 11 Tailgate Print Golf Polo",
  imageUrl: 'https://dks.scene7.com/is/image/dkscdn/polo',
);

Widget _app({required bool isLoading, required VoidCallback onTap}) =>
    MaterialApp(
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
            body: TryOnOverlay(
              product: _product,
              category: TryOnCategory.golf,
              isLoading: isLoading,
              onTap: onTap,
            ),
          );
        },
      ),
    );

void main() {
  testWidgets('offers the product by name', (tester) async {
    await tester.pumpWidget(_app(isLoading: false, onTap: () {}));

    expect(find.text('TRY THIS ON · GOLF'), findsOneWidget);
    expect(find.text(_product.title), findsOneWidget);
  });

  testWidgets('tapping asks for the try-on', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(isLoading: false, onTap: () => taps++));

    await tester.tap(find.text('TRY THIS ON · GOLF'));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('a request in flight cannot be asked for twice', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(isLoading: true, onTap: () => taps++));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('TRY THIS ON · GOLF'));
    await tester.pump();

    expect(taps, 0);
  });
}

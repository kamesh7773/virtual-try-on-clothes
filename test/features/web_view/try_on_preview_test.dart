import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_try_on/features/web_view/models/web_purchase_options.dart';
import 'package:virtual_try_on/features/web_view/view_models/product_try_on_state.dart';
import 'package:virtual_try_on/features/web_view/views/widgets/try_on_preview.dart';
import 'package:virtual_try_on/features/web_view/views/widgets/web_overlay_button.dart';

void main() {
  Widget host(Widget child) => ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, _) => MaterialApp(home: Scaffold(body: child)),
  );

  testWidgets('shows the try-on the service sent back', (tester) async {
    await tester.pumpWidget(
      host(
        TryOnPreview(
          imageUrl: 'https://mirror.maxaix.com/images/Golf.png',
          onClose: () {},
        ),
      ),
    );
    await tester.pump();

    final image = tester.widget<Image>(find.byType(Image));

    expect(
      (image.image as NetworkImage).url,
      'https://mirror.maxaix.com/images/Golf.png',
    );
    expect(image.fit, BoxFit.contain);
  });

  testWidgets('can be zoomed into, the garment being the point', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(TryOnPreview(imageUrl: 'https://example.com/a.png', onClose: () {})),
    );
    await tester.pump();

    expect(find.byType(InteractiveViewer), findsOneWidget);
  });

  testWidgets('the cross closes it', (tester) async {
    var closed = 0;

    await tester.pumpWidget(
      host(
        TryOnPreview(
          imageUrl: 'https://example.com/a.png',
          onClose: () => closed++,
        ),
      ),
    );
    await tester.pump();

    final cross = tester.widget<WebOverlayButton>(
      find.byType(WebOverlayButton),
    );
    expect(cross.icon, Icons.close_rounded);

    await tester.tap(find.byType(WebOverlayButton));

    expect(closed, 1);
  });

  group('checkout', () {
    testWidgets('offers no checkout without a product to buy', (tester) async {
      await tester.pumpWidget(
        host(
          TryOnPreview(imageUrl: 'https://example.com/a.png', onClose: () {}),
        ),
      );
      await tester.pump();

      expect(find.text('CHECKOUT'), findsNothing);
    });

    testWidgets('the bar asks to check out', (tester) async {
      var asked = 0;
      await tester.pumpWidget(
        host(
          TryOnPreview(
            imageUrl: 'https://example.com/a.png',
            onClose: () {},
            canCheckout: true,
            onCheckout: () => asked++,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('CHECKOUT'));

      expect(asked, 1);
    });

    testWidgets('while the page is asked, the bar says so and takes no tap', (
      tester,
    ) async {
      var asked = 0;
      await tester.pumpWidget(
        host(
          TryOnPreview(
            imageUrl: 'https://example.com/a.png',
            onClose: () {},
            canCheckout: true,
            step: CheckoutStep.adding,
            onCheckout: () => asked++,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('ADDING TO CART'), findsOneWidget);
      await tester.tap(find.text('ADDING TO CART'));
      expect(asked, 0);
    });

    testWidgets(
      'the size row offers the page\'s sizes, crossed out ones aside',
      (tester) async {
        String? picked;
        await tester.pumpWidget(
          host(
            TryOnPreview(
              imageUrl: 'https://example.com/a.png',
              onClose: () {},
              canCheckout: true,
              step: CheckoutStep.pickingSize,
              sizes: const [
                WebSizeOption(label: 'S'),
                WebSizeOption(label: 'M', available: false),
                WebSizeOption(label: 'L'),
              ],
              onCheckout: () {},
              onSizePicked: (label) => picked = label,
            ),
          ),
        );
        await tester.pump();

        expect(find.text('SELECT SIZE'), findsOneWidget);
        expect(find.text('CHECKOUT'), findsNothing);

        await tester.tap(find.text('M'));
        expect(picked, isNull);

        await tester.tap(find.text('L'));
        expect(picked, 'L');
      },
    );

    testWidgets('the colour row offers the page\'s swatches by name', (
      tester,
    ) async {
      String? picked;
      await tester.pumpWidget(
        host(
          TryOnPreview(
            imageUrl: 'https://example.com/a.png',
            onClose: () {},
            canCheckout: true,
            step: CheckoutStep.pickingColor,
            colors: const [
              WebColorOption(label: 'Football Dog Convo Red'),
              WebColorOption(label: 'Carolina Convo Blue', available: false),
            ],
            onCheckout: () {},
            onColorPicked: (label) => picked = label,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('SELECT COLOR'), findsOneWidget);
      expect(find.text('CHECKOUT'), findsNothing);

      await tester.tap(find.text('Carolina Convo Blue'));
      expect(picked, isNull);

      await tester.tap(find.text('Football Dog Convo Red'));
      expect(picked, 'Football Dog Convo Red');
    });

    testWidgets('the size row can be closed back to the picture', (
      tester,
    ) async {
      var cancelled = 0;
      await tester.pumpWidget(
        host(
          TryOnPreview(
            imageUrl: 'https://example.com/a.png',
            onClose: () {},
            canCheckout: true,
            step: CheckoutStep.pickingSize,
            sizes: const [WebSizeOption(label: 'S')],
            onCheckout: () {},
            onCancelPick: () => cancelled++,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Back to the try-on'));

      expect(cancelled, 1);
    });
  });
}

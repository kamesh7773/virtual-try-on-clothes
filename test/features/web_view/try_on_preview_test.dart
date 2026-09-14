import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
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
}

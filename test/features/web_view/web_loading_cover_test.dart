import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_try_on/core/widgets/mirror_wordmark.dart';
import 'package:virtual_try_on/features/web_view/views/widgets/web_loading_cover.dart';

void main() {
  Widget host(Widget child, {bool reduceMotion = false}) => ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, _) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(body: child),
      ),
    ),
  );

  testWidgets('the wait carries the app\'s own name', (tester) async {
    await tester.pumpWidget(host(const WebLoadingCover()));
    await tester.pump();

    expect(find.byType(MirrorWordmark), findsOneWidget);
    expect(find.text('ONE MOMENT'), findsOneWidget);
  });

  testWidgets('lets the page underneath show through, dimmed', (tester) async {
    await tester.pumpWidget(host(const WebLoadingCover()));
    await tester.pump();

    final cover = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(WebLoadingCover),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final gradient = (cover.decoration as BoxDecoration).gradient!;

    // Not opaque: a page that paints without saying so is still readable
    // under it. Not faint either: it has to read as a wait, and keep the
    // wordmark legible over a white page.
    for (final color in gradient.colors) {
      expect(color.a, lessThan(1.0));
      expect(color.a, greaterThanOrEqualTo(0.7));
    }
  });

  testWidgets('the moving segment is actually drawn', (tester) async {
    await tester.pumpWidget(host(const WebLoadingCover()));
    await tester.pump();

    // It travels inside an `Align`, which lets a child be as small as it
    // likes — a segment with no height animates just as happily as one with,
    // and shows nothing at all.
    final size = tester.getSize(
      find.descendant(
        of: find.byType(AnimatedBuilder),
        matching: find.byType(Container),
      ),
    );

    expect(size.height, greaterThan(0));
    expect(size.width, greaterThan(20));
  });

  testWidgets('keeps moving while the page is on its way', (tester) async {
    await tester.pumpWidget(host(const WebLoadingCover()));
    await tester.pump();

    final start = _segmentAlignment(tester);
    await tester.pump(const Duration(milliseconds: 400));

    expect(_segmentAlignment(tester), isNot(start));
  });

  testWidgets('holds still for a user who asked for less motion', (
    tester,
  ) async {
    await tester.pumpWidget(host(const WebLoadingCover(), reduceMotion: true));
    await tester.pumpAndSettle();

    expect(_segmentAlignment(tester).x, 0);
  });
}

/// Where the lit segment sits on its track, from -1 (hard left) to 1.
///
/// Scoped to the `AnimatedBuilder` that drives it: `Center` is an `Align`
/// too, and it sits at 0 forever — a test that found that one instead would
/// pass whether the segment moved or not.
Alignment _segmentAlignment(WidgetTester tester) {
  final align = tester.widget<Align>(
    find.descendant(
      of: find.byType(AnimatedBuilder),
      matching: find.byType(Align),
    ),
  );

  return align.alignment as Alignment;
}

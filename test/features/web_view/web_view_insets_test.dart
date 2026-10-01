import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_try_on/features/web_view/views/web_view_screen.dart';

void main() {
  group('hasButtonNavigationBar', () {
    test('a bar of three buttons is one', () {
      // Android's back / home / recents, on every release that has them.
      expect(
        hasButtonNavigationBar(const EdgeInsets.only(top: 24, bottom: 48)),
        isTrue,
      );
    });

    test('a gesture bar is not', () {
      // Android's pill, and the iPhone's home indicator.
      for (final height in [16.0, 24.0, 34.0]) {
        expect(
          hasButtonNavigationBar(EdgeInsets.only(top: 24, bottom: height)),
          isFalse,
          reason: '$height',
        );
      }
    });

    test('no bar at all is not', () {
      expect(hasButtonNavigationBar(EdgeInsets.zero), isFalse);
    });
  });
}

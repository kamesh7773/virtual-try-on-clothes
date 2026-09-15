import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_try_on/features/web_view/models/web_destination.dart';

void main() {
  group('WebDestinations.handlesOwnInsets', () {
    test('the mirror is handed the whole screen', () {
      expect(
        WebDestinations.handlesOwnInsets(WebDestinations.mirror.host),
        isTrue,
      );
    });

    test('a retailer keeps the status bar clear', () {
      expect(
        WebDestinations.handlesOwnInsets(
          WebDestinations.dicksSportingGoods.host,
        ),
        isFalse,
      );
    });

    test('a host followed off the mirror keeps the status bar clear', () {
      expect(WebDestinations.handlesOwnInsets('www.nike.com'), isFalse);
      expect(WebDestinations.handlesOwnInsets(''), isFalse);
    });
  });

  group('cart', () {
    test('a known retailer has a cart the app can open', () {
      expect(
        WebDestinations.cartUrlFor('www.dickssportinggoods.com'),
        contains('OrderItemDisplay'),
      );
    });

    test('an unknown site has none', () {
      expect(WebDestinations.cartUrlFor('shop.example.com'), isNull);
    });
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_try_on/features/web_view/models/visit_trigger.dart';
import 'package:virtual_try_on/features/web_view/models/web_bridge_message.dart';
import 'package:virtual_try_on/features/web_view/models/web_purchase_options.dart';

void main() {
  group('taps', () {
    test('reads what the page reported about a tap', () {
      final message = WebBridgeMessage.tryParse(
        jsonEncode({
          'url': 'https://www.dickssportinggoods.com/f/mens-golf-apparel',
          'trigger': 'element',
          'promote': true,
          'label': '  GET THIS STYLE  ',
          'context': "MEN'S APPAREL",
          'sourceUrl': 'https://mirror.maxaix.com/',
          'sourceTitle': 'LiveLook Mirror',
        }),
      );

      expect(message, isA<WebTapMessage>());
      final report = (message! as WebTapMessage).report;
      expect(report.promote, isTrue);
      expect(report.trigger, VisitTrigger.element);
      expect(report.label, 'GET THIS STYLE');
      expect(report.context, "MEN'S APPAREL");
    });

    test('an unknown trigger falls back rather than failing', () {
      final message = WebBridgeMessage.tryParse(
        jsonEncode({'url': 'https://example.com', 'trigger': 'nonsense'}),
      );

      final report = (message! as WebTapMessage).report;
      expect(report.trigger, VisitTrigger.direct);
      expect(report.promote, isFalse);
    });

    test('a runaway label is cut rather than carried into the history', () {
      final message = WebBridgeMessage.tryParse(
        jsonEncode({'url': 'https://example.com', 'label': 'x' * 5000}),
      );

      final report = (message! as WebTapMessage).report;
      expect(report.label!.length, 200);
      expect(report.label, endsWith('…'));
    });

    test('empty strings are dropped, not stored as blanks', () {
      final message = WebBridgeMessage.tryParse(
        jsonEncode({'url': 'https://example.com', 'label': '   '}),
      );

      expect((message! as WebTapMessage).report.label, isNull);
    });
  });

  group('products', () {
    test('reads the product the page is showing', () {
      final message = WebBridgeMessage.tryParse(
        jsonEncode({
          'type': 'product',
          'url': 'https://www.dickssportinggoods.com/p/walter-hagen-polo',
          'title': "Walter Hagen Men's Performance 11 Tailgate Print Golf Polo",
          'image': 'https://dks.scene7.com/is/image/dkscdn/polo',
          'brand': 'Walter Hagen',
          'sku': '23WHGMPRFRMNC11TLPLO',
          'price': '54.97',
          'currency': 'USD',
        }),
      );

      expect(message, isA<WebProductMessage>());
      final product = (message! as WebProductMessage).product!;
      expect(product.brand, 'Walter Hagen');
      expect(product.imageUrl, 'https://dks.scene7.com/is/image/dkscdn/polo');
      expect(product.formattedPrice, 'USD 54.97');
    });

    test('a page with no product reports that, so the overlay can go', () {
      final message = WebBridgeMessage.tryParse(
        jsonEncode({'type': 'product', 'url': 'https://example.com'}),
      );

      expect(message, isA<WebProductMessage>());
      expect((message! as WebProductMessage).product, isNull);
    });

    test('a product without a usable image is no product at all', () {
      final message = WebBridgeMessage.tryParse(
        jsonEncode({
          'type': 'product',
          'url': 'https://example.com/p/1',
          'title': 'Something',
          'image': '/relative/not-resolved.jpg',
        }),
      );

      expect((message! as WebProductMessage).product, isNull);
    });
  });

  group('paints', () {
    test('reads where the page was when it first painted', () {
      final message = WebBridgeMessage.tryParse(
        jsonEncode({
          'type': 'painted',
          'url': 'https://www.dickssportinggoods.com/f/mens-golf-apparel',
        }),
      );

      expect(message, isA<WebPaintedMessage>());
      expect(
        (message! as WebPaintedMessage).url.host,
        'www.dickssportinggoods.com',
      );
    });

    test('a paint with no page to its name is dropped', () {
      // The bridge is reachable by every script on the page; a paint the
      // app cannot place is not one it can act on.
      expect(
        WebBridgeMessage.tryParse(jsonEncode({'type': 'painted'})),
        isNull,
      );
      expect(
        WebBridgeMessage.tryParse(
          jsonEncode({'type': 'painted', 'url': 'not a url'}),
        ),
        isNull,
      );
    });
  });

  group('purchase options', () {
    test('reads the sizes and controls the page offers', () {
      final message = WebBridgeMessage.tryParse(
        jsonEncode({
          'type': 'options',
          'url': 'https://www.dickssportinggoods.com/p/polo',
          'sizes': [
            {'label': 'S', 'available': true, 'selected': false},
            {'label': 'M', 'available': false},
            {'label': 'L', 'selected': true},
          ],
          'addToCart': true,
          'cartUrl': 'https://www.dickssportinggoods.com/OrderItemDisplay?a=1',
        }),
      );

      expect(message, isA<WebOptionsMessage>());
      final options = (message! as WebOptionsMessage).options;
      expect(options.sizes.map((s) => s.label), ['S', 'M', 'L']);
      expect(options.sizes[1].available, isFalse);
      expect(options.selectedSize?.label, 'L');
      expect(options.needsSize, isFalse);
      expect(options.canAddToCart, isTrue);
      expect(options.cartUrl, contains('OrderItemDisplay'));
    });

    test('a size row with nothing picked needs a size', () {
      final options = WebPurchaseOptions.tryParse({
        'url': 'https://example.com/p',
        'sizes': [
          {'label': 'S'},
          {'label': 'M'},
        ],
        'addToCart': true,
      })!;

      expect(options.needsSize, isTrue);
      expect(options.selectedSize, isNull);
    });

    test('junk sizes and a non-web cart link are dropped', () {
      final options = WebPurchaseOptions.tryParse({
        'url': 'https://example.com/p',
        'sizes': [
          {'label': 'S'},
          {'label': 42},
          'M',
          {'label': 'a label far too long to be a size'},
        ],
        'cartUrl': 'javascript:alert(1)',
      })!;

      expect(options.sizes.map((s) => s.label), ['S']);
      expect(options.cartUrl, isNull);
      expect(options.canAddToCart, isFalse);
    });

    test('reads the colour swatches and settles the colour from the URL', () {
      final options = WebPurchaseOptions.tryParse({
        'url':
            'https://www.dickssportinggoods.com/p/polo?color=Football%20Dog%20Convo%20Red',
        'colors': [
          {
            'label': 'Carolina Convo Blue',
            'image': 'https://dks.scene7.com/is/image/blue',
          },
          {'label': 'Football Dog Convo Red', 'image': '/relative.png'},
        ],
        'addToCart': true,
      })!;

      expect(options.colors.map((c) => c.label), [
        'Carolina Convo Blue',
        'Football Dog Convo Red',
      ]);
      expect(options.colors.first.imageUrl, contains('scene7'));
      expect(options.colors.last.imageUrl, isNull);
      expect(options.colorInUrl, 'Football Dog Convo Red');
      expect(options.resolvedColor?.label, 'Football Dog Convo Red');
      expect(options.needsColor, isFalse);
    });

    test('a colour the page has marked wins over the URL', () {
      final options = WebPurchaseOptions.tryParse({
        'url': 'https://example.com/p?color=Red',
        'colors': [
          {'label': 'Red'},
          {'label': 'Blue', 'selected': true},
        ],
      })!;

      expect(options.resolvedColor?.label, 'Blue');
    });

    test('colours with nothing to settle them have to be asked for', () {
      final options = WebPurchaseOptions.tryParse({
        'url': 'https://example.com/p',
        'colors': [
          {'label': 'Red'},
          {'label': 'Blue'},
        ],
      })!;

      expect(options.needsColor, isTrue);

      final sold = WebPurchaseOptions.tryParse({
        'url': 'https://example.com/p?color=red',
        'colors': [
          {'label': 'Red', 'available': false},
          {'label': 'Blue'},
        ],
      })!;
      // The address names a colour that cannot be bought.
      expect(sold.needsColor, isTrue);
    });

    test('colour names match loosely', () {
      const red = WebColorOption(label: 'Football Dog Convo Red');
      expect(red.isCalled('football-dog-convo-red'), isTrue);
      expect(red.isCalled('FOOTBALL DOG CONVO RED'), isTrue);
      expect(red.isCalled('Blue'), isFalse);
    });

    test('options without a page are no options', () {
      expect(
        WebBridgeMessage.tryParse(jsonEncode({'type': 'options'})),
        isNull,
      );
    });
  });

  group('checkout', () {
    test('reads how the page answered', () {
      final message = WebBridgeMessage.tryParse(
        jsonEncode({
          'type': 'checkout',
          'status': 'failed',
          'reason': '  Please select a size  ',
          'cartUrl': 'https://example.com/cart',
        }),
      );

      expect(message, isA<WebCheckoutMessage>());
      final checkout = message! as WebCheckoutMessage;
      expect(checkout.status, WebCheckoutStatus.failed);
      expect(checkout.reason, 'Please select a size');
      expect(checkout.cartUrl, 'https://example.com/cart');
    });

    test('an empty reason is no reason', () {
      final message = WebBridgeMessage.tryParse(
        jsonEncode({'type': 'checkout', 'status': 'added', 'reason': ''}),
      );

      expect((message! as WebCheckoutMessage).reason, isNull);
      expect((message as WebCheckoutMessage).cartUrl, isNull);
    });

    test('an unknown status is dropped', () {
      expect(
        WebBridgeMessage.tryParse(
          jsonEncode({'type': 'checkout', 'status': 'maybe'}),
        ),
        isNull,
      );
    });
  });

  test('anything that is not a message is ignored', () {
    // The bridge is reachable by every script on the page, so junk arriving
    // on it has to be survivable.
    expect(WebBridgeMessage.tryParse('hello'), isNull);
    expect(WebBridgeMessage.tryParse('[]'), isNull);
    expect(WebBridgeMessage.tryParse('{}'), isNull);
    expect(WebBridgeMessage.tryParse(jsonEncode({'url': 42})), isNull);
  });
}

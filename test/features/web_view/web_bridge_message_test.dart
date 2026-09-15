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
    test('reads the attribute rows and controls the page offers', () {
      final message = WebBridgeMessage.tryParse(
        jsonEncode({
          'type': 'options',
          'url': 'https://www.dickssportinggoods.com/p/polo',
          'groups': [
            {
              'name': 'Size:',
              'values': [
                {'label': 'S', 'available': true, 'selected': false},
                {'label': 'M', 'available': false},
                {'label': 'L', 'selected': true},
              ],
            },
          ],
          'addToCart': true,
          'cartUrl': 'https://www.dickssportinggoods.com/OrderItemDisplay?a=1',
        }),
      );

      expect(message, isA<WebOptionsMessage>());
      final options = (message! as WebOptionsMessage).options;
      expect(options.groups.map((g) => g.name), ['Size']);
      final size = options.group('size')!;
      expect(size.values.map((s) => s.label), ['S', 'M', 'L']);
      expect(size.values[1].available, isFalse);
      expect(size.selected?.label, 'L');
      expect(options.nextToChoose(options.settledChoices), isNull);
      expect(options.canAddToCart, isTrue);
      expect(options.cartUrl, contains('OrderItemDisplay'));
    });

    test('rows with nothing picked are asked for in the page\'s order', () {
      final options = WebPurchaseOptions.tryParse({
        'url': 'https://example.com/p',
        'groups': [
          {
            'name': 'Size',
            'values': [
              {'label': 'S'},
              {'label': 'M'},
            ],
          },
          {
            'name': 'Inseam',
            'values': [
              {'label': '30'},
              {'label': '32'},
            ],
          },
        ],
        'addToCart': true,
      })!;

      expect(options.settledChoices, isEmpty);
      expect(options.nextToChoose(const {})?.name, 'Size');
      expect(options.nextToChoose(const {'Size': 'M'})?.name, 'Inseam');
      expect(options.nextToChoose(const {'size': 'M', 'INSEAM': '30'}), isNull);
    });

    test('junk values, empty rows and a non-web cart link are dropped', () {
      final options = WebPurchaseOptions.tryParse({
        'url': 'https://example.com/p',
        'groups': [
          {
            'name': 'Size',
            'values': [
              {'label': 'S'},
              {'label': 42},
              'M',
              {'label': 'x' * 81},
            ],
          },
          {'name': 'Width', 'values': []},
          {
            'name': 'Size',
            'values': [
              {'label': 'XL'},
            ],
          },
          {
            'values': [
              {'label': '10'},
            ],
          },
        ],
        'cartUrl': 'javascript:alert(1)',
      })!;

      expect(options.groups.map((g) => g.name), ['Size']);
      expect(options.groups.single.values.map((s) => s.label), ['S']);
      expect(options.cartUrl, isNull);
      expect(options.canAddToCart, isFalse);
    });

    test('reads the colour swatches and settles the colour from the URL', () {
      final options = WebPurchaseOptions.tryParse({
        'url':
            'https://www.dickssportinggoods.com/p/polo?color=Football%20Dog%20Convo%20Red',
        'groups': [
          {
            'name': 'Color',
            'values': [
              {
                'label': 'Carolina Convo Blue',
                'image': 'https://dks.scene7.com/is/image/blue',
              },
              {'label': 'Football Dog Convo Red', 'image': '/relative.png'},
            ],
          },
        ],
        'addToCart': true,
      })!;

      final color = options.groups.single;
      expect(color.isColor, isTrue);
      expect(color.isSwatch, isTrue);
      expect(color.values.first.imageUrl, contains('scene7'));
      expect(color.values.last.imageUrl, isNull);
      expect(options.colorInUrl, 'Football Dog Convo Red');
      expect(options.resolved(color)?.label, 'Football Dog Convo Red');
      expect(options.settledChoices, {'Color': 'Football Dog Convo Red'});
    });

    test('a colour the page has marked wins over the URL', () {
      final options = WebPurchaseOptions.tryParse({
        'url': 'https://example.com/p?color=Red',
        'groups': [
          {
            'name': 'Colour',
            'values': [
              {'label': 'Red'},
              {'label': 'Blue', 'selected': true},
            ],
          },
        ],
      })!;

      expect(options.resolved(options.groups.single)?.label, 'Blue');
    });

    test('colours with nothing to settle them have to be asked for', () {
      final options = WebPurchaseOptions.tryParse({
        'url': 'https://example.com/p',
        'groups': [
          {
            'name': 'Color',
            'values': [
              {'label': 'Red'},
              {'label': 'Blue'},
            ],
          },
        ],
      })!;

      expect(options.nextToChoose(options.settledChoices)?.name, 'Color');

      final sold = WebPurchaseOptions.tryParse({
        'url': 'https://example.com/p?color=red',
        'groups': [
          {
            'name': 'Color',
            'values': [
              {'label': 'Red', 'available': false},
              {'label': 'Blue'},
            ],
          },
        ],
      })!;
      // The address names a colour that cannot be bought.
      expect(sold.settledChoices, isEmpty);
    });

    test(
      'the URL settles only the colour, not a size that happens to match',
      () {
        final options = WebPurchaseOptions.tryParse({
          'url': 'https://example.com/p?color=M',
          'groups': [
            {
              'name': 'Size',
              'values': [
                {'label': 'S'},
                {'label': 'M'},
              ],
            },
          ],
        })!;

        expect(options.settledChoices, isEmpty);
      },
    );

    test('value names match loosely, but the exact spelling comes first', () {
      const red = WebOptionValue(label: 'Football Dog Convo Red');
      expect(red.isCalled('football-dog-convo-red'), isTrue);
      expect(red.isCalled('FOOTBALL DOG CONVO RED'), isTrue);
      expect(red.isCalled('Blue'), isFalse);

      const sizes = WebOptionGroup(
        name: 'Size',
        values: [
          WebOptionValue(label: 'XL'),
          WebOptionValue(label: 'L'),
        ],
      );
      expect(sizes.find('L')?.label, 'L');
      expect(sizes.find('xl')?.label, 'XL');
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

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_try_on/features/web_view/models/visit_trigger.dart';
import 'package:virtual_try_on/features/web_view/models/web_bridge_message.dart';

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

  test('anything that is not a message is ignored', () {
    // The bridge is reachable by every script on the page, so junk arriving
    // on it has to be survivable.
    expect(WebBridgeMessage.tryParse('hello'), isNull);
    expect(WebBridgeMessage.tryParse('[]'), isNull);
    expect(WebBridgeMessage.tryParse('{}'), isNull);
    expect(WebBridgeMessage.tryParse(jsonEncode({'url': 42})), isNull);
  });
}

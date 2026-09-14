import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_try_on/features/web_view/models/shop_link.dart';
import 'package:virtual_try_on/features/web_view/models/try_on_category.dart';

void main() {
  group('reading a shop link off the channel', () {
    test('takes the url and the category the site sends', () {
      final link = ShopLink.tryParse(
        '{"category":"golf",'
        '"url":"https://www.dickssportinggoods.com/f/mens-golf-apparel"}',
      );

      expect(link, isNotNull);
      expect(
        link!.url.toString(),
        'https://www.dickssportinggoods.com/f/mens-golf-apparel',
      );
      expect(link.category, TryOnCategory.golf);
    });

    test('reads every category the four cards can send', () {
      for (final category in TryOnCategory.values) {
        final link = ShopLink.tryParse(
          '{"category":"${category.wireName}","url":"https://example.com/a"}',
        );

        expect(link?.category, category, reason: category.wireName);
      }
    });

    test('still opens a link whose category is one this app does not know', () {
      final link = ShopLink.tryParse(
        '{"category":"skiing","url":"https://example.com/a"}',
      );

      expect(link?.url.toString(), 'https://example.com/a');
      expect(link?.category, isNull);
      expect(link?.label, 'Shop link');
    });

    test('names the tap after the card for the history', () {
      final link = ShopLink.tryParse(
        '{"category":"athletics","url":"https://example.com/a"}',
      );

      expect(link?.label, 'Athletics apparel');
    });
  });

  group('what the channel refuses to open', () {
    test('a message that is not JSON', () {
      expect(ShopLink.tryParse('open the shop'), isNull);
    });

    test('JSON that is not an object', () {
      expect(ShopLink.tryParse('["https://example.com"]'), isNull);
    });

    test('an object with no url', () {
      expect(ShopLink.tryParse('{"category":"golf"}'), isNull);
    });

    test('a url that is not a string', () {
      expect(ShopLink.tryParse('{"url":42}'), isNull);
    });

    test('a scheme that is not the web', () {
      expect(ShopLink.tryParse('{"url":"javascript:alert(1)"}'), isNull);
      expect(ShopLink.tryParse('{"url":"file:///etc/passwd"}'), isNull);
    });

    test('a url with no host to open', () {
      expect(ShopLink.tryParse('{"url":"https:///f/golf"}'), isNull);
      expect(ShopLink.tryParse('{"url":"/f/mens-golf-apparel"}'), isNull);
    });
  });
}

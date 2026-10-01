import 'dart:convert';

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
        '{"category":"athletics","dept":"apparel",'
        '"url":"https://example.com/a"}',
      );

      expect(link?.label, 'Athletics apparel');
    });
  });

  group('who the card was styled for, and on which shelf', () {
    test('reads the variant and the dept the site sends', () {
      final link = ShopLink.tryParse(
        '{"category":"golf","variant":"women","dept":"shoes",'
        '"url":"https://www.dickssportinggoods.com/f/womens-golf-shoes"}',
      );

      expect(link?.variant, ShopVariant.women);
      expect(link?.dept, ShopDept.shoes);
      expect(link?.label, 'Golf shoes');
      expect(link?.context, "Women's Shoes");
    });

    test('reads every variant and dept the site can send', () {
      for (final variant in ShopVariant.values) {
        for (final dept in ShopDept.values) {
          final link = ShopLink.tryParse(
            '{"category":"golf","variant":"${variant.wireName}",'
            '"dept":"${dept.wireName}","url":"https://example.com/a"}',
          );

          expect(link?.variant, variant, reason: variant.wireName);
          expect(link?.dept, dept, reason: dept.wireName);
        }
      }
    });

    test('heads a youth card the way the site does', () {
      final link = ShopLink.tryParse(
        '{"category":"sports","variant":"girls","dept":"apparel",'
        '"url":"https://example.com/a"}',
      );

      expect(link?.context, "Girls' Apparel");
    });

    test('says nothing about a shelf the site did not name', () {
      final link = ShopLink.tryParse(
        '{"category":"golf","variant":"seniors","dept":"hats",'
        '"url":"https://example.com/a"}',
      );

      expect(link?.url.toString(), 'https://example.com/a');
      expect(link?.variant, isNull);
      expect(link?.dept, isNull);
      expect(link?.label, 'Golf');
      expect(link?.context, isNull);
    });
  });

  // The site picks the link; the app's whole part is to open the one it was
  // given. A retailer reads `5495:Girls%27` as a filter and anything the
  // parser tidied — a decoded quote, a dropped empty parameter — as a
  // different search.
  group('opens the link exactly as the site wrote it', () {
    const search =
        '&storeId=15108&catalogId=12301&langId=-1&sType=SimpleSearch'
        '&resultCatEntryType=2&showResultsPage=true&fromPage=Search'
        '&searchSource=Q&pageView=&beginIndex=0&DSGsearchType=Keyword';
    const links = {
      'a category page': 'https://www.dickssportinggoods.com/f/mens-golf-shoes',
      'a category page with a filter':
          'https://www.dickssportinggoods.com/f/shop-youth-golf-apparel'
          '?filterFacets=5495:Girls%27',
      'a search with a gender filter':
          'https://www.dickssportinggoods.com/search/SearchDisplay'
          '?searchTerm=running%20shoes$search&filterFacets=5495:Women%27s',
      'a youth search':
          'https://www.dickssportinggoods.com/search/SearchDisplay'
          '?searchTerm=youth%20Running%20Clothing$search'
          '&filterFacets=5495:Boys%27',
      'a search with a page size':
          'https://www.dickssportinggoods.com/search/SearchDisplay'
          '?searchTerm=Steelers%20womens%20t%20shirts$search&pageSize=48',
      'a product page':
          'https://www.dickssportinggoods.com/p/'
          'nike-vomero-18-steelers-running-shoes-26nikarunnamryzqoqr5c/'
          '26nikarunnamryzqoqr5c?enteredSearchTerm=steeler%20shoes',
    };

    for (final MapEntry(key: name, value: url) in links.entries) {
      test(name, () {
        final link = ShopLink.tryParse(
          jsonEncode({'category': 'golf', 'url': url}),
        );

        expect(link?.url.toString(), url);
      });
    }
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

import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_try_on/features/style_me/models/style_catalog.dart';
import 'package:virtual_try_on/features/web_view/models/shop_link.dart';
import 'package:virtual_try_on/features/web_view/models/try_on_category.dart';

/// Every link the web mirror's `xe(category, variant, dept)` returned, taken
/// from its live bundle when the flow was ported. The app now owns this
/// table; these pin it to what shoppers were sent before.
const Map<String, String> _siteLinks = {
  'golf|men|apparel': 'https://www.dickssportinggoods.com/f/mens-golf-apparel',
  'athletics|men|apparel':
      'https://www.dickssportinggoods.com/f/mens-running-apparel',
  'workout|men|apparel':
      'https://www.dickssportinggoods.com/search/SearchDisplay?searchTerm=gym%20tshirt&storeId=15108&catalogId=12301&langId=-1&sType=SimpleSearch&resultCatEntryType=2&showResultsPage=true&fromPage=Search&searchSource=Q&pageView=&beginIndex=0&DSGsearchType=Keyword&pageSize=48',
  'sports|men|apparel':
      'https://www.dickssportinggoods.com/search/SearchDisplay?searchTerm=Steelers%20t%20shirts&storeId=15108&catalogId=12301&langId=-1&sType=SimpleSearch&resultCatEntryType=2&showResultsPage=true&fromPage=Search&searchSource=Q&pageView=&beginIndex=0&DSGsearchType=Keyword&pageSize=48',
  'golf|men|shoes': 'https://www.dickssportinggoods.com/f/mens-golf-shoes',
  'athletics|men|shoes':
      'https://www.dickssportinggoods.com/search/SearchDisplay?searchTerm=running%20shoes&storeId=15108&catalogId=12301&langId=-1&sType=SimpleSearch&resultCatEntryType=2&showResultsPage=true&fromPage=Search&searchSource=Q&pageView=&beginIndex=0&DSGsearchType=Keyword&filterFacets=5495:Men%27s',
  'workout|men|shoes':
      'https://www.dickssportinggoods.com/search/SearchDisplay?searchTerm=gym%20shoes&storeId=15108&catalogId=12301&langId=-1&sType=SimpleSearch&resultCatEntryType=2&showResultsPage=true&fromPage=Search&searchSource=Q&pageView=&beginIndex=0&DSGsearchType=Keyword&filterFacets=5495:Men%27s',
  'sports|men|shoes':
      'https://www.dickssportinggoods.com/p/nike-vomero-18-steelers-running-shoes-26nikarunnamryzqoqr5c/26nikarunnamryzqoqr5c?enteredSearchTerm=steeler%20shoes',
  'golf|women|apparel':
      'https://www.dickssportinggoods.com/f/womens-golf-apparel',
  'athletics|women|apparel':
      'https://www.dickssportinggoods.com/f/womens-running-clothing-apparel',
  'workout|women|apparel':
      'https://www.dickssportinggoods.com/search/SearchDisplay?searchTerm=womens%20gym%20tshirt&storeId=15108&catalogId=12301&langId=-1&sType=SimpleSearch&resultCatEntryType=2&showResultsPage=true&fromPage=Search&searchSource=Q&pageView=&beginIndex=0&DSGsearchType=Keyword&pageSize=48',
  'sports|women|apparel':
      'https://www.dickssportinggoods.com/search/SearchDisplay?searchTerm=Steelers%20womens%20t%20shirts&storeId=15108&catalogId=12301&langId=-1&sType=SimpleSearch&resultCatEntryType=2&showResultsPage=true&fromPage=Search&searchSource=Q&pageView=&beginIndex=0&DSGsearchType=Keyword&pageSize=48',
  'golf|women|shoes': 'https://www.dickssportinggoods.com/f/womens-golf-shoes',
  'athletics|women|shoes':
      'https://www.dickssportinggoods.com/search/SearchDisplay?searchTerm=running%20shoes&storeId=15108&catalogId=12301&langId=-1&sType=SimpleSearch&resultCatEntryType=2&showResultsPage=true&fromPage=Search&searchSource=Q&pageView=&beginIndex=0&DSGsearchType=Keyword&filterFacets=5495:Women%27s',
  'workout|women|shoes':
      'https://www.dickssportinggoods.com/search/SearchDisplay?searchTerm=gym%20shoes&storeId=15108&catalogId=12301&langId=-1&sType=SimpleSearch&resultCatEntryType=2&showResultsPage=true&fromPage=Search&searchSource=Q&pageView=&beginIndex=0&DSGsearchType=Keyword&filterFacets=5495:Women%27s',
  'sports|women|shoes':
      'https://www.dickssportinggoods.com/p/nike-vomero-18-steelers-running-shoes-26nikarunnamryzqoqr5c/26nikarunnamryzqoqr5c?enteredSearchTerm=steeler%20shoes',
  'golf|boys|apparel':
      'https://www.dickssportinggoods.com/f/shop-youth-golf-apparel',
  'athletics|boys|apparel':
      'https://www.dickssportinggoods.com/search/SearchDisplay?searchTerm=youth%20Running%20Clothing&storeId=15108&catalogId=12301&langId=-1&sType=SimpleSearch&resultCatEntryType=2&showResultsPage=true&fromPage=Search&searchSource=Q&pageView=&beginIndex=0&DSGsearchType=Keyword&filterFacets=5495:Boys%27',
  'workout|boys|apparel':
      'https://www.dickssportinggoods.com/search/SearchDisplay?searchTerm=youth%20gym%20clothes&storeId=15108&catalogId=12301&langId=-1&sType=SimpleSearch&resultCatEntryType=2&showResultsPage=true&fromPage=Search&searchSource=Q&pageView=&beginIndex=0&DSGsearchType=Keyword&filterFacets=5495:Boys%27',
  'sports|boys|apparel':
      'https://www.dickssportinggoods.com/search/SearchDisplay?searchTerm=steeler%20youth&storeId=15108&catalogId=12301&langId=-1&sType=SimpleSearch&resultCatEntryType=2&showResultsPage=true&fromPage=Search&searchSource=Q&pageView=&beginIndex=0&DSGsearchType=Keyword&filterFacets=5495:Boys%27',
  'golf|boys|shoes':
      'https://www.dickssportinggoods.com/f/shop-youth-golf-apparel',
  'athletics|boys|shoes':
      'https://www.dickssportinggoods.com/search/SearchDisplay?searchTerm=youth%20Running%20Clothing&storeId=15108&catalogId=12301&langId=-1&sType=SimpleSearch&resultCatEntryType=2&showResultsPage=true&fromPage=Search&searchSource=Q&pageView=&beginIndex=0&DSGsearchType=Keyword&filterFacets=5495:Boys%27',
  'workout|boys|shoes':
      'https://www.dickssportinggoods.com/search/SearchDisplay?searchTerm=youth%20gym%20clothes&storeId=15108&catalogId=12301&langId=-1&sType=SimpleSearch&resultCatEntryType=2&showResultsPage=true&fromPage=Search&searchSource=Q&pageView=&beginIndex=0&DSGsearchType=Keyword&filterFacets=5495:Boys%27',
  'sports|boys|shoes':
      'https://www.dickssportinggoods.com/search/SearchDisplay?searchTerm=steeler%20youth&storeId=15108&catalogId=12301&langId=-1&sType=SimpleSearch&resultCatEntryType=2&showResultsPage=true&fromPage=Search&searchSource=Q&pageView=&beginIndex=0&DSGsearchType=Keyword&filterFacets=5495:Boys%27',
  'golf|girls|apparel':
      'https://www.dickssportinggoods.com/f/shop-youth-golf-apparel?filterFacets=5495:Girls%27',
  'athletics|girls|apparel':
      'https://www.dickssportinggoods.com/search/SearchDisplay?searchTerm=youth%20Running%20Clothing&storeId=15108&catalogId=12301&langId=-1&sType=SimpleSearch&resultCatEntryType=2&showResultsPage=true&fromPage=Search&searchSource=Q&pageView=&beginIndex=0&DSGsearchType=Keyword&filterFacets=5495:Girls%27',
  'workout|girls|apparel':
      'https://www.dickssportinggoods.com/search/SearchDisplay?searchTerm=youth%20gym%20clothes&storeId=15108&catalogId=12301&langId=-1&sType=SimpleSearch&resultCatEntryType=2&showResultsPage=true&fromPage=Search&searchSource=Q&pageView=&beginIndex=0&DSGsearchType=Keyword&filterFacets=5495:Girls%27',
  'sports|girls|apparel':
      'https://www.dickssportinggoods.com/search/SearchDisplay?searchTerm=steeler%20youth&storeId=15108&catalogId=12301&langId=-1&sType=SimpleSearch&resultCatEntryType=2&showResultsPage=true&fromPage=Search&searchSource=Q&pageView=&beginIndex=0&DSGsearchType=Keyword&filterFacets=5495:Girls%27',
  'golf|girls|shoes':
      'https://www.dickssportinggoods.com/f/shop-youth-golf-apparel?filterFacets=5495:Girls%27',
  'athletics|girls|shoes':
      'https://www.dickssportinggoods.com/search/SearchDisplay?searchTerm=youth%20Running%20Clothing&storeId=15108&catalogId=12301&langId=-1&sType=SimpleSearch&resultCatEntryType=2&showResultsPage=true&fromPage=Search&searchSource=Q&pageView=&beginIndex=0&DSGsearchType=Keyword&filterFacets=5495:Girls%27',
  'workout|girls|shoes':
      'https://www.dickssportinggoods.com/search/SearchDisplay?searchTerm=youth%20gym%20clothes&storeId=15108&catalogId=12301&langId=-1&sType=SimpleSearch&resultCatEntryType=2&showResultsPage=true&fromPage=Search&searchSource=Q&pageView=&beginIndex=0&DSGsearchType=Keyword&filterFacets=5495:Girls%27',
  'sports|girls|shoes':
      'https://www.dickssportinggoods.com/search/SearchDisplay?searchTerm=steeler%20youth&storeId=15108&catalogId=12301&langId=-1&sType=SimpleSearch&resultCatEntryType=2&showResultsPage=true&fromPage=Search&searchSource=Q&pageView=&beginIndex=0&DSGsearchType=Keyword&filterFacets=5495:Girls%27',
};

void main() {
  group('StyleCatalog.shopUrl', () {
    for (final entry in _siteLinks.entries) {
      test('matches the site for ${entry.key}', () {
        final [category, variant, dept] = entry.key.split('|');

        final url = StyleCatalog.shopUrl(
          TryOnCategory.fromWireName(category)!,
          ShopVariant.fromWireName(variant)!,
          ShopDept.fromWireName(dept)!,
        );

        expect(url.toString(), entry.value);
      });
    }
  });

  group('StyleCatalog.apparelFor', () {
    test("hides the other adult's row", () {
      final labels = StyleCatalog.apparelFor(
        ShopVariant.men,
      ).map((t) => t.label);

      expect(labels, contains("MEN'S APPAREL"));
      expect(labels, isNot(contains("WOMEN'S APPAREL")));
      expect(labels, contains('YOUTH APPAREL'));
      expect(labels, hasLength(5));
    });

    test('shows the women\'s row to a women\'s shopper', () {
      final labels = StyleCatalog.apparelFor(
        ShopVariant.women,
      ).map((t) => t.label);

      expect(labels, contains("WOMEN'S APPAREL"));
      expect(labels, isNot(contains("MEN'S APPAREL")));
    });
  });

  group('the apparel rows', () {
    test('only the shelves Dick\'s links were given for lead there', () {
      final shopping = [
        for (final tile in StyleCatalog.apparel)
          if (tile.shops) tile.label,
      ];

      expect(shopping, [
        "MEN'S APPAREL",
        "WOMEN'S APPAREL",
        'YOUTH APPAREL',
        'SHOES',
      ]);
    });

    test('each row is styled for the shopper, the youth row for a child', () {
      ShopVariant variant(String label, ShopVariant shopper) => StyleCatalog
          .apparel
          .firstWhere((t) => t.label == label)
          .variantFor(shopper);

      expect(variant('YOUTH APPAREL', ShopVariant.men), ShopVariant.boys);
      expect(variant('YOUTH APPAREL', ShopVariant.women), ShopVariant.girls);
      for (final adult in StyleCatalog.adultVariants) {
        expect(variant('SHOES', adult), adult);
        expect(variant('ACCESSORIES', adult), adult);
        expect(variant('FAN SHOP', adult), adult);
      }
      expect(variant("MEN'S APPAREL", ShopVariant.men), ShopVariant.men);
      expect(variant("WOMEN'S APPAREL", ShopVariant.women), ShopVariant.women);
    });
  });
}

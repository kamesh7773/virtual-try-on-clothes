import 'package:flutter/material.dart';

import '../../web_view/models/shop_link.dart';
import '../../web_view/models/try_on_category.dart';

/// Everything the Style Me screens show that is not the shopper's own photo:
/// the tiles, the four looks, and where each look leads on Dick's.
///
/// Ported from the web mirror (`men-apparel-*.js`), which used to own this
/// flow. Only the retailer itself still opens in a browser, so the table of
/// which card leads where now lives here.
class StyleCatalog {
  StyleCatalog._();

  static const String _dir = 'assets/style_me';

  static const String logo = '$_dir/dicks_logo.svg';
  static const String introVideo = '$_dir/intro_video.mp4';
  static const String introPoster = '$_dir/intro_poster.webp';
  static const String stageBackdrop = '$_dir/stage_backdrop.webp';

  /// The three promises over the capture frame.
  static const List<StyleFeature> features = [
    StyleFeature('Instant\nStyling', '$_dir/feature_styling.svg'),
    StyleFeature('Outfits\nFor You', '$_dir/feature_outfits.svg'),
    StyleFeature('Available\nAt This Store', '$_dir/feature_store.svg'),
  ];

  /// The first choice after the photo. Only APPAREL leads anywhere yet; the
  /// rest open the previews under their own name, with nothing on Dick's
  /// behind them.
  static const List<ExploreTile> explore = [
    ExploreTile(
      label: 'APPAREL',
      sub: 'WEAR YOUR PASSION',
      image: '$_dir/explore_apparel.webp',
      opensApparel: true,
    ),
    ExploreTile(
      label: 'FOOTWEAR',
      sub: 'STEP FURTHER',
      image: '$_dir/explore_footwear.webp',
    ),
    ExploreTile(
      label: 'OUTDOORS',
      sub: 'EXPLORE MORE',
      image: '$_dir/explore_outdoors.webp',
    ),
    ExploreTile(
      label: 'EQUIPMENT',
      sub: 'BUILT FOR MORE',
      image: '$_dir/explore_equipment.webp',
    ),
    ExploreTile(
      label: 'FAN SHOP',
      sub: 'REP YOUR TEAM',
      image: '$_dir/explore_fan_shop.webp',
    ),
  ];

  /// The apparel shelves. Every row styles the looks for whoever was picked
  /// over the camera, the youth row for a child of theirs. Only the rows
  /// Dick's has a shelf for lead there: accessories and the fan shop show
  /// the looks and stop.
  static const List<ApparelTile> apparel = [
    ApparelTile(
      label: "MEN'S APPAREL",
      image: '$_dir/apparel_mens.webp',
      adult: ShopVariant.men,
    ),
    ApparelTile(
      label: "WOMEN'S APPAREL",
      image: '$_dir/apparel_women.webp',
      adult: ShopVariant.women,
    ),
    ApparelTile(
      label: 'YOUTH APPAREL',
      image: '$_dir/apparel_youth.webp',
      youth: true,
    ),
    ApparelTile(
      label: 'SHOES',
      image: '$_dir/apparel_shoes.webp',
      dept: ShopDept.shoes,
    ),
    ApparelTile(
      label: 'ACCESSORIES',
      image: '$_dir/apparel_accessories.webp',
      shops: false,
    ),
    ApparelTile(
      label: 'FAN SHOP',
      image: '$_dir/apparel_fanshop.webp',
      shops: false,
    ),
  ];

  /// The apparel rows for a shopper who picked [adult] over the camera: the
  /// other adult's row is hidden, as a men's shopper has no use for it.
  static List<ApparelTile> apparelFor(ShopVariant adult) => apparel
      .where((tile) => tile.adult == null || tile.adult == adult)
      .toList();

  /// The two choices on the MEN'S / WOMEN'S switch.
  static const List<ShopVariant> adultVariants = [
    ShopVariant.men,
    ShopVariant.women,
  ];

  /// The four looks every photo is styled into, in the order they are shown.
  static const List<StyleLook> looks = [
    StyleLook(
      category: TryOnCategory.golf,
      label: 'Golf',
      tagline: 'Course-ready',
      image: '$_dir/look_golf.webp',
      accent: Color(0xFF6EE7B7),
    ),
    StyleLook(
      category: TryOnCategory.athletics,
      label: 'Athletics',
      tagline: 'Built to perform',
      image: '$_dir/look_athletics.webp',
      accent: Color(0xFFFCD34D),
    ),
    StyleLook(
      category: TryOnCategory.workout,
      label: 'Workout',
      tagline: 'Train harder',
      image: '$_dir/look_workout.webp',
      accent: Color(0xFF7DD3FC),
    ),
    StyleLook(
      category: TryOnCategory.sports,
      label: 'Sports',
      tagline: 'Game day',
      image: '$_dir/look_sports.webp',
      accent: Color(0xFFF0ABFC),
    ),
  ];

  /// Where a look leads on Dick's, for this shopper and shelf — the table
  /// the web mirror used, kept for a look the service did not finish. A
  /// look it did finish comes with its own `shop_url`, which wins.
  ///
  /// Only asked for a shelf that shops (see [ApparelTile.shops]). Shoes have
  /// links of their own for adults only, which is all the shoe row is ever
  /// styled for; any gap in a table falls back to the apparel link and then
  /// the men's.
  static Uri shopUrl(
    TryOnCategory category,
    ShopVariant variant,
    ShopDept dept,
  ) {
    final shoes = dept == ShopDept.shoes ? _shoes[variant] : null;
    final url =
        shoes?[category] ??
        _apparel[variant]?[category] ??
        _apparel[ShopVariant.men]![category]!;
    return Uri.parse(url);
  }

  static const String _site = 'https://www.dickssportinggoods.com';

  static const String _search =
      '&storeId=15108&catalogId=12301&langId=-1&sType=SimpleSearch'
      '&resultCatEntryType=2&showResultsPage=true&fromPage=Search'
      '&searchSource=Q&pageView=&beginIndex=0&DSGsearchType=Keyword';

  static String _searchFor(String term, {String? facet, bool paged = false}) =>
      '$_site/search/SearchDisplay?searchTerm=$term$_search'
      '${paged ? '&pageSize=48' : ''}'
      '${facet == null ? '' : '&filterFacets=5495:$facet'}';

  static const String _steelersShoes =
      '$_site/p/nike-vomero-18-steelers-running-shoes-26nikarunnamryzqoqr5c/'
      '26nikarunnamryzqoqr5c?enteredSearchTerm=steeler%20shoes';

  static final Map<ShopVariant, Map<TryOnCategory, String>> _apparel = {
    ShopVariant.men: {
      TryOnCategory.golf: '$_site/f/mens-golf-apparel',
      TryOnCategory.athletics: '$_site/f/mens-running-apparel',
      TryOnCategory.workout: _searchFor('gym%20tshirt', paged: true),
      TryOnCategory.sports: _searchFor('Steelers%20t%20shirts', paged: true),
    },
    ShopVariant.women: {
      TryOnCategory.golf: '$_site/f/womens-golf-apparel',
      TryOnCategory.athletics: '$_site/f/womens-running-clothing-apparel',
      TryOnCategory.workout: _searchFor('womens%20gym%20tshirt', paged: true),
      TryOnCategory.sports: _searchFor(
        'Steelers%20womens%20t%20shirts',
        paged: true,
      ),
    },
    ShopVariant.boys: {
      TryOnCategory.golf: '$_site/f/shop-youth-golf-apparel',
      TryOnCategory.athletics: _searchFor(
        'youth%20Running%20Clothing',
        facet: 'Boys%27',
      ),
      TryOnCategory.workout: _searchFor(
        'youth%20gym%20clothes',
        facet: 'Boys%27',
      ),
      TryOnCategory.sports: _searchFor('steeler%20youth', facet: 'Boys%27'),
    },
    ShopVariant.girls: {
      TryOnCategory.golf:
          '$_site/f/shop-youth-golf-apparel?filterFacets=5495:Girls%27',
      TryOnCategory.athletics: _searchFor(
        'youth%20Running%20Clothing',
        facet: 'Girls%27',
      ),
      TryOnCategory.workout: _searchFor(
        'youth%20gym%20clothes',
        facet: 'Girls%27',
      ),
      TryOnCategory.sports: _searchFor('steeler%20youth', facet: 'Girls%27'),
    },
  };

  static final Map<ShopVariant, Map<TryOnCategory, String>> _shoes = {
    ShopVariant.men: {
      TryOnCategory.golf: '$_site/f/mens-golf-shoes',
      TryOnCategory.athletics: _searchFor('running%20shoes', facet: 'Men%27s'),
      TryOnCategory.workout: _searchFor('gym%20shoes', facet: 'Men%27s'),
      TryOnCategory.sports: _steelersShoes,
    },
    ShopVariant.women: {
      TryOnCategory.golf: '$_site/f/womens-golf-shoes',
      TryOnCategory.athletics: _searchFor(
        'running%20shoes',
        facet: 'Women%27s',
      ),
      TryOnCategory.workout: _searchFor('gym%20shoes', facet: 'Women%27s'),
      TryOnCategory.sports: _steelersShoes,
    },
  };
}

@immutable
class StyleFeature {
  final String label;
  final String icon;

  const StyleFeature(this.label, this.icon);
}

@immutable
class ExploreTile {
  final String label;
  final String sub;
  final String image;

  /// Whether the tile opens the apparel shelves rather than the previews.
  final bool opensApparel;

  const ExploreTile({
    required this.label,
    required this.sub,
    required this.image,
    this.opensApparel = false,
  });
}

@immutable
class ApparelTile {
  final String label;
  final String image;

  /// The one shopper this row is shown to. Null shows it to both.
  final ShopVariant? adult;

  /// Whether the looks are for the shopper's child rather than the shopper.
  final bool youth;

  final ShopDept dept;

  /// Whether a look on this shelf opens Dick's. False for a shelf Dick's
  /// links were never given for: the looks are still made and shown.
  final bool shops;

  const ApparelTile({
    required this.label,
    required this.image,
    this.adult,
    this.youth = false,
    this.dept = ShopDept.apparel,
    this.shops = true,
  });

  /// Who the looks are styled for, and whose links they open, when
  /// [shopper] taps this row: a man's youth are boys and a woman's girls,
  /// and every other row is the shopper's own.
  ShopVariant variantFor(ShopVariant shopper) {
    if (!youth) return adult ?? shopper;
    return shopper == ShopVariant.women ? ShopVariant.girls : ShopVariant.boys;
  }
}

@immutable
class StyleLook {
  final TryOnCategory category;
  final String label;
  final String tagline;

  /// Shown until the shopper's own look arrives, and in its place if it
  /// never does.
  final String image;

  final Color accent;

  const StyleLook({
    required this.category,
    required this.label,
    required this.tagline,
    required this.image,
    required this.accent,
  });
}

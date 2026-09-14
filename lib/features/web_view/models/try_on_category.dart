/// The only categories the try-on service accepts.
enum TryOnCategory {
  golf,
  athletics,
  workout,

  /// Also the fallback: a product that matches nothing is tried on as
  /// sportswear rather than refused.
  sports;

  /// What goes in the request's `category` field.
  String get wireName => name;

  /// Reads back a [wireName], from the try-on service or from the mirror's
  /// shop links. Null rather than a guess: a name this app does not know is
  /// a contract that has changed, not sportswear.
  static TryOnCategory? fromWireName(String? wireName) {
    for (final category in values) {
      if (category.wireName == wireName) return category;
    }
    return null;
  }
}

/// Words that put a product in a category, checked in this order.
///
/// Order is the whole design: a "golf training polo" is golf first, and a
/// "football training jersey" is a team's kit before it is gym wear. Anything
/// that matches nothing falls through to [TryOnCategory.sports].
const Map<TryOnCategory, List<String>> _categoryWords = {
  TryOnCategory.golf: [
    'golf',
    'golfing',
    'putter',
    'putting',
    'caddie',
    'caddy',
    'fairway',
    'birdie',
    'tour',
  ],
  TryOnCategory.sports: [
    'jersey',
    'fan',
    'nfl',
    'nba',
    'mlb',
    'nhl',
    'football',
    'basketball',
    'baseball',
    'hockey',
    'soccer',
    'lacrosse',
    'softball',
    'team',
    'gameday',
  ],
  TryOnCategory.workout: [
    'workout',
    'gym',
    'training',
    'train',
    'fitness',
    'lifting',
    'weightlifting',
    'yoga',
    'pilates',
    'crossfit',
    'compression',
    'exercise',
  ],
  TryOnCategory.athletics: [
    'athletics',
    'athletic',
    'running',
    'runner',
    'run',
    'track',
    'marathon',
    'sprint',
    'jogging',
    'tennis',
    'performance',
  ],
};

/// Works out which category a product belongs to.
///
/// The title is the first source; the page's own URL is the second, because a
/// retailer's path — `/f/mens-golf-apparel` — says plainly what a product
/// name sometimes only implies.
TryOnCategory resolveTryOnCategory({required String title, String? url}) {
  // "Walter Hagen … Golf Polo | Dick's Sporting Goods" — everything after the
  // bar is the shop's name, and "Sporting Goods" would match every product
  // there is.
  final productName = title.split('|').first;

  final fromTitle = _match(_normalize(productName));
  if (fromTitle != null) return fromTitle;

  if (url != null) {
    final fromUrl = _match(_normalize(Uri.tryParse(url)?.path ?? ''));
    if (fromUrl != null) return fromUrl;
  }

  return TryOnCategory.sports;
}

TryOnCategory? _match(String haystack) {
  for (final entry in _categoryWords.entries) {
    for (final word in entry.value) {
      if (haystack.contains(' $word ')) return entry.key;
    }
  }
  return null;
}

/// Lower-cased, stripped to words, and padded — so a search for ` run ` finds
/// the word and not the middle of "running" or "trunk".
String _normalize(String text) {
  final letters = text.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), ' ');
  return ' ${letters.trim()} ';
}

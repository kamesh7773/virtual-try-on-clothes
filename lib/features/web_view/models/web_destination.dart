import 'package:flutter/foundation.dart';

/// A site the app opens in its own browser instead of handing off to Safari
/// or Chrome, so a shopper never leaves the try-on to look at a garment.
@immutable
class WebDestination {
  /// Stable id, used for keys and analytics rather than the URL.
  final String id;

  /// What the app bar and the launcher pill call this site.
  final String title;

  final String url;

  /// Whether links this site opens in an embedded frame should be promoted to
  /// full pages. See [decideWebNavigation] for why a site would need it.
  ///
  /// Off by default: on an ordinary site the frames are the site's own parts,
  /// and promoting one would throw the user out of the page they are on.
  final bool promotesFramedLinks;

  const WebDestination({
    required this.id,
    required this.title,
    required this.url,
    this.promotesFramedLinks = false,
  });

  /// The bare host, shown under the title so the user can see where they are
  /// even after the site navigates somewhere else.
  String get host => Uri.parse(url).host;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is WebDestination && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

/// The sites the app ships with.
class WebDestinations {
  WebDestinations._();

  /// The web mirror — the same try-on experience, served as a page.
  ///
  /// Its style cards link out to retailers through an in-page browser of its
  /// own, which is redundant inside a browser and blank in practice, so those
  /// links are promoted to full pages.
  static const WebDestination mirror = WebDestination(
    id: 'mirror',
    title: 'Mirror',
    url: 'https://mirror.maxaix.com/',
    promotesFramedLinks: true,
  );

  static const WebDestination dicksSportingGoods = WebDestination(
    id: 'dicks_sporting_goods',
    title: "Dick's Sporting Goods",
    url: 'https://www.dickssportinggoods.com/',
  );

  static const List<WebDestination> all = [mirror, dicksSportingGoods];
}

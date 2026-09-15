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

  /// Whether this site lays itself out around the status bar and the home
  /// indicator, so the browser can hand it the whole screen.
  ///
  /// Off by default, and deliberately: a retailer's page is written for a
  /// browser with chrome above it, so its header lands under the clock when
  /// given the full screen. Only a site written for this app knows the
  /// notch is there.
  final bool handlesOwnInsets;

  /// Where this site keeps its cart, for a checkout the app finishes on the
  /// site's behalf when the page itself shows no cart link to follow.
  final String? cartUrl;

  const WebDestination({
    required this.id,
    required this.title,
    required this.url,
    this.promotesFramedLinks = false,
    this.handlesOwnInsets = false,
    this.cartUrl,
  });

  /// The bare host, shown under the title so the user can see where they are
  /// even after the site navigates somewhere else.
  String get host => Uri.parse(url).host;

  /// Whether the browser is still on this destination's own pages.
  ///
  /// What separates the site the app opened from a retailer it followed a
  /// link into — which is the line the floating back control appears on, and
  /// the one frame promotion stops at.
  bool isOwnSite(String currentHost) => currentHost == host;

  /// Whether framed links should be promoted while the browser is on [host].
  ///
  /// Scoped to this site and no further. A destination is marked because of
  /// how *it* opens outside links; once the browser has followed one, it is
  /// on someone else's site, whose frames are its own — a size guide, a
  /// payment widget, a review panel. Promoting one of those throws the user
  /// off the page they are reading and onto a widget rendered on its own,
  /// which reads as the screen going blank.
  bool promotesFramedLinksOn(String currentHost) =>
      promotesFramedLinks && isOwnSite(currentHost);

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
    handlesOwnInsets: true,
  );

  static const WebDestination dicksSportingGoods = WebDestination(
    id: 'dicks_sporting_goods',
    title: "Dick's Sporting Goods",
    url: 'https://www.dickssportinggoods.com/',
    // The cart page the site's own header link opens, minus the per-order
    // parameters it adds — the store answers the bare one the same way.
    cartUrl:
        'https://www.dickssportinggoods.com/OrderItemDisplay'
        '?storeId=15108&catalogId=12301&langId=-1',
  );

  static const List<WebDestination> all = [mirror, dicksSportingGoods];

  /// Whether the page currently on [host] can be handed the whole screen.
  ///
  /// Asked of the host the browser is on rather than the destination it was
  /// opened with, because those part company the moment a link is followed:
  /// a shopper who taps through from the mirror to a retailer is on someone
  /// else's layout, and it needs the status bar kept clear again.
  static bool handlesOwnInsets(String host) =>
      all.any((d) => d.handlesOwnInsets && d.isOwnSite(host));

  /// The cart of whichever known site the browser is on, if any.
  static String? cartUrlFor(String host) {
    for (final destination in all) {
      if (destination.isOwnSite(host)) return destination.cartUrl;
    }
    return null;
  }
}

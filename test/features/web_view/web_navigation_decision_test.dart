import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_try_on/features/web_view/models/web_destination.dart';
import 'package:virtual_try_on/features/web_view/models/web_navigation_decision.dart';

void main() {
  WebNavigationAction decide(
    String url, {
    bool isMainFrame = true,
    String currentHost = 'mirror.maxaix.com',
    bool promotesFramedLinks = true,
  }) => decideWebNavigation(
    url: url,
    isMainFrame: isMainFrame,
    currentHost: currentHost,
    promotesFramedLinks: promotesFramedLinks,
  );

  test('schemes that belong to other apps are refused', () {
    expect(decide('tel:+15551234'), WebNavigationAction.block);
    expect(decide('mailto:hi@example.com'), WebNavigationAction.block);
    expect(
      decide('intent://scan/#Intent;scheme=zxing;end'),
      WebNavigationAction.block,
    );
  });

  test('the page navigating itself is always allowed', () {
    expect(
      decide('https://www.dickssportinggoods.com/f/mens-golf-apparel'),
      WebNavigationAction.allow,
    );
  });

  test('a framed link to another site becomes a full page', () {
    expect(
      decide(
        'https://www.dickssportinggoods.com/f/mens-golf-apparel',
        isMainFrame: false,
      ),
      WebNavigationAction.openTopLevel,
    );
  });

  test("a frame loading its own site's content is left alone", () {
    expect(
      decide('https://mirror.maxaix.com/embed/preview', isMainFrame: false),
      WebNavigationAction.allow,
    );
  });

  test('sites not marked for it keep their frames', () {
    // Dick's own third-party frames — ads, chat, payment — must not throw the
    // shopper out of the page they are reading.
    expect(
      decide(
        'https://ads.example.com/banner',
        isMainFrame: false,
        currentHost: 'www.dickssportinggoods.com',
        promotesFramedLinks: false,
      ),
      WebNavigationAction.allow,
    );
  });

  test('only the mirror promotes its framed links', () {
    expect(WebDestinations.mirror.promotesFramedLinks, isTrue);
    expect(WebDestinations.dicksSportingGoods.promotesFramedLinks, isFalse);
  });

  group('where promotion applies', () {
    test('on the destination\'s own site', () {
      expect(
        WebDestinations.mirror.promotesFramedLinksOn('mirror.maxaix.com'),
        isTrue,
      );
    });

    test('nowhere else — a retailer\'s frames are its own', () {
      // Having followed a link out of the mirror, the browser is on a site
      // whose frames are a size guide, a payment widget, a review panel.
      // Promoting one leaves the widget rendered on its own, which reads as
      // the screen going blank.
      expect(
        WebDestinations.mirror.promotesFramedLinksOn(
          'www.dickssportinggoods.com',
        ),
        isFalse,
      );
      expect(WebDestinations.mirror.promotesFramedLinksOn(''), isFalse);
    });

    test('and never for a destination that is not marked', () {
      expect(
        WebDestinations.dicksSportingGoods.promotesFramedLinksOn(
          'www.dickssportinggoods.com',
        ),
        isFalse,
      );
    });
  });
}

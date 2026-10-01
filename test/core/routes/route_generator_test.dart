import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_try_on/core/routes/route_arguments.dart';
import 'package:virtual_try_on/core/routes/route_generator.dart';
import 'package:virtual_try_on/core/routes/routes.dart';
import 'package:virtual_try_on/features/web_view/models/web_destination.dart';

void main() {
  group('the route the app starts on', () {
    test('is the Style Me intro, not the browser', () {
      expect(RouteGenerator.initialRoute.name, Routes.styleIntro);
    });
  });

  group('every Style Me screen has a route', () {
    for (final name in [
      Routes.styleIntro,
      Routes.styleGetReady,
      Routes.styleExplore,
      Routes.styleApparel,
      Routes.stylePreviews,
    ]) {
      test(name, () {
        final route = RouteGenerator.generateRoute(RouteSettings(name: name));

        expect(route.settings.name, name);
      });
    }
  });

  test('the browser can be opened on a page of its destination', () {
    const args = WebViewScreenArgs(
      destination: WebDestinations.dicksSportingGoods,
      initialUrl: 'https://www.dickssportinggoods.com/f/mens-golf-apparel',
    );

    final route = RouteGenerator.generateRoute(
      const RouteSettings(name: Routes.webView, arguments: args),
    );

    expect(route.settings.arguments, args);
  });
}

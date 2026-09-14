import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_try_on/core/routes/route_arguments.dart';
import 'package:virtual_try_on/core/routes/route_generator.dart';
import 'package:virtual_try_on/core/routes/routes.dart';
import 'package:virtual_try_on/features/web_view/models/web_destination.dart';

void main() {
  group('the route the app starts on', () {
    test('is the browser, not the menu', () {
      expect(RouteGenerator.initialRoute.name, Routes.webView);
    });

    test('carries the mirror as its destination', () {
      final args = RouteGenerator.initialRoute.arguments as WebViewScreenArgs;

      expect(args.destination, WebDestinations.mirror);
    });
  });
}

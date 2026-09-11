import 'package:flutter/material.dart';

import '../../features/home/views/home_screen.dart';
import '../../features/try_on/views/try_on_screen.dart';
import '../../features/web_view/views/url_history_screen.dart';
import '../../features/web_view/views/url_visit_detail_screen.dart';
import '../../features/web_view/views/web_view_screen.dart';
import 'route_arguments.dart';
import 'routes.dart';

class RouteGenerator {
  RouteGenerator._();

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case Routes.home:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const HomeScreen(),
        );

      case Routes.tryOn:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const TryOnScreen(),
        );

      case Routes.webView:
        final args = settings.arguments as WebViewScreenArgs?;
        // Without a destination there is no URL to load, and guessing at one
        // would open the wrong site.
        if (args == null) {
          return _errorRoute('No destination given for ${settings.name}');
        }
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => WebViewScreen(destination: args.destination),
        );

      case Routes.urlHistory:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const UrlHistoryScreen(),
        );

      case Routes.urlVisitDetail:
        final args = settings.arguments as UrlVisitDetailArgs?;
        if (args == null) {
          return _errorRoute('No visit given for ${settings.name}');
        }
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => UrlVisitDetailScreen(visit: args.visit),
        );

      default:
        return _errorRoute('Route not found: ${settings.name}');
    }
  }

  static Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text(message)),
      ),
    );
  }
}

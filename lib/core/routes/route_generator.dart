import 'package:flutter/material.dart';

import '../../features/home/views/home_screen.dart';
import '../../features/style_me/views/apparel_screen.dart';
import '../../features/style_me/views/explore_screen.dart';
import '../../features/style_me/views/get_ready_screen.dart';
import '../../features/style_me/views/look_previews_screen.dart';
import '../../features/style_me/views/style_intro_screen.dart';
import '../../features/web_view/views/url_history_screen.dart';
import '../../features/web_view/views/url_visit_detail_screen.dart';
import '../../features/web_view/views/web_view_screen.dart';
import 'route_arguments.dart';
import 'routes.dart';

class RouteGenerator {
  RouteGenerator._();

  /// What the app opens on: the Style Me intro.
  ///
  /// The kiosk flow runs natively; only the retailer it leads to opens in
  /// the browser.
  static const RouteSettings initialRoute = RouteSettings(
    name: Routes.styleIntro,
  );

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case Routes.home:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const HomeScreen(),
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
          builder: (_) => WebViewScreen(
            destination: args.destination,
            initialUrl: args.initialUrl,
          ),
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

      case Routes.styleIntro:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const StyleIntroScreen(),
        );

      case Routes.styleGetReady:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const GetReadyScreen(),
        );

      case Routes.styleExplore:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const ExploreScreen(),
        );

      case Routes.styleApparel:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const ApparelScreen(),
        );

      case Routes.stylePreviews:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const LookPreviewsScreen(),
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

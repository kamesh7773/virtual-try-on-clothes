// Typed argument objects for named routes.
//
// Pass these via `Navigator.pushNamed(name, arguments: ...)` (or
// `NavigationService.pushNamed(name, arguments: ...)`) and extract them
// inside `RouteGenerator.generateRoute` with
// `settings.arguments as <ScreenName>Args?`. Always keep them immutable.

import 'package:flutter/foundation.dart';

import '../../features/web_view/models/url_visit.dart';
import '../../features/web_view/models/web_destination.dart';

/// Which site the in-app browser should open.
@immutable
class WebViewScreenArgs {
  final WebDestination destination;

  const WebViewScreenArgs({required this.destination});
}

/// Which recorded visit the detail screen should show.
@immutable
class UrlVisitDetailArgs {
  final UrlVisit visit;

  const UrlVisitDetailArgs({required this.visit});
}

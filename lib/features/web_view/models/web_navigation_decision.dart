/// What the browser should do with a navigation the page asked for.
enum WebNavigationAction {
  /// Let the web view handle it as it would normally.
  allow,

  /// Refuse it. Used for schemes that belong to other apps.
  block,

  /// Refuse it in the frame that asked, and load it as a full page instead.
  openTopLevel,
}

/// Decides what happens when a page navigates.
///
/// Two rules, both about staying out of the user's way:
///
/// 1. `tel:`, `mailto:` and Android's `intent://` belong to other apps. A web
///    view handed one only renders an error page.
/// 2. A site that opens outside links inside its own embedded browser — the
///    mirror's style cards do exactly this — puts an iframe between the user
///    and the page they tapped. Most retailers refuse to be framed at all, so
///    that iframe comes up blank with an "Open" button over it. When the
///    destination is marked for it, the browser skips the frame and loads the
///    link as a real page.
WebNavigationAction decideWebNavigation({
  required String url,
  required bool isMainFrame,
  required String currentHost,
  required bool promotesFramedLinks,
}) {
  final uri = Uri.tryParse(url);
  final scheme = uri?.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') return WebNavigationAction.block;

  if (isMainFrame || !promotesFramedLinks) return WebNavigationAction.allow;

  // A frame loading part of its own site is the site working normally — an
  // embedded map, a video, a checkout widget. Only a jump to another host
  // reads as a link the user tapped.
  final host = uri!.host;
  if (host.isEmpty || host == currentHost) return WebNavigationAction.allow;

  return WebNavigationAction.openTopLevel;
}

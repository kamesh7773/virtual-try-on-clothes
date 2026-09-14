import 'package:webview_flutter/webview_flutter.dart';

/// iOS reports a navigation the app cancelled as `NSURLErrorCancelled`.
const int _nsUrlErrorCancelled = -999;

/// Chromium reports the same thing as `net::ERR_ABORTED`, arriving as a
/// generic error with the reason only in its description.
const String _chromiumAborted = 'ERR_ABORTED';

/// Whether a web view error means the page is dead, or only that a load was
/// thrown away.
///
/// Going back cancels whatever the page being left still had in flight, and
/// both platforms report that cancellation down the same callback a real
/// failure arrives on — neither with an error type of its own. Taking every
/// error at face value puts a "try again" screen over a page that loaded
/// perfectly well, which is what a user sees on the way back from a retailer
/// whose page was still fetching when they left it.
bool isPageFailure(WebResourceError error, {required String loadingUrl}) {
  // Only the main frame is the page. A blocked tracker or a missing image
  // fails the same way a dead page does.
  if (error.isForMainFrame != true) return false;

  if (error.errorCode == _nsUrlErrorCancelled) return false;
  if (error.description.contains(_chromiumAborted)) return false;

  // An error naming a page other than the one now loading belongs to the
  // load that has just been replaced, however it was worded.
  final url = error.url;
  if (url != null && url.isNotEmpty && url != loadingUrl) return false;

  return true;
}

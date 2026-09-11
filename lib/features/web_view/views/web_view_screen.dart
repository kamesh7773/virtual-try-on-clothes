import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../../core/routes/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/stage_back_button.dart';
import '../models/web_destination.dart';
import '../models/web_navigation_decision.dart';
import '../models/web_tap_report.dart';
import '../models/visit_trigger.dart';
import '../view_models/url_history_view_model.dart';

/// An in-app browser for a single [WebDestination].
///
/// The page runs edge to edge under a single back control. No title, no
/// address, no load bar, no scrollbars — the site is left to present itself,
/// at the full width it expects, and reads as a screen rather than a page.
/// The one control is the way out: back walks the page history first and
/// only leaves the screen once there is nothing left to go back to.
class WebViewScreen extends HookConsumerWidget {
  final WebDestination destination;

  const WebViewScreen({super.key, required this.destination});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failure = useState<String?>(null);
    final canGoBack = useState<bool>(false);
    final history = ref.read(urlHistoryViewModelProvider.notifier);

    // The visit currently loading. Held in refs, not state: nothing on this
    // screen renders them, and a rebuild per page load would restart nothing
    // but would cost a frame.
    final visitId = useRef<String?>(null);
    final visitStartedAt = useRef<DateTime?>(null);

    useEffect(() {
      // Reading the store is what makes a page recorded now sit above the
      // pages recorded last week.
      WidgetsBinding.instance.addPostFrameCallback((_) => history.load());
      return null;
    }, const []);

    // Tied to the URL so the controller — and the page it holds — survives
    // every rebuild this screen does.
    final controller = useMemoized(
      () => _createController(
        destination: destination,
        failure: failure,
        canGoBack: canGoBack,
        onVisitStarted: (url, tap, trigger) {
          visitId.value = history.record(
            url: url,
            destinationId: destination.id,
            trigger: trigger,
            tappedLabel: tap?.label,
            tappedContext: tap?.context,
            sourceUrl: tap?.sourceUrl,
            sourceTitle: tap?.sourceTitle,
          );
          visitStartedAt.value = DateTime.now();
          _showVisitSnackBar(context, url);
        },
        onVisitFinished: (title) {
          final id = visitId.value;
          final startedAt = visitStartedAt.value;
          if (id == null) return;
          history.markLoaded(
            id,
            title: title,
            loadTime: startedAt == null
                ? null
                : DateTime.now().difference(startedAt),
          );
        },
        onVisitFailed: (message) {
          final id = visitId.value;
          if (id == null) return;
          history.markFailed(id, message);
        },
        // The element outlives every rebuild, so this stays a valid check
        // for as long as the controller it is handed to does.
        isMounted: () => context.mounted,
      ),
      [destination.url],
    );

    return PopScope(
      // Sitting on the first page, a back gesture leaves the screen — which
      // is also what lets iOS run its swipe-back transition. Deeper in, the
      // gesture is intercepted below and walks the page history instead.
      canPop: !canGoBack.value,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await controller.canGoBack()) {
          await controller.goBack();
          return;
        }
        navigator.pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.stageBackground,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The only chrome left. Without it an iOS user who has browsed
              // a page deep has no way back: the swipe gesture is off while
              // there is page history to walk.
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                child: const StageBackButton(),
              ),
              Expanded(
                child: _Frame(
                  child: failure.value != null
                      ? _LoadFailure(
                          message: failure.value!,
                          onRetry: () {
                            failure.value = null;
                            controller.loadRequest(Uri.parse(destination.url));
                          },
                        )
                      : WebViewWidget(controller: controller),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The page, separated from the app's chrome by a hairline and nothing else.
///
/// Deliberately edge to edge: side gutters shrink the layout viewport, and a
/// site with a minimum width — most retail sites carry one — answers that by
/// overflowing rather than reflowing, which reads as content cut off at the
/// right edge.
class _Frame extends StatelessWidget {
  final Widget child;

  const _Frame({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.stageSurface,
        border: Border(top: BorderSide(color: AppColors.stageBorder)),
      ),
      child: ClipRect(child: child),
    );
  }
}

WebViewController _createController({
  required WebDestination destination,
  required ValueNotifier<String?> failure,
  required ValueNotifier<bool> canGoBack,
  required bool Function() isMounted,
  required void Function(String url, WebTapReport? tap, VisitTrigger trigger)
  onVisitStarted,
  required void Function(String? title) onVisitFinished,
  required void Function(String message) onVisitFailed,
}) {
  // Assigned on the next line; the delegate's callbacks only run long after.
  late final WebViewController controller;

  // Where the main frame is right now, which is what a framed link is judged
  // against. `onPageStarted` only fires for the main frame, so this stays the
  // page's own host.
  var currentHost = destination.host;

  // The last link promoted out of a frame. A page that re-inserts the same
  // iframe while the promoted page is still loading would otherwise ask for
  // it again on every mutation.
  String? lastPromoted;

  // What the page last said about a tap, waiting for the navigation it
  // explains. The two arrive separately and in that order.
  WebTapReport? pendingTap;
  DateTime? pendingTapAt;

  // The destination's own first page is opened by the app, not by a tap.
  var hasLoaded = false;
  // The mirror asks for the camera through getUserMedia, which WKWebView only
  // runs inline and without a tap gesture when the configuration says so — and
  // the configuration is fixed at creation time, not settable later.
  final params = WebViewPlatform.instance is WebKitWebViewPlatform
      ? WebKitWebViewControllerCreationParams(
          allowsInlineMediaPlayback: true,
          mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
        )
      : const PlatformWebViewControllerCreationParams();

  controller = WebViewController.fromPlatformCreationParams(params)
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setBackgroundColor(AppColors.stageBackground)
    // A native screen does not pinch-zoom, and it does not glow or rubber-band
    // at an edge it cannot scroll past.
    ..enableZoom(false)
    ..setOverScrollMode(WebViewOverScrollMode.ifContentScrolls)
    ..setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (request) {
          final action = decideWebNavigation(
            url: request.url,
            isMainFrame: request.isMainFrame,
            currentHost: currentHost,
            promotesFramedLinks: destination.promotesFramedLinks,
          );

          switch (action) {
            case WebNavigationAction.allow:
              return NavigationDecision.navigate;
            case WebNavigationAction.block:
              return NavigationDecision.prevent;
            case WebNavigationAction.openTopLevel:
              // Loading from inside the decision callback would re-enter the
              // web view while it is still deciding.
              Future.microtask(
                () => controller.loadRequest(Uri.parse(request.url)),
              );
              return NavigationDecision.prevent;
          }
        },
        onPageStarted: (url) {
          currentHost = Uri.tryParse(url)?.host ?? destination.host;
          lastPromoted = null;
          failure.value = null;

          // A report older than this belongs to a tap that led nowhere — an
          // in-page link, a dismissed overlay — not to the page now loading.
          final reportedAt = pendingTapAt;
          final isFresh =
              reportedAt != null &&
              DateTime.now().difference(reportedAt) <
                  const Duration(seconds: 8);
          final tap = isFresh ? pendingTap : null;
          pendingTap = null;
          pendingTapAt = null;

          onVisitStarted(
            url,
            tap,
            tap?.trigger ??
                (hasLoaded ? VisitTrigger.inPage : VisitTrigger.direct),
          );
          hasLoaded = true;

          // The head usually exists by now, so the page is styled before its
          // first paint. The script no-ops when it does not.
          _applyNativeFeel(controller);
          _applyBridge(controller, promote: destination.promotesFramedLinks);
        },
        onPageFinished: (_) {
          _applyNativeFeel(controller);
          _applyBridge(controller, promote: destination.promotesFramedLinks);
          // The title is only worth recording once the page has one, which is
          // why the visit is completed here rather than on the first byte.
          controller.getTitle().then((title) {
            if (isMounted()) onVisitFinished(title);
          });
          // Asked per page rather than tracked by hand: the page can push
          // history entries of its own that no callback here reports.
          controller.canGoBack().then((value) {
            // The answer arrives a frame or two later, by which time the
            // screen — and the notifier — may be gone.
            if (isMounted()) canGoBack.value = value;
          });
        },
        onWebResourceError: (error) {
          // A blocked tracker or a missing image fails the same way a dead
          // page does; only the main frame is worth an error screen.
          if (error.isForMainFrame != true) return;
          final message = error.description.isEmpty
              ? 'This page could not be loaded.'
              : error.description;
          failure.value = message;
          onVisitFailed(message);
        },
      ),
    );

  // Both platforms draw their own scroll indicators over the page; a native
  // screen shows none. The CSS below cannot reach these — on iOS they belong
  // to the UIScrollView, not the document.
  controller.supportsSetScrollBarsEnabled().then((supported) {
    if (!supported) return;
    controller
      ..setVerticalScrollBarEnabled(false)
      ..setHorizontalScrollBarEnabled(false);
  });

  final platform = controller.platform;
  if (platform is AndroidWebViewController) {
    // Android blocks autoplay until the user taps; a camera preview never
    // gets that tap.
    platform.setMediaPlaybackRequiresUserGesture(false);
  }
  if (platform is AndroidWebViewController ||
      platform is WebKitWebViewController) {
    platform.setOnPlatformPermissionRequest(_handlePermissionRequest);

    // Release builds stay quiet; in debug the page's own console is the only
    // window into what a site does when a link is tapped.
    if (kDebugMode) {
      platform.setOnConsoleMessage(
        (message) => debugPrint(
          '[web] ${message.level.name}: '
          '${message.message}',
        ),
      );
    }
  }

  // The page is the only place a tap's details exist, and on Android it is
  // also the only place an iframe set by script is visible at all — the
  // navigation delegate above never sees one.
  controller.addJavaScriptChannel(
    _bridgeChannel,
    onMessageReceived: (message) {
      final report = WebTapReport.tryParse(message.message);
      if (report == null) return;

      final uri = Uri.tryParse(report.url);
      if (uri == null) return;
      if (uri.scheme != 'http' && uri.scheme != 'https') return;

      pendingTap = report;
      pendingTapAt = DateTime.now();

      if (!report.promote) return;
      if (uri.host.isEmpty || uri.host == currentHost) return;
      if (report.url == lastPromoted) return;

      lastPromoted = report.url;
      controller.loadRequest(uri);
    },
  );

  controller.loadRequest(Uri.parse(destination.url));
  return controller;
}

/// Announces each page the browser opens, with a way straight to the full
/// history — the record is only useful if the user knows it is being kept.
void _showVisitSnackBar(BuildContext context, String url) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.stageElevated,
        duration: const Duration(seconds: 2),
        shape: const RoundedRectangleBorder(),
        content: Text(
          url,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11.sp, color: AppColors.onStageSecondary),
        ),
        action: SnackBarAction(
          label: 'HISTORY',
          textColor: AppColors.onStagePrimary,
          onPressed: () => Navigator.of(context).pushNamed(Routes.urlHistory),
        ),
      ),
    );
}

/// Trims the page back to what a screen in this app should look like: no
/// scrollbars of its own, no sideways overscroll, no blue tap flash, and no
/// link that quietly asks for a second window the app does not have.
const String _nativeFeelScript = r"""
(function () {
  var d = document;
  if (!d.head) return;

  // Pages written for a desktop report a viewport wider than the phone, and
  // that width is what the user ends up dragging sideways. Sites that ship
  // their own viewport tag are left alone.
  if (!d.querySelector('meta[name="viewport"]')) {
    var meta = d.createElement('meta');
    meta.name = 'viewport';
    meta.content = 'width=device-width, initial-scale=1, viewport-fit=cover';
    d.head.appendChild(meta);
  }

  // Nothing here constrains the page's width. Clamping `html`/`body` does
  // stop sideways scrolling, but on a layout that is genuinely wider than the
  // screen it hides the overflow instead of reflowing it — the right edge of
  // the page simply disappears.
  if (!d.getElementById('livelook-native-feel')) {
    var style = d.createElement('style');
    style.id = 'livelook-native-feel';
    style.textContent =
      'html,body{-webkit-tap-highlight-color:transparent !important;}' +
      'html{scrollbar-width:none !important;-ms-overflow-style:none !important;' +
      'overscroll-behavior-x:none !important;}' +
      '*::-webkit-scrollbar{width:0 !important;height:0 !important;' +
      'display:none !important;}';
    d.head.appendChild(style);
  }

  // There is one window here, and a link that asks for a second one gets
  // nothing: window.open returns a window iOS never shows, and target=_blank
  // does nothing at all. Either way the user taps and the app sits still.
  if (!window.__livelookLinksPatched) {
    window.__livelookLinksPatched = true;

    var nativeOpen = window.open;
    window.open = function (url) {
      if (url) {
        window.location.href = url;
        return window;
      }
      return nativeOpen ? nativeOpen.apply(window, arguments) : null;
    };

    d.addEventListener('click', function (event) {
      var target = event.target;
      var link = target && target.closest ? target.closest('a[target]') : null;
      if (link && link.href && link.target && link.target !== '_self') {
        link.target = '_self';
      }
    }, true);
  }
})();
""";

void _applyNativeFeel(WebViewController controller) {
  // A page that failed to load has no document to style, and that failure is
  // already on screen — nothing here is worth a second error.
  controller.runJavaScript(_nativeFeelScript).catchError((Object _) {});
}

/// Name of the channel the page posts tapped links to. Must match the script.
const String _bridgeChannel = 'LiveLookBridge';

/// Reports what the user tapped, and — where the destination asks for it —
/// hands the link over so the app can open it as a full page.
///
/// The page is the only place these details exist. By the time a navigation
/// reaches the app, the card, its words and the heading above it are gone,
/// and on Android a scripted iframe is never reported at all.
const String _bridgeScript = r"""
(function () {
  if (window.__livelookBridge) return;
  if (typeof LiveLookBridge === 'undefined') return;
  if (!document.documentElement) return;
  window.__livelookBridge = true;

  var promoting = window.__livelookPromote === true;
  console.log('livelook: bridge installed on ' + location.href +
    (promoting ? ' (promoting)' : ''));

  function external(url) {
    if (!url || !/^https?:/i.test(url)) return null;
    try {
      var resolved = new URL(url, location.href);
      if (!resolved.host || resolved.host === location.host) return null;
      return resolved.href;
    } catch (e) {
      return null;
    }
  }

  function words(node) {
    if (!node) return '';
    var text = node.innerText || node.textContent || '';
    return text.replace(/\s+/g, ' ').trim();
  }

  // What the user actually hit: the nearest thing up the tree that says
  // something, e.g. "GET THIS STYLE" or the card's own name.
  function labelFor(node) {
    var el = node;
    for (var depth = 0; el && depth < 6; depth++) {
      var text = words(el);
      if (text && text.length <= 120) return text;
      el = el.parentElement;
    }
    return '';
  }

  // What it sat under, which is what turns "GET THIS STYLE" into something
  // worth reading back a week later.
  function contextFor(node) {
    var el = node;
    for (var depth = 0; el && depth < 8; depth++) {
      var heading = el.querySelector ? el.querySelector('h1,h2,h3,h4') : null;
      var text = words(heading);
      if (text && text.length <= 120) return text;
      el = el.parentElement;
    }
    var page = document.querySelector('h1');
    return words(page).slice(0, 120) || document.title || '';
  }

  // Between handing the link over and the next page painting, the page is
  // still showing whatever it was about to do with it — the blank in-page
  // browser, mid-animation. Covering it makes the tap read as one step.
  function cover() {
    if (document.getElementById('livelook-cover')) return;
    var host = document.body || document.documentElement;
    if (!host) return;

    var sheet = document.createElement('div');
    sheet.id = 'livelook-cover';
    sheet.style.cssText =
      'position:fixed;top:0;right:0;bottom:0;left:0;background:#0A0A0A;' +
      'z-index:2147483647;';
    host.appendChild(sheet);

    // If the app decided not to navigate after all, the page must not be left
    // under a sheet it cannot lift.
    setTimeout(function () {
      var stale = document.getElementById('livelook-cover');
      if (stale && stale.parentNode) stale.parentNode.removeChild(stale);
    }, 2500);
  }

  function report(url, trigger, node, promote) {
    if (!url) return false;
    if (promote) cover();
    console.log('livelook: ' + (promote ? 'promoting ' : 'tap ') + url +
      ' (' + trigger + ')');
    LiveLookBridge.postMessage(JSON.stringify({
      url: url,
      trigger: trigger,
      promote: !!promote,
      label: node ? labelFor(node) : '',
      context: node ? contextFor(node) : '',
      sourceUrl: location.href,
      sourceTitle: document.title || ''
    }));
    return true;
  }

  // Only attributes that read as a destination. A card carries its artwork in
  // `src`, `data-src` and `style`, all of them absolute URLs on someone
  // else's CDN, and following one would land the user on a photo.
  var DESTINATION = /(href|url|link|destination|shop|site)/i;
  var ASSET = /\.(png|jpe?g|gif|webp|avif|svg|ico|mp4|webm|mp3|css|js)($|[?#])/i;

  // A card that is not a link keeps its URL somewhere on itself — a data
  // attribute, usually. Finding it on the tap is what makes the jump
  // immediate: waiting for the iframe means waiting for the overlay that
  // holds it to animate in first.
  function attributeLink(node) {
    var el = node;
    for (var depth = 0; el && depth < 6; depth++) {
      var attributes = el.attributes;
      for (var i = 0; attributes && i < attributes.length; i++) {
        var attribute = attributes[i];
        if (!DESTINATION.test(attribute.name)) continue;
        if (ASSET.test(attribute.value)) continue;
        var found = external(attribute.value);
        if (found) return found;
      }
      el = el.parentElement;
    }
    return null;
  }

  document.addEventListener('click', function (event) {
    var node = event.target;
    var anchor = node && node.closest ? node.closest('a[href]') : null;
    var outside = anchor ? external(anchor.href) : null;
    var carried = outside ? null : attributeLink(node);

    if (promoting && (outside || carried)) {
      // Taken before the page sees it: left alone, it would put the link
      // inside its own browser instead of going there.
      event.preventDefault();
      event.stopPropagation();
      if (event.stopImmediatePropagation) event.stopImmediatePropagation();
      report(outside || carried, outside ? 'link' : 'element', node, true);
      return;
    }

    // Elsewhere the page handles its own links; this only says what was hit,
    // so the navigation that follows can be recorded with the card's words.
    if (anchor && /^https?:/i.test(anchor.href)) {
      report(anchor.href, 'link', node, false);
    } else if (carried) {
      report(carried, 'element', node, false);
    }
  }, true);

  if (!promoting) return;

  // Analytics and consent scripts drop external iframes on almost every page,
  // sized to nothing and hidden. Promoting one would navigate the user to a
  // tracker they never asked for, so only a frame big enough to be the thing
  // on screen counts as a tapped link.
  function decorative(frame) {
    if (frame.hidden) return true;

    var width = frame.getAttribute('width');
    var height = frame.getAttribute('height');
    if (width !== null && parseInt(width, 10) < 120) return true;
    if (height !== null && parseInt(height, 10) < 120) return true;

    var style = window.getComputedStyle ? window.getComputedStyle(frame) : null;
    if (style && (style.display === 'none' || style.visibility === 'hidden')) {
      return true;
    }

    // A frame still being laid out measures zero; that is not yet a reason to
    // rule it out, only a measured, small one is.
    var rect = frame.getBoundingClientRect ? frame.getBoundingClientRect() : null;
    if (rect && rect.width && rect.height) {
      if (rect.width < 120 || rect.height < 120) return true;
    }

    return false;
  }

  function scanFrame(frame) {
    if (decorative(frame)) return false;
    var link = external(frame.src);
    if (!link) return false;
    return report(link, 'frame', frame.parentElement, true);
  }

  function scan(node) {
    if (!node || node.nodeType !== 1) return;
    if (node.tagName === 'IFRAME' && scanFrame(node)) return;
    if (!node.querySelectorAll) return;
    var frames = node.querySelectorAll('iframe');
    for (var i = 0; i < frames.length; i++) {
      if (scanFrame(frames[i])) return;
    }
  }

  new MutationObserver(function (records) {
    for (var i = 0; i < records.length; i++) {
      var record = records[i];
      if (record.type === 'attributes') {
        scan(record.target);
        continue;
      }
      for (var j = 0; j < record.addedNodes.length; j++) {
        scan(record.addedNodes[j]);
      }
    }
  }).observe(document.documentElement, {
    childList: true,
    subtree: true,
    attributes: true,
    attributeFilter: ['src'],
  });

  // A viewer page keeps the link it is showing in its own address — the
  // "?url=https://…" pattern behind most in-page browsers. Landing on one is
  // the same tap, one redirect later.
  try {
    var params = new URL(location.href).searchParams;
    var keys = ['url', 'u', 'link', 'href', 'target', 'redirect'];
    for (var i = 0; i < keys.length; i++) {
      var carriedUrl = external(params.get(keys[i]));
      if (carriedUrl && report(carriedUrl, 'viewer', document.body, true)) {
        return;
      }
    }
  } catch (e) {}

  // Anything already on the page when this runs.
  scan(document.body);
})();
""";

void _applyBridge(WebViewController controller, {required bool promote}) {
  // The flag has to be set before the script reads it, and a page reload
  // wipes both, so they travel together.
  controller
      .runJavaScript('window.__livelookPromote = $promote;\n$_bridgeScript')
      .catchError((Object _) {});
}

/// Camera and microphone are what the mirror needs, and the OS has already
/// asked for both by the time a page can request them. Anything else — a
/// location prompt, a MIDI device — is denied rather than passed through.
void _handlePermissionRequest(PlatformWebViewPermissionRequest request) {
  const allowed = <WebViewPermissionResourceType>{
    WebViewPermissionResourceType.camera,
    WebViewPermissionResourceType.microphone,
  };

  if (request.types.isNotEmpty && request.types.every(allowed.contains)) {
    request.grant();
  } else {
    request.deny();
  }
}

/// The stage-palette twin of `ErrorView`, which is built for the app's light
/// surfaces and disappears against black.
class _LoadFailure extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LoadFailure({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 32.r,
              color: AppColors.onStageFaint,
            ),
            SizedBox(height: 14.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.sp,
                height: 1.5,
                color: AppColors.onStageMuted,
              ),
            ),
            SizedBox(height: 18.h),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.onStagePrimary,
                side: const BorderSide(color: AppColors.stageBorderActive),
                shape: const RoundedRectangleBorder(),
                padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 12.h),
              ),
              child: Text(
                'RETRY',
                style: TextStyle(fontSize: 10.sp, letterSpacing: 2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

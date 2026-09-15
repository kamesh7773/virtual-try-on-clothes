import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../../core/theme/app_colors.dart';
import '../models/visit_trigger.dart';
import '../models/shop_link.dart';
import '../models/web_bridge_message.dart';
import '../models/web_load_failure.dart';
import '../models/web_destination.dart';
import '../models/web_navigation_decision.dart';
import '../models/web_product.dart';
import '../models/web_tap_report.dart';
import '../view_models/history_flow_view_model.dart';
import '../view_models/product_try_on_view_model.dart';
import '../view_models/url_history_view_model.dart';
import 'widgets/try_on_overlay.dart';
import 'widgets/try_on_preview.dart';
import 'widgets/web_overlay_button.dart';
import 'widgets/web_loading_cover.dart';

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
    // The page the failure was for, so retrying asks for that one again.
    final failedUrl = useState<String?>(null);
    final canGoBack = useState<bool>(false);
    // True from the moment a page is asked for until it has painted
    // something — the page's first paint, not its `load` event, which on a
    // retail site can be tens of seconds later. Starts true: the first page
    // is already on its way.
    final isLoading = useState<bool>(true);
    // Which site the page is on, which is what tells a link the browser
    // followed out apart from the destination's own pages.
    final currentHost = useState<String>(destination.host);
    final history = ref.read(urlHistoryViewModelProvider.notifier);
    final flow = ref.read(historyFlowViewModelProvider.notifier);
    final tryOn = ref.watch(productTryOnViewModelProvider);
    final tryOnViewModel = ref.read(productTryOnViewModelProvider.notifier);

    // The visit currently loading. Held in refs, not state: nothing on this
    // screen renders them, and a rebuild per page load would restart nothing
    // but would cost a frame.
    final visitId = useRef<String?>(null);
    final visitStartedAt = useRef<DateTime?>(null);

    // What the page last said about a tap, waiting for the navigation it
    // explains. Held here rather than inside the controller so the app can
    // file its own — the try-on jump is a tap the page never saw.
    final pendingTap = useRef<WebTapReport?>(null);
    final pendingTapAt = useRef<DateTime?>(null);

    useEffect(() {
      // Reading the store is what makes a page recorded now sit above the
      // pages recorded last week.
      WidgetsBinding.instance.addPostFrameCallback((_) => history.load());
      return null;
    }, const []);

    // A journey the user walks away from is still a journey. Reported when
    // the app goes to the background, which is the only ending the browser
    // itself never sees — every other one is a return to the mirror.
    useOnAppLifecycleStateChange((_, current) {
      if (current == AppLifecycleState.paused ||
          current == AppLifecycleState.detached) {
        flow.completeFlow();
      }
    });

    // A page that never reports a paint would otherwise leave the cover up
    // until its `load` event, or for good. The cover is only a cover:
    // dropping it late is recoverable, keeping it forever is not.
    useEffect(() {
      if (!isLoading.value) return null;
      final timer = Timer(_loadCoverLimit, () => isLoading.value = false);
      return timer.cancel;
    }, [isLoading.value]);

    // Tied to the URL so the controller — and the page it holds — survives
    // every rebuild this screen does.
    final controller = useMemoized(
      () => _createController(
        destination: destination,
        failure: failure,
        failedUrl: failedUrl,
        canGoBack: canGoBack,
        isLoading: isLoading,
        currentHost: currentHost,
        pendingTap: pendingTap,
        pendingTapAt: pendingTapAt,
        onProduct: tryOnViewModel.setProduct,
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

          // The flow is the unit the backend is told about, and it is only a
          // flow once it has left the mirror for a retailer.
          flow.noteVisit(
            visitId.value!,
            isOwnSite: destination.isOwnSite(Uri.tryParse(url)?.host ?? ''),
          );
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

    // Asked of where the browser is now, not of what opened it: following a
    // link off the mirror lands on a layout that needs the status bar kept
    // clear again, and going back gives the screen away again.
    final edgeToEdge = WebDestinations.handlesOwnInsets(currentHost.value);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The stage is black, and the app now opens on it — dark status bar
      // icons would be invisible against it from the first frame.
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.stageBackground,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: PopScope(
        // Deeper than the first page, a back gesture walks the page history
        // instead of leaving. On the first page it is let through, which on
        // Android closes the app the way leaving a site's home page should.
        canPop: !canGoBack.value && !tryOn.hasResult,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          final navigator = Navigator.of(context);

          // The try-on lies over the page, so it is what a back gesture is
          // asking to leave — not the page underneath it.
          if (ref.read(productTryOnViewModelProvider).hasResult) {
            tryOnViewModel.dismissResult();
            return;
          }
          if (await controller.canGoBack()) {
            await controller.goBack();
            return;
          }
          navigator.pop();
        },
        child: Scaffold(
          backgroundColor: AppColors.stageBackground,
          // No chrome and no padding around the page, and the bottom is
          // never inset: a page that stops above the home indicator reads
          // as letterboxed, which is the look this screen has no chrome in
          // order to avoid. The top is inset only for a site that does not
          // know the status bar is there — see [WebDestinations
          // .handlesOwnInsets].
          body: SafeArea(
            top: !edgeToEdge,
            bottom: false,
            child: _Frame(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: failure.value != null
                        ? _LoadFailure(
                            message: failure.value!,
                            onRetry: () {
                              final retry = failedUrl.value ?? destination.url;
                              failure.value = null;
                              isLoading.value = true;
                              controller.loadRequest(Uri.parse(retry));
                            },
                          )
                        : WebViewWidget(controller: controller),
                  ),
                  // Only once the browser has followed a link off the
                  // destination's own site. The destination draws a back
                  // control of its own, and on its first page there is
                  // nothing behind it to go back to.
                  if (failure.value == null &&
                      canGoBack.value &&
                      !destination.isOwnSite(currentHost.value))
                    Positioned(
                      // The page runs under the status bar, but this does not:
                      // a control sitting behind the clock is a control that
                      // cannot be read or reliably tapped.
                      top: edgeToEdge
                          ? MediaQuery.paddingOf(context).top + 10.h
                          : 10.h,
                      left: 12.w,
                      child: WebOverlayButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        label: 'Back',
                        onTap: controller.goBack,
                      ),
                    ),
                  if (tryOn.canTryOn && failure.value == null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: TryOnOverlay(
                          product: tryOn.product!,
                          category: tryOn.category!,
                          isLoading: tryOn.isLoading,
                          onTap: () async {
                            await tryOnViewModel.requestTryOn();
                            if (!context.mounted) return;

                            // The answer is an image, shown by the preview
                            // below; only a failure needs saying out loud.
                            final error = ref
                                .read(productTryOnViewModelProvider)
                                .error;
                            if (error == null) return;

                            _showMessage(context, error, isError: true);
                            tryOnViewModel.dismissError();
                          },
                        ),
                      ),
                    ),
                  // Over the page and over its controls: the view keeps
                  // loading underneath, and there is nothing for a back
                  // control or a try-on offer to act on until it arrives.
                  // The cover lifts the moment the page has painted, or at
                  // the limit above, which is what keeps a page that never
                  // reports back from hiding them for good. It fades rather
                  // than pops: the page underneath is already showing
                  // through it, and a cut would read as a flash.
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: !isLoading.value,
                      child: AnimatedSwitcher(
                        duration: _coverFade,
                        child: isLoading.value && failure.value == null
                            ? const WebLoadingCover()
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                  // Last in the stack, and so over everything else: while a
                  // try-on is up it is the only thing to look at.
                  if (tryOn.resultUrl != null)
                    Positioned.fill(
                      child: TryOnPreview(
                        imageUrl: tryOn.resultUrl!,
                        onClose: tryOnViewModel.dismissResult,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The page, and nothing around it.
///
/// Deliberately edge to edge: side gutters shrink the layout viewport, and a
/// site with a minimum width — most retail sites carry one — answers that by
/// overflowing rather than reflowing, which reads as content cut off at the
/// right edge. Not even a hairline at the top: there is no app chrome left
/// for it to separate the page from.
class _Frame extends StatelessWidget {
  final Widget child;

  const _Frame({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.stageSurface),
      child: ClipRect(child: child),
    );
  }
}

WebViewController _createController({
  required WebDestination destination,
  required ValueNotifier<String?> failure,
  required ValueNotifier<String?> failedUrl,
  required ValueNotifier<bool> canGoBack,
  required ValueNotifier<bool> isLoading,
  required ValueNotifier<String> currentHost,
  required bool Function() isMounted,
  required ObjectRef<WebTapReport?> pendingTap,
  required ObjectRef<DateTime?> pendingTapAt,
  required void Function(WebProduct? product) onProduct,
  required void Function(String url, WebTapReport? tap, VisitTrigger trigger)
  onVisitStarted,
  required void Function(String? title) onVisitFinished,
  required void Function(String message) onVisitFailed,
}) {
  // Assigned on the next line; the delegate's callbacks only run long after.
  late final WebViewController controller;

  // `currentHost` is where the main frame is right now — what a framed link
  // is judged against, and what the floating back control keys off.
  // `onPageStarted` only fires for the main frame, so it stays the page's own
  // host rather than following a tracker into an iframe.

  // The page the user is looking at, recorded as the source of a tap.
  var currentUrl = destination.url;

  // The last link promoted out of a frame. A page that re-inserts the same
  // iframe while the promoted page is still loading would otherwise ask for
  // it again on every mutation.
  String? lastPromoted;

  // The destination's own first page is opened by the app, not by a tap.
  var hasLoaded = false;

  // Debug only: a clock on the lifecycle lines, so a log dump says how long
  // each page took rather than only what order things came in.
  final clock = Stopwatch()..start();
  String stamp() => '[web +${clock.elapsedMilliseconds}ms]';

  // The paint probe is re-sent on a clock after every page start, not only
  // on progress ticks. On iOS page start fires while the old document is
  // still the one scripts land in, and the progress observer that would
  // carry the probe into the new one goes through a plugin path that has
  // been seen to fail. A few timed sends land in the new document whatever
  // the observers do; the probe itself installs once and no more.
  final probeTimers = <Timer>[];
  void cancelProbes() {
    for (final timer in probeTimers) {
      timer.cancel();
    }
    probeTimers.clear();
  }

  void scheduleProbes() {
    cancelProbes();
    for (final delay in _paintProbeRetries) {
      probeTimers.add(Timer(delay, () => _applyPaintProbe(controller)));
    }
  }

  // `load` on a page that has not painted is not a page to show. A retailer
  // met for the first time answers with a blank interstitial that finishes
  // in a moment and then loads the real page over itself; lifting the cover
  // on that first `load` puts a white flash between two waits. So the
  // finish only starts a short grace, and the probe is asked once more: a
  // page that has painted answers inside the grace, a blank one does not,
  // and the next page start cancels it.
  Timer? finishGrace;
  void lift() {
    finishGrace?.cancel();
    finishGrace = null;
    cancelProbes();
    if (isMounted()) isLoading.value = false;
  }

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
            currentHost: currentHost.value,
            promotesFramedLinks: destination.promotesFramedLinksOn(
              currentHost.value,
            ),
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
        // A retail page's load event can be minutes away — trackers, video,
        // lazy images — and waiting for it to inject leaves the user on a
        // product page the app has not looked at yet. Once the page is
        // mostly there it is worth looking at; the script installs once and
        // the rest of these only ask it to scan again.
        onProgress: (progress) => _safely('onProgress', () {
          // The paint probe goes in on every tick as well as on the clock
          // above: whichever reaches the new document first wins, and the
          // probe installs itself once per document and no more.
          _applyPaintProbe(controller);
          if (progress < _bridgeProgress) return;
          _applyNativeFeel(controller);
          _applyBridge(
            controller,
            promote: destination.promotesFramedLinksOn(currentHost.value),
          );
        }),
        // A site that navigates without loading — most retailers, once they
        // are running — reports itself here and nowhere else.
        onUrlChange: (change) => _safely('onUrlChange', () {
          final url = change.url;
          if (url == null || url.isEmpty) return;
          if (kDebugMode) debugPrint('${stamp()} url change → $url');

          currentUrl = url;
          currentHost.value = Uri.tryParse(url)?.host ?? currentHost.value;
          _applyPaintProbe(controller);
          _applyBridge(
            controller,
            promote: destination.promotesFramedLinksOn(currentHost.value),
          );
        }),
        onPageStarted: (url) => _safely('onPageStarted', () {
          if (kDebugMode) debugPrint('${stamp()} page started → $url');
          finishGrace?.cancel();
          finishGrace = null;
          isLoading.value = true;
          currentUrl = url;
          currentHost.value = Uri.tryParse(url)?.host ?? destination.host;
          lastPromoted = null;
          failure.value = null;

          // A report older than this belongs to a tap that led nowhere — an
          // in-page link, a dismissed overlay — not to the page now loading.
          final reportedAt = pendingTapAt.value;
          final isFresh =
              reportedAt != null &&
              DateTime.now().difference(reportedAt) <
                  const Duration(seconds: 8);
          final tap = isFresh ? pendingTap.value : null;
          pendingTap.value = null;
          pendingTapAt.value = null;

          // The old page's product is gone the moment the next one starts.
          onProduct(null);

          onVisitStarted(
            url,
            tap,
            tap?.trigger ??
                (hasLoaded ? VisitTrigger.inPage : VisitTrigger.direct),
          );
          hasLoaded = true;

          // The head usually exists by now, so the page is styled before its
          // first paint. The script no-ops when it does not.
          _applyPaintProbe(controller);
          scheduleProbes();
          _applyNativeFeel(controller);
          _applyBridge(
            controller,
            promote: destination.promotesFramedLinksOn(currentHost.value),
          );
        }),
        onPageFinished: (url) => _safely('onPageFinished', () {
          if (kDebugMode) debugPrint('${stamp()} page finished → $url');
          // Usually long lifted by the paint probe. This is the backstop for
          // a page that painted without saying so — see `finishGrace`.
          cancelProbes();
          _applyPaintProbe(controller);
          finishGrace?.cancel();
          finishGrace = Timer(_finishGrace, lift);
          _applyNativeFeel(controller);
          _applyBridge(
            controller,
            promote: destination.promotesFramedLinksOn(currentHost.value),
          );
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
        }),
        onWebResourceError: (error) => _safely('onWebResourceError', () {
          if (kDebugMode) {
            debugPrint(
              '${stamp()} error ${error.errorCode} ${error.errorType?.name} '
              'main=${error.isForMainFrame} url=${error.url} '
              '"${error.description}" (loading $currentUrl)',
            );
          }
          if (!isPageFailure(error, loadingUrl: currentUrl)) return;

          finishGrace?.cancel();
          finishGrace = null;
          cancelProbes();
          isLoading.value = false;
          final message = error.description.isEmpty
              ? 'This page could not be loaded.'
              : error.description;
          // What to try again, which is the page that failed and not the
          // site's front door.
          failedUrl.value = error.url ?? currentUrl;
          failure.value = message;
          onVisitFailed(message);
        }),
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
    // window into what a site does when a link is tapped. `console.debug` is
    // left out: a retailer's telemetry SDK writes hundreds of those per page,
    // and each one crosses to Dart and through `debugPrint`'s throttle,
    // burying the lines worth reading.
    if (kDebugMode) {
      platform.setOnConsoleMessage((message) {
        if (message.level == JavaScriptLogLevel.debug) return;
        debugPrint('[web] ${message.level.name}: ${message.message}');
      });
    }
  }

  // The page is the only place a tap's details exist, and on Android it is
  // also the only place an iframe set by script is visible at all — the
  // navigation delegate above never sees one.
  controller.addJavaScriptChannel(
    _bridgeChannel,
    onMessageReceived: _guarded(_bridgeChannel, (message) {
      switch (WebBridgeMessage.tryParse(message.message)) {
        case WebProductMessage(:final product):
          onProduct(product);

        case WebPaintedMessage(:final url):
          if (kDebugMode) debugPrint('${stamp()} painted → $url');
          // A paint reported by the page being left — its probe outlives it
          // until the next document commits — must not lift the cover off
          // the one still on its way. The host is what tells them apart in
          // the case that matters, the jump from the mirror to a retailer.
          if (url.host != currentHost.value) return;
          lift();

        case WebTapMessage(:final report):
          final uri = Uri.tryParse(report.url);
          if (uri == null) return;
          if (uri.scheme != 'http' && uri.scheme != 'https') return;

          pendingTap.value = report;
          pendingTapAt.value = DateTime.now();

          if (!report.promote) return;
          // The bridge is reachable by every script on the page, so the
          // decision is made here too, not trusted from the message.
          if (!destination.promotesFramedLinksOn(currentHost.value)) return;
          if (uri.host.isEmpty || uri.host == currentHost.value) return;
          if (report.url == lastPromoted) return;

          lastPromoted = report.url;
          controller.loadRequest(uri);

        case null:
          return;
      }
    }),
  );

  controller.addJavaScriptChannel(
    _shopLinkChannel,
    onMessageReceived: _guarded(_shopLinkChannel, (message) {
      // The channel is reachable by every script on every page, and only the
      // destination's own site is party to this contract.
      if (!destination.isOwnSite(currentHost.value)) return;

      final link = ShopLink.tryParse(message.message);
      if (link == null) {
        debugPrint('[shop-link] ignored: ${message.message}');
        return;
      }
      debugPrint('[shop-link] ${link.label} → ${link.url}');

      // Filed before the load so the history records the card that was
      // tapped, rather than the retailer appearing out of nowhere.
      pendingTap.value = WebTapReport(
        promote: true,
        url: link.url.toString(),
        trigger: VisitTrigger.element,
        label: link.label,
        context: "Men's Apparel",
        sourceUrl: currentUrl,
      );
      pendingTapAt.value = DateTime.now();
      controller.loadRequest(link.url);
    }),
  );

  controller.loadRequest(Uri.parse(destination.url));
  return controller;
}

/// Runs a navigation callback, keeping its failure on this side of the
/// bridge. Same reason as [_guarded]: the platform reports a callback that
/// threw as a bare native stack trace, and the Dart error is lost with it.
void _safely(String callback, void Function() body) {
  try {
    body();
  } catch (error, stack) {
    debugPrint('[web] $callback failed: $error\n$stack');
  }
}

/// Keeps a channel handler's failure on this side of the bridge.
///
/// An exception thrown from a channel callback goes back to the platform as
/// a method failure, which on iOS is logged as a bare native stack trace
/// with the Dart error nowhere in it. Caught here it is at least named, and
/// a page's message that the app could not handle costs the app nothing
/// more than that line.
void Function(JavaScriptMessage) _guarded(
  String channel,
  void Function(JavaScriptMessage message) handler,
) {
  return (message) {
    try {
      handler(message);
    } catch (error, stack) {
      debugPrint('[web] $channel handler failed: $error\n$stack');
    }
  };
}

/// Says something once, over the page. Used only when the app has to report
/// a failure the user asked for — a try-on that could not be fetched. Every
/// page load is recorded silently; the history screen is where it is read.
void _showMessage(
  BuildContext context,
  String message, {
  SnackBarAction? action,
  bool isError = false,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.stageElevated,
        duration: Duration(seconds: isError ? 4 : 2),
        shape: const RoundedRectangleBorder(),
        content: Text(
          message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11.sp,
            color: isError ? AppColors.error : AppColors.onStageSecondary,
          ),
        ),
        action: action,
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
  // that width is what the user ends up dragging sideways.
  var viewport = d.querySelector('meta[name="viewport"]');
  if (!viewport) {
    viewport = d.createElement('meta');
    viewport.name = 'viewport';
    viewport.content = 'width=device-width, initial-scale=1, viewport-fit=cover';
    d.head.appendChild(viewport);
  } else if (!/viewport-fit/.test(viewport.content || '')) {
    // A site's own viewport tag is otherwise left alone, but without this
    // one key iOS lays the page out inside the safe area and paints the
    // insets itself — black bars above and below a full-bleed page, which
    // is exactly what this screen has no chrome in order to avoid.
    viewport.content = (viewport.content || '') + ',viewport-fit=cover';
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

/// How far into a page load the bridge is worth injecting, in percent.
///
/// Early enough that a page which never finishes loading is still read, late
/// enough that there is a document with something in it to read.
const int _bridgeProgress = 60;

/// How long the loading cover may stay up without the page reporting a
/// paint. Past this the page is left to show whatever it has, however
/// little. Ten seconds, not twenty: with the cover lifting on first paint,
/// reaching this at all means the probe is not being heard, and the page
/// underneath is showing through the cover already.
const Duration _loadCoverLimit = Duration(seconds: 10);

/// How long the cover takes to fade once the page has painted.
const Duration _coverFade = Duration(milliseconds: 220);

/// How long after `load` the cover waits for a paint report before lifting
/// anyway. A page that has painted answers the probe within a frame or two;
/// this only has to outlast that, and the blank interstitial it exists for
/// starts its real load well inside it.
const Duration _finishGrace = Duration(milliseconds: 800);

/// Reports the page's first paint to the app, so the loading cover can lift
/// as soon as there is something under it to see.
///
/// `onPageFinished` is the window's `load` event, and on a retail site that
/// waits for every tracker, ad and lazy image — routinely ten to twenty
/// seconds after the page itself was on screen. The browser knows the
/// moment it first drew content and says so through the paint timing API;
/// where it does not, a body with a height that has survived two frames has
/// been drawn.
///
/// Installs itself once per document. Injected on every progress tick and
/// URL change rather than on page start, because on iOS page start fires
/// while the previous document is still the one scripts run in.
const String _paintProbeScript = r"""
(function () {
  if (window.__livelookPaintProbe) return;
  if (typeof LiveLookBridge === 'undefined') return;
  window.__livelookPaintProbe = true;

  var reported = false;
  function painted() {
    if (reported) return;
    reported = true;
    LiveLookBridge.postMessage(JSON.stringify({
      type: 'painted',
      url: location.href
    }));
  }

  function hasContentfulPaint(entries) {
    for (var i = 0; entries && i < entries.length; i++) {
      if (entries[i].name === 'first-contentful-paint') return true;
    }
    return false;
  }

  // The browser's own word for it. Buffered, so a paint that happened
  // before this ran still counts.
  try {
    new PerformanceObserver(function (list) {
      if (hasContentfulPaint(list.getEntries())) painted();
    }).observe({ type: 'paint', buffered: true });
  } catch (e) {}

  // The fallback, for a browser without paint timing. A body that has
  // children and a height has been laid out; two frames later it has been
  // drawn. An empty document — `about:blank` before the first page — never
  // gets there, which is the point: it has nothing to report.
  function poll() {
    if (reported) return;
    try {
      if (hasContentfulPaint(performance.getEntriesByType('paint'))) {
        return painted();
      }
    } catch (e) {}
    var body = document.body;
    if (body && body.children.length &&
        body.getBoundingClientRect().height > 0) {
      requestAnimationFrame(function () { requestAnimationFrame(painted); });
      return;
    }
    setTimeout(poll, 100);
  }
  poll();
})();
""";

/// When, after a page starts, the paint probe is sent again. Dense early,
/// where a page usually commits and paints, then sparse: past a few seconds
/// `onPageFinished` is the likelier way out.
const List<Duration> _paintProbeRetries = [
  Duration(milliseconds: 150),
  Duration(milliseconds: 400),
  Duration(milliseconds: 800),
  Duration(milliseconds: 1500),
  Duration(milliseconds: 2500),
  Duration(milliseconds: 4000),
];

void _applyPaintProbe(WebViewController controller) {
  controller.runJavaScript(_paintProbeScript).catchError((Object _) {});
}

/// Name of the channel the page posts tapped links to. Must match the script.
const String _bridgeChannel = 'LiveLookBridge';

/// Name of the channel the mirror posts its apparel links to.
///
/// Spelled by the site, not by this app: the page calls
/// `ShopLink.postMessage(...)`, so renaming this silently stops the four
/// apparel cards from opening anything.
const String _shopLinkChannel = 'ShopLink';

/// Reports what the user tapped, and — where the destination asks for it —
/// hands the link over so the app can open it as a full page.
///
/// The page is the only place these details exist. By the time a navigation
/// reaches the app, the card, its words and the heading above it are gone,
/// and on Android a scripted iframe is never reported at all.
const String _bridgeScript = r"""
(function () {
  // Before the install guard, so it runs on every injection and not only on
  // the first: a page restored from the back-forward cache comes back with
  // the bridge already installed, and — until this — with the sheet the tap
  // that left it put up.
  var stale = document.getElementById('livelook-cover');
  if (stale && stale.parentNode) stale.parentNode.removeChild(stale);

  if (window.__livelookBridge) return;
  if (typeof LiveLookBridge === 'undefined') return;
  if (!document.documentElement) return;
  window.__livelookBridge = true;

  // The page is not reloaded on the way back, it is restored, so the sheet
  // is still in the DOM and the timer set to lift it was frozen with the
  // page — it has the rest of its 2.5 seconds left to run, and only once the
  // page is visible again. This lifts it on the frame the page comes back.
  //
  // On the way out rather than on the way back would be earlier, but
  // `pagehide` can fire while the old page is still the one on screen, which
  // is the moment the sheet is there to cover.
  window.addEventListener('pageshow', uncover);

  var promoting = window.__livelookPromote === true;
  console.log('livelook: bridge installed on ' + location.href +
    (promoting ? ' (promoting)' : ''));

  function absolute(url) {
    if (!url || !/^(https?:)?\/\//i.test(url)) return null;
    try {
      return new URL(url, location.href).href;
    } catch (e) {
      return null;
    }
  }

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

  function uncover() {
    var sheet = document.getElementById('livelook-cover');
    if (sheet && sheet.parentNode) sheet.parentNode.removeChild(sheet);
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
    // under a sheet it cannot lift. Only for that case: a page that does
    // navigate is uncovered when it comes back, by the listener above,
    // because this timer is frozen for as long as the page is away.
    setTimeout(uncover, 2500);
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

  // ─── What the page is selling ──────────────────────────────────────
  // Read from the page's own structured data. Retailers publish it for search
  // engines, which makes it far steadier than anything the layout could be
  // scraped for.
  function firstImage(value) {
    if (!value) return null;
    if (typeof value === 'string') return absolute(value);
    if (Array.isArray(value)) {
      for (var i = 0; i < value.length; i++) {
        var found = firstImage(value[i]);
        if (found) return found;
      }
      return null;
    }
    if (typeof value === 'object') {
      return firstImage(value.url || value.contentUrl || value['@id']);
    }
    return null;
  }

  function findProductNode(node, depth) {
    if (!node || depth > 4) return null;
    if (Array.isArray(node)) {
      for (var i = 0; i < node.length; i++) {
        var found = findProductNode(node[i], depth + 1);
        if (found) return found;
      }
      return null;
    }
    if (typeof node !== 'object') return null;

    var type = node['@type'];
    var isProduct = type === 'Product' ||
      (Array.isArray(type) && type.indexOf('Product') >= 0);
    if (isProduct) return node;

    return findProductNode(node['@graph'] || node.mainEntity, depth + 1);
  }

  function productFromStructuredData() {
    var scripts = document.querySelectorAll(
      'script[type="application/ld+json"]');
    for (var i = 0; i < scripts.length; i++) {
      var node;
      try {
        node = findProductNode(JSON.parse(scripts[i].textContent), 0);
      } catch (e) {
        continue;
      }
      if (!node) continue;

      var image = firstImage(node.image);
      if (!image) continue;

      var offers = node.offers;
      if (Array.isArray(offers)) offers = offers[0];
      var brand = node.brand;
      if (brand && typeof brand === 'object') brand = brand.name;

      return {
        title: node.name || document.title || '',
        image: image,
        brand: typeof brand === 'string' ? brand : '',
        sku: node.sku || node.mpn || '',
        price: offers && offers.price != null ? String(offers.price) : '',
        currency: offers && offers.priceCurrency ? offers.priceCurrency : ''
      };
    }
    return null;
  }

  function metaContent(name) {
    var el = document.querySelector('meta[property="' + name + '"]') ||
      document.querySelector('meta[name="' + name + '"]');
    return el ? el.getAttribute('content') : null;
  }

  // Sites that publish no JSON-LD still tag their product pages for social
  // previews, and that is enough: a name and a picture.
  function productFromMeta() {
    var image = absolute(metaContent('og:image'));
    if (!image) return null;

    var type = metaContent('og:type') || '';
    var priced = metaContent('product:price:amount');
    var marked = document.querySelector('[itemtype*="schema.org/Product" i]');
    if (!/product/i.test(type) && !priced && !marked) return null;

    return {
      title: metaContent('og:title') || document.title || '',
      image: image,
      brand: metaContent('product:brand') || '',
      sku: metaContent('product:retailer_item_id') || '',
      price: priced || '',
      currency: metaContent('product:price:currency') || ''
    };
  }

  var lastProductKey = null;
  var lastProductUrl = null;

  function reportProduct() {
    var product = productFromStructuredData() || productFromMeta();
    var key = product ? product.image + '|' + location.href : '';

    // A retail page rewrites itself for minutes after it loads — a carousel
    // arrives, a script replaces the JSON-LD — and a scan that lands mid-way
    // finds nothing. On the page the offer was already made for, that is the
    // page still filling itself in, not the product going away. Only leaving
    // the page takes the offer with it.
    if (!product && lastProductKey && location.href === lastProductUrl) return;

    if (key === lastProductKey) return;
    lastProductKey = key;
    lastProductUrl = location.href;

    var payload = { type: 'product', url: location.href };
    if (product) {
      payload.title = product.title;
      payload.image = product.image;
      payload.brand = product.brand;
      payload.sku = product.sku;
      payload.price = product.price;
      payload.currency = product.currency;
      console.log('livelook: product ' + product.title);
    } else {
      console.log('livelook: no product on ' + location.href);
    }
    LiveLookBridge.postMessage(JSON.stringify(payload));
  }

  // Called again from the app on every injection, so a page that arrives
  // in pieces is looked at each time rather than only on its own schedule.
  window.__livelookScan = reportProduct;

  reportProduct();
  // Retail pages fill themselves in after the first paint, and a single-page
  // site swaps products without ever loading again.
  setInterval(reportProduct, 2000);

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
      .runJavaScript(
        'window.__livelookPromote = $promote;\n'
        '$_bridgeScript\n'
        // Installed already on a page the app is injecting into again: the
        // script returns at its own guard, so the scan is asked for here.
        'if (window.__livelookScan) window.__livelookScan();',
      )
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

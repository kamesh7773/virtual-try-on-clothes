import 'dart:async';
import 'dart:convert';

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
import '../models/web_purchase_options.dart';
import '../models/web_tap_report.dart';
import '../view_models/history_flow_view_model.dart';
import '../view_models/product_try_on_state.dart';
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

    // A checkout the page never answers would otherwise leave the preview
    // saying "adding" for good. The script gives up on its own well inside
    // this; this is for a script that was never heard from at all.
    final checkoutTimeout = useRef<Timer?>(null);
    useEffect(
      () =>
          () => checkoutTimeout.value?.cancel(),
      const [],
    );

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
        onOptions: tryOnViewModel.setOptions,
        onCheckoutDone: (cartUrl) {
          checkoutTimeout.value?.cancel();
          tryOnViewModel.dismissResult();
          // With no cart to open the item is in the cart all the same, and
          // the page is the place to find it from.
          if (cartUrl == null && context.mounted) {
            _showMessage(context, 'Added to cart.');
          }
        },
        onCheckoutFailed: (reason) {
          checkoutTimeout.value?.cancel();
          tryOnViewModel.checkoutFailed(reason);
          // The page is where the answer is — a prompt it put up, a notice
          // by the button — and the size the user chose is still chosen on
          // it. The picture would only hide that.
          tryOnViewModel.dismissResult();
          if (context.mounted) _showMessage(context, reason, isError: true);
        },
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

    // Asks the page to add the product, with the choices given by group
    // name, and waits for the bridge to say how it went — see
    // `_bridgeScript`'s checkout.
    void runCheckout(Map<String, String> choices) {
      _runCheckout(controller, choices);
      checkoutTimeout.value?.cancel();
      checkoutTimeout.value = Timer(_checkoutLimit, () {
        if (!context.mounted) return;
        if (ref.read(productTryOnViewModelProvider).checkoutStep !=
            CheckoutStep.adding) {
          return;
        }
        const reason = 'The page did not respond. Add to cart from the page.';
        tryOnViewModel.checkoutFailed(reason);
        tryOnViewModel.dismissResult();
        _showMessage(context, reason, isError: true);
      });
    }

    void startCheckout() {
      switch (tryOnViewModel.startCheckout()) {
        case CheckoutPlan.pick:
          // The preview asks for the open attribute; the pick comes back
          // through `onPicked` below.
          return;
        case CheckoutPlan.add:
          runCheckout(ref.read(productTryOnViewModelProvider).checkoutChoices);
        case CheckoutPlan.guide:
          // The page's controls could not be read, so the page itself is
          // the way to finish: close the picture, bring its options into
          // view, and say what to do there.
          tryOnViewModel.dismissResult();
          _guideToPurchase(controller);
          _showMessage(
            context,
            'Choose your options on the page, then tap Add To Cart.',
          );
      }
    }

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
          // asking to leave — not the page underneath it. A question open
          // over the try-on is one step further out again.
          final tryOnNow = ref.read(productTryOnViewModelProvider);
          if (tryOnNow.hasResult) {
            if (tryOnNow.checkoutStep == CheckoutStep.picking) {
              tryOnViewModel.cancelCheckout();
            } else {
              tryOnViewModel.dismissResult();
            }
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
                        canCheckout: tryOn.canCheckout,
                        step: tryOn.checkoutStep,
                        choosing: tryOn.choosing,
                        onCheckout: startCheckout,
                        onPicked: (label) {
                          // One attribute settled; the next open one is
                          // asked for, or the page is.
                          if (tryOnViewModel.choose(label) ==
                              CheckoutPlan.add) {
                            runCheckout(
                              ref
                                  .read(productTryOnViewModelProvider)
                                  .checkoutChoices,
                            );
                          }
                        },
                        onCancelPick: tryOnViewModel.cancelCheckout,
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
  required void Function(WebPurchaseOptions options) onOptions,
  // The cart the checkout is taking the user to, or null when the item went
  // in but the page showed no cart to open.
  required void Function(String? cartUrl) onCheckoutDone,
  required void Function(String reason) onCheckoutFailed,
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

        case WebOptionsMessage(:final options):
          onOptions(options);

        case WebCheckoutMessage(:final status, :final reason, :final cartUrl):
          if (kDebugMode) {
            debugPrint('${stamp()} checkout ${status.name} ${reason ?? ''}');
          }
          if (status != WebCheckoutStatus.added) {
            // A silence is a refusal too: a cart page with nothing in it
            // is the one outcome worse than saying the add did not work.
            onCheckoutFailed(
              reason ?? 'The page could not add this to the cart.',
            );
            return;
          }

          // The page's own cart link first, then the cart this app knows
          // for the site.
          final cart = cartUrl ?? WebDestinations.cartUrlFor(currentHost.value);
          onCheckoutDone(cart);
          if (cart == null) return;

          // Filed so the history reads "Checkout" against the product page,
          // not a cart appearing from nowhere.
          pendingTap.value = WebTapReport(
            promote: false,
            url: cart,
            trigger: VisitTrigger.element,
            label: 'Checkout',
            context: 'Try-on',
            sourceUrl: currentUrl,
          );
          pendingTapAt.value = DateTime.now();
          controller.loadRequest(Uri.parse(cart));

        case WebPaintedMessage(:final url):
          if (kDebugMode) debugPrint('${stamp()} painted → $url');
          // A paint reported by the page being left — its probe outlives it
          // until the next document commits — must not lift the cover off
          // the one still on its way. The host is what tells them apart in
          // the case that matters, the jump from the mirror to a retailer.
          if (url.host != currentHost.value) return;
          lift();
          // A page brought back from the cache paints but never finishes,
          // and a visit completed only on finish would sit in the history
          // as loading for good. Completed here as well; a finish that does
          // come later overwrites this with its own, longer time.
          controller.getTitle().then((title) {
            if (isMounted()) onVisitFinished(title);
          });

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
/// Installs itself once per document, and reports once per showing: a
/// document restored from the back-forward cache reports again on
/// `pageshow`, since going back is a navigation the app sees start and
/// finish but no paint of — the page was painted before it left.
///
/// Injected on every progress tick and URL change rather than on page
/// start, because on iOS page start fires while the previous document is
/// still the one scripts run in.
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

  // A page brought back from the back-forward cache is not loaded again,
  // it is shown again — already painted, with this probe already spent.
  // Going back is the one navigation where the cover has nothing to wait
  // for, so it is told so on the spot.
  window.addEventListener('pageshow', function (event) {
    if (!event.persisted) return;
    reported = false;
    painted();
  });

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

/// How long the preview waits for the page to answer a checkout before
/// giving up on it. The script gives up on its own inside thirty seconds;
/// this is for a script that was never installed to answer at all.
const Duration _checkoutLimit = Duration(seconds: 40);

/// [choices] is what to press on the page, by the page's own name for each
/// attribute row; the script matches names loosely and presses in the
/// page's order, whatever order these arrive in.
void _runCheckout(WebViewController controller, Map<String, String> choices) {
  controller
      .runJavaScript(
        'if (window.__livelookCheckout) '
        'window.__livelookCheckout(${jsonEncode(choices)});',
      )
      .catchError((Object _) {});
}

void _guideToPurchase(WebViewController controller) {
  controller
      .runJavaScript('if (window.__livelookGuide) window.__livelookGuide();')
      .catchError((Object _) {});
}

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

  // ─── What the page lets the user do about buying ───────────────────
  // Read from the page's controls rather than its data: a size row and an
  // add-to-cart button are what the user would press, and pressing them on
  // the user's behalf is what the checkout in the preview does. Everything
  // here is matched on what the controls say, not on how the site names
  // its classes — the words are the stable part.
  // What a size can look like, across the store: lettered (S, XXL, 2XL,
  // 1X, YM for youth), paired (S/M), shoe sizes with a width (10.5, 9 W,
  // 12 EE, 7 1/2), trouser sizes (32x30, 34W x 32L, W32 L30), bra sizes
  // (34B), hat sizes (7 1/4), children's (4T, 5Y), and one-size. Anything
  // longer than a dozen characters is a description, not a size.
  var SIZE_TOKEN = new RegExp(
    '^(' +
      'XXXS|XXS|XS|S|M|L|XL|XXL|XXXL|[2-6]XL|[1-4]X|Y(XS|S|M|L|XL)|' +
      '(XXS|XS|S|M|L|XL|XXL)\\s?[\\/-]\\s?(XS|S|M|L|XL|XXL|XXXL)|' +
      'OS|ONE SIZE|O\\/S|' +
      '\\d{1,2}(\\.\\d)?\\s?(W|M|D|N|B|C|E|EE|EEE|XW|WW|H|R|T|Y|K)?|' +
      '\\d{1,2}\\s\\d\\/\\d|' +
      '\\d{2}\\s?[xX\u00d7]\\s?\\d{2}|\\d{2}\\s?W\\s?[xX\u00d7]?\\s?\\d{2}\\s?L|W\\s?\\d{2}\\s?L\\s?\\d{2}|' +
      '\\d{2}[A-K]{1,3}' +
    ')$', 'i');
  var ADD_TO_CART = /^add to (cart|bag|basket)$/i;

  function visible(el) {
    var rect = el.getBoundingClientRect ? el.getBoundingClientRect() : null;
    return !!(rect && rect.width > 0 && rect.height > 0);
  }

  function isDisabled(el) {
    if (el.disabled) return true;
    if (el.getAttribute('aria-disabled') === 'true') return true;
    var parent = el.parentElement;
    var cls = (el.className || '') + ' ' + (parent && parent.className || '');
    if (/disabled|unavailable|out-?of-?stock|sold-?out|strike/i.test(cls)) {
      return true;
    }
    var style = window.getComputedStyle ? window.getComputedStyle(el) : null;
    var deco = style ? (style.textDecorationLine || style.textDecoration || '') : '';
    return /line-through/.test(deco);
  }

  function isSelected(el) {
    if (el.getAttribute('aria-pressed') === 'true') return true;
    if (el.getAttribute('aria-checked') === 'true') return true;
    if (el.getAttribute('aria-selected') === 'true') return true;
    if (el.getAttribute('aria-current') === 'true') return true;
    if (/(^|[\s_-])(selected|active|checked)([\s_-]|$)/i.test(el.className || '')) {
      return true;
    }
    var radio = el.querySelector ? el.querySelector('input[type="radio"]') : null;
    if (radio && radio.checked) return true;
    return !!(el.tagName === 'LABEL' && el.control && el.control.checked);
  }

  // The size controls are the buttons that say nothing but a size, and they
  // come as a row: the ancestor holding the most of them holds the row. Each
  // control is offered to its nearest three ancestors, the nearest winning
  // a tie, so a row of individually wrapped buttons is still one row.
  function sizeControls() {
    var candidates = document.querySelectorAll(
      'button, [role="radio"], [role="option"], label');
    var groups = new Map();
    for (var i = 0; i < candidates.length; i++) {
      var el = candidates[i];
      var text = words(el);
      if (!text || !SIZE_TOKEN.test(text) || !visible(el)) continue;
      var ancestor = el.parentElement;
      for (var depth = 0; ancestor && depth < 3; depth++) {
        var list = groups.get(ancestor);
        if (!list) groups.set(ancestor, list = []);
        if (list.indexOf(el) < 0) list.push(el);
        ancestor = ancestor.parentElement;
      }
    }
    var best = null;
    groups.forEach(function (list, ancestor) {
      if (!best || list.length > best.list.length ||
          (list.length === best.list.length && best.ancestor !== ancestor &&
           best.ancestor.contains(ancestor))) {
        best = { ancestor: ancestor, list: list };
      }
    });
    return best && best.list.length >= 2 ? best.list : [];
  }

  // The text an element carries itself, not through its children: the
  // "Color:" of a "Color: Red" row, without the "Red".
  function ownText(el) {
    var text = '';
    for (var i = 0; i < el.childNodes.length; i++) {
      if (el.childNodes[i].nodeType === 3) text += el.childNodes[i].nodeValue;
    }
    return text.replace(/\s+/g, ' ').trim();
  }

  function nameOf(el) {
    var name = el.getAttribute('aria-label') || el.getAttribute('title') ||
      el.getAttribute('data-color') || el.getAttribute('data-color-name') || '';
    if (!name) {
      var img = el.tagName === 'IMG' ? el : (el.querySelector ? el.querySelector('img') : null);
      if (img) name = img.getAttribute('alt') || img.getAttribute('title') || '';
    }
    if (!name) name = words(el);
    return name.replace(/\s+/g, ' ').trim();
  }

  function imageOf(el) {
    var img = el.tagName === 'IMG' ? el : (el.querySelector ? el.querySelector('img') : null);
    return img ? (img.currentSrc || img.src || '') : '';
  }

  function plain(name) {
    return String(name).toLowerCase().replace(/[^a-z0-9]/g, '');
  }

  function sameName(a, b) {
    var x = plain(a);
    var y = plain(b);
    return x && y && (x === y || x.indexOf(y) >= 0 || y.indexOf(x) >= 0);
  }

  // The entry in `list` called `label`: the one spelt the same first, and
  // only failing that one that contains it — "L" must not find "XL".
  function named(list, label) {
    for (var i = 0; i < list.length; i++) {
      if (plain(list[i].label) === plain(label)) return list[i];
    }
    for (var j = 0; j < list.length; j++) {
      if (sameName(list[j].label, label)) return list[j];
    }
    return null;
  }

  // What a store heads an attribute row with. A heading ending in a colon
  // is taken whatever it says; these are taken without one.
  var GROUP_NAME = new RegExp('^(colou?r|size|inseam|width|length|waist|rise|fit|style|' +
    'hand|loft|flex|shaft|lie|bounce|grind|scent|flavou?r|band|cup|pattern|finish|' +
    'material|capacity|volume|weight|dimensions?|configuration|model)$', 'i');
  // Things beside a row that are not one of its values: the size chart
  // link, the fit finder, the prompt to choose.
  var NOT_A_VALUE = /chart|guide|what'?s my|find (my|your)|select|please|choose|view|see all|shop|learn|more$/i;

  // What `el` heads, as { name, chosen, known }: "Color" from a "Color:"
  // span, with "Tuxedo" as chosen when the span says "Color: Tuxedo" —
  // or null when it heads nothing. `known` is whether the name is one a
  // store is known to sell by, as against a bare heading with a colon.
  function headingOf(el) {
    var own = ownText(el);
    if (!own || own.length > 70 || !visible(el)) return null;
    var name, chosen = '';
    var split = own.match(/^([A-Za-z][A-Za-z\/&' -]{0,28}?)\s*:\s*(.*)$/);
    if (split) {
      name = split[1];
      chosen = split[2].trim();
    } else if (/^[A-Za-z][A-Za-z\/&' -]{0,28}$/.test(own)) {
      name = own;
    } else {
      return null;
    }
    name = name.replace(/^(select|choose|pick)\s+(an?|your)?\s*/i, '').trim();
    if (!name || SIZE_TOKEN.test(name)) return null;
    var known = GROUP_NAME.test(name);
    if (!split && !known) return null;
    // A heading is not itself something to press.
    if (el.closest('button, a, [role="button"], [role="radio"], [role="option"]')) return null;
    if (el.tagName === 'LABEL' && el.control) return null;
    return { name: name, chosen: chosen, known: known };
  }

  function follows(a, b) {
    return !!(a.compareDocumentPosition(b) & Node.DOCUMENT_POSITION_FOLLOWING);
  }

  // The values offered under `heading`: small clickable things after it
  // and before the next heading, each with a name — its text, an alt, a
  // title, an aria-label. Looked for under the heading's nearest ancestors
  // in turn, the first to hold a row of two or more winning.
  function valuesUnder(heading, head, headings) {
    var name = head.name;
    // What the heading row says is chosen — "Color: Tuxedo", "Size: L" —
    // for pages that mark the value itself no other way. In the heading's
    // own text, or failing that in the row it sits in.
    var chosen = head.chosen;
    if (!chosen) {
      var row = words(heading.parentElement || heading);
      var own = ownText(heading);
      var at = row.toLowerCase().indexOf(own.toLowerCase());
      chosen = at < 0 ? '' : row.slice(at + own.length).trim();
    }
    if (chosen.length > 40 || NOT_A_VALUE.test(chosen)) chosen = '';
    // A row under a heading nobody knows — "Ships to:" — has to look like
    // options to count: short labels, not sentences.
    var longest = head.known ? 60 : 24;

    var ancestor = heading.parentElement;
    for (var depth = 0; ancestor && depth < 5; depth++) {
      var found = [];
      var nodes = ancestor.querySelectorAll(
        'button, [role="radio"], [role="option"], [role="button"], label, a, li, img');
      for (var j = 0; j < nodes.length; j++) {
        var node = nodes[j];
        if (!visible(node) || !follows(heading, node) || node.contains(heading)) continue;
        var cut = false;
        for (var h = 0; h < headings.length; h++) {
          var other = headings[h];
          if (other !== heading && ancestor.contains(other) && follows(heading, other) &&
              follows(other, node) && !other.contains(node)) { cut = true; break; }
        }
        if (cut) continue;
        var rect = node.getBoundingClientRect();
        if (rect.width < 16 || rect.width > 220 || rect.height < 12 || rect.height > 220) continue;
        var clickable = node.tagName === 'IMG'
          ? (node.closest('button, a, [role="radio"], [role="option"], [role="button"], label, li') || node.parentElement)
          : node;
        var label = nameOf(clickable) || nameOf(node);
        if (!label || label.length > longest || NOT_A_VALUE.test(label) || plain(label) === plain(name)) continue;
        var duplicate = false;
        for (var k = 0; k < found.length; k++) {
          if (found[k].el === clickable || found[k].el.contains(clickable) || clickable.contains(found[k].el) ||
              plain(found[k].label) === plain(label)) { duplicate = true; break; }
        }
        if (duplicate) continue;
        found.push({
          el: clickable,
          label: label,
          image: imageOf(node),
          available: !isDisabled(clickable),
          selected: isSelected(clickable) || (clickable.parentElement && isSelected(clickable.parentElement)) ||
            (chosen ? plain(chosen) === plain(label) : false)
        });
      }
      if (found.length >= 2) return found;
      ancestor = ancestor.parentElement;
    }
    return [];
  }

  // How far `el` is from the Add To Cart button: the number of steps up
  // from the button to an ancestor holding both. A "Color:" row in a
  // carousel of other products is further than the product's own.
  function distanceFromCart(el) {
    var add = addToCartControl();
    var node = add;
    for (var depth = 0; node; depth++) {
      if (node.contains(el)) return depth;
      node = node.parentElement;
    }
    return 999;
  }

  // Every attribute the page wants chosen, in the page's order: each a
  // heading — "Color", "Size", "Inseam", whatever the store sells by — and
  // the values under it, as [{ name, values: [{ el, label, image,
  // available, selected }] }]. Read afresh each time: choosing a colour
  // can redraw the sizes under it.
  function optionGroups() {
    var candidates = document.querySelectorAll(
      'label, legend, span, div, p, h2, h3, h4, h5, dt, strong, b');
    var headings = [];
    var heads = [];
    for (var i = 0; i < candidates.length; i++) {
      var head = headingOf(candidates[i]);
      if (!head) continue;
      headings.push(candidates[i]);
      heads.push(head);
    }
    var groups = [];
    for (var j = 0; j < headings.length; j++) {
      var values = valuesUnder(headings[j], heads[j], headings);
      if (!values.length) continue;
      var group = { name: heads[j].name, values: values, distance: distanceFromCart(headings[j]) };
      // Two rows under one name are two products; keep the one the
      // Add To Cart button is for.
      var taken = -1;
      for (var k = 0; k < groups.length; k++) {
        if (plain(groups[k].name) === plain(group.name)) { taken = k; break; }
      }
      if (taken < 0) groups.push(group);
      else if (group.distance < groups[taken].distance) groups[taken] = group;
    }
    // A size row with no heading over it is still a size row.
    var hasSize = groups.some(function (g) { return /^size/i.test(g.name); });
    if (!hasSize) {
      var sizes = sizeControls();
      if (sizes.length) {
        groups.push({
          name: 'Size',
          distance: 0,
          values: sizes.map(function (el) {
            return { el: el, label: words(el), image: '', available: !isDisabled(el), selected: isSelected(el) };
          })
        });
      }
    }
    return groups;
  }

  function groupNamed(name) {
    var groups = optionGroups();
    for (var i = 0; i < groups.length; i++) {
      if (sameName(groups[i].name, name)) return groups[i];
    }
    return null;
  }

  function addToCartControl() {
    var candidates = document.querySelectorAll(
      'button, [role="button"], input[type="submit"]');
    for (var i = 0; i < candidates.length; i++) {
      var el = candidates[i];
      var text = words(el) || el.value || el.getAttribute('aria-label') || '';
      if (ADD_TO_CART.test(text.trim()) && visible(el)) return el;
    }
    return null;
  }

  function cartLink() {
    var link = document.querySelector('a[href*="OrderItemDisplay"]') ||
      document.querySelector(
        'a[href*="/cart" i], a[href*="ShoppingCart" i], a[aria-label*="cart" i]');
    return link && link.href ? link.href : null;
  }

  function cartCount() {
    var link = document.querySelector(
      'a[href*="OrderItemDisplay"], a[href*="/cart" i], a[aria-label*="cart" i]');
    if (!link) return null;
    var match = words(link).match(/\d+/);
    return match ? parseInt(match[0], 10) : null;
  }

  function readOptions() {
    return {
      type: 'options',
      url: location.href,
      groups: optionGroups().map(function (group) {
        return {
          name: group.name,
          values: group.values.map(function (v) {
            return { label: v.label, image: v.image, available: v.available, selected: !!v.selected };
          })
        };
      }),
      addToCart: !!addToCartControl(),
      cartUrl: cartLink()
    };
  }

  var lastOptionsKey = null;

  function reportOptions() {
    // Only a product page has anything to buy on it.
    if (!lastProductKey) return;
    var payload = readOptions();
    var key = JSON.stringify(payload);
    if (key === lastOptionsKey) return;
    lastOptionsKey = key;
    var summary = payload.groups.map(function (group) {
      var chosen = null;
      for (var v = 0; v < group.values.length; v++) {
        if (group.values[v].selected) chosen = group.values[v].label;
      }
      return group.name + ' ' + group.values.length + (chosen ? ' (' + chosen + ')' : '');
    });
    console.log('livelook: options ' + (summary.length ? summary.join(', ') : 'none') +
      '; add to cart ' + (payload.addToCart ? 'found' : 'missing'));
    LiveLookBridge.postMessage(key);
  }

  function errorText() {
    var alerts = document.querySelectorAll('[role="alert"], [class*="error" i]');
    for (var i = 0; i < alerts.length; i++) {
      if (!visible(alerts[i])) continue;
      var text = words(alerts[i]);
      if (text && /size|select|unavailable|out of stock|sold out|try again/i.test(text)) {
        return text.slice(0, 160);
      }
    }
    return null;
  }

  function describe(el) {
    if (!el) return 'nothing';
    var cls = String(el.className || '').replace(/\s+/g, ' ').trim().slice(0, 80);
    return el.tagName.toLowerCase() + (cls ? '.' + cls : '') +
      ' "' + words(el).slice(0, 40) + '"' +
      (el.getAttribute('aria-pressed') ? ' pressed=' + el.getAttribute('aria-pressed') : '') +
      (el.getAttribute('aria-checked') ? ' checked=' + el.getAttribute('aria-checked') : '') +
      (el.disabled ? ' disabled' : '');
  }

  // A tap as the page would see one from a finger: the pointer and mouse
  // events first, then the click. A bare `click()` is enough for a plain
  // button, but a component that arms itself on pointerdown ignores it.
  function press(el) {
    var control = el.tagName === 'LABEL' && el.control ? el.control : el;
    try { control.focus(); } catch (e) {}
    var rect = control.getBoundingClientRect();
    var x = rect.left + rect.width / 2;
    var y = rect.top + rect.height / 2;
    function fire(type, Ctor, extra) {
      try {
        var init = { bubbles: true, cancelable: true, composed: true,
          clientX: x, clientY: y, screenX: x, screenY: y, view: window };
        for (var key in extra) init[key] = extra[key];
        control.dispatchEvent(new Ctor(type, init));
      } catch (e) {}
    }
    var touch = { pointerId: 1, pointerType: 'touch', isPrimary: true };
    if (window.PointerEvent) fire('pointerdown', PointerEvent, touch);
    fire('mousedown', MouseEvent, { button: 0, buttons: 1 });
    if (window.PointerEvent) fire('pointerup', PointerEvent, touch);
    fire('mouseup', MouseEvent, { button: 0 });
    try { control.click(); } catch (e) { fire('click', MouseEvent, { button: 0 }); }
    if (control.tagName === 'INPUT' &&
        (control.type === 'radio' || control.type === 'checkbox') && !control.checked) {
      control.checked = true;
      fire('input', Event, {});
      fire('change', Event, {});
    }
  }

  // The site's own verdict, where it gives one. This retailer logs its
  // add-to-cart result to the console as JSON with a `callOrigin` and a
  // `success` — far surer than watching the page for a badge to change.
  var addToCartVerdict = null;
  function watchVerdicts(name) {
    var original = console[name];
    if (typeof original !== 'function') return;
    console[name] = function () {
      for (var i = 0; i < arguments.length; i++) {
        var arg = arguments[i];
        var text = typeof arg === 'string' ? arg : null;
        if (!text && arg && typeof arg === 'object' && arg.message) {
          text = Array.isArray(arg.message) ? arg.message.join(' ') : String(arg.message);
        }
        if (!text || text.indexOf('callOrigin') < 0) continue;
        // The verdict arrives as JSON inside the site's logger's own JSON,
        // quotes escaped, so it is read with a pattern rather than parsed.
        var success = /\\?"success\\?"\s*:\s*\\?"?(true|false)/i.exec(text);
        if (!success) continue;
        var error = /\\?"errorMessage\\?"\s*:\s*\\?"([^"\\]*)/i.exec(text);
        addToCartVerdict = {
          success: success[1].toLowerCase() === 'true',
          error: error && error[1] && error[1] !== 'none' ? error[1] : ''
        };
        console.log('livelook: site verdict ' + (addToCartVerdict.success ? 'added' : 'refused: ' + addToCartVerdict.error));
      }
      return original.apply(console, arguments);
    };
  }
  watchVerdicts('log');
  watchVerdicts('info');
  watchVerdicts('warn');
  watchVerdicts('error');

  // What the page asks its servers while a checkout is under way. Kept
  // only during one, and only to be read back when it fails: the answer
  // to "why did nothing happen" is almost always in here.
  var netLog = null;
  function noteRequest(method, url, status, ms) {
    if (!netLog) return;
    var path = String(url).replace(/^https?:\/\/[^\/]+/, '').slice(0, 120);
    netLog.push(method + ' ' + path + ' → ' + status + ' (' + ms + 'ms)');
  }
  if (window.fetch && !window.__livelookFetchHooked) {
    window.__livelookFetchHooked = true;
    var nativeFetch = window.fetch;
    window.fetch = function (input, init) {
      var url = typeof input === 'string' ? input : (input && input.url) || '';
      var method = (init && init.method) || (input && input.method) || 'GET';
      var at = Date.now();
      return nativeFetch.apply(this, arguments).then(function (response) {
        noteRequest(method, url, response.status, Date.now() - at);
        return response;
      }, function (error) {
        noteRequest(method, url, 'error ' + (error && error.message), Date.now() - at);
        throw error;
      });
    };
  }
  if (window.XMLHttpRequest && !window.__livelookXhrHooked) {
    window.__livelookXhrHooked = true;
    var nativeOpen = XMLHttpRequest.prototype.open;
    XMLHttpRequest.prototype.open = function (method, url) {
      var at = Date.now();
      var xhr = this;
      xhr.addEventListener('loadend', function () {
        noteRequest(method, url, xhr.status || 'no status', Date.now() - at);
      });
      return nativeOpen.apply(this, arguments);
    };
  }

  // Anything the page has put up over itself, which the preview hides.
  function dialogsNow() {
    var nodes = document.querySelectorAll(
      '[role="dialog"], [aria-modal="true"], [class*="modal" i], [class*="drawer" i], ' +
      '[class*="flyout" i], [class*="toast" i], [role="alert"], [aria-live]');
    var seen = [];
    for (var i = 0; i < nodes.length; i++) {
      if (!visible(nodes[i])) continue;
      var text = words(nodes[i]).slice(0, 160);
      if (text && seen.indexOf(text) < 0) seen.push(text);
    }
    return seen;
  }

  // The cart as the store's own API has it. Same-origin and sent by the
  // page itself on every cart view, so asking again costs nothing. A store
  // with no such API answers nothing, and the check is simply not made.
  function cartItems() {
    if (!/dickssportinggoods\.com$/i.test(location.hostname)) return Promise.resolve(null);
    return fetch('/api/v2/carts', { credentials: 'include' }).then(function (response) {
      if (response.status === 400 || response.status === 404) return 0;
      if (!response.ok) return null;
      return response.json().then(function (json) {
        console.log('livelook: cart api ' + response.status + ' ' + JSON.stringify(json).slice(0, 300));
        var found = null;
        (function walk(node, depth) {
          if (found !== null || !node || depth > 4 || typeof node !== 'object') return;
          for (var key in node) {
            var value = node[key];
            if (Array.isArray(value) && /item/i.test(key)) { found = value.length; return; }
          }
          for (var key2 in node) walk(node[key2], depth + 1);
        })(json, 0);
        return found === null ? 1 : found;
      });
    }).catch(function () { return null; });
  }

  // The part of the page the buying happens in: the smallest ancestor of
  // the Add To Cart button that also holds the size row (or the swatches).
  // A refusal — "Please Select Color" — is written into it, in words, and
  // reading it before and after the press is what catches those words
  // whatever the page calls the box they sit in.
  function purchasePanel() {
    var add = addToCartControl();
    var groups = optionGroups();
    var mark = groups.length ? groups[0].values[0].el : null;
    var node = add;
    for (var depth = 0; node && depth < 10; depth++) {
      if (!mark || node.contains(mark)) return node;
      node = node.parentElement;
    }
    return add ? add.parentElement : document.body;
  }

  function panelLines(panel) {
    return panel ? words(panel).split(/\s{2,}|\n/) : [];
  }

  function newRefusal(before, after) {
    for (var i = 0; i < after.length; i++) {
      var line = after[i].trim();
      if (!line || line.length > 140 || before.indexOf(after[i]) >= 0) continue;
      if (/please|select|required|choose|unavailable|out of stock|sold out|error|try again/i.test(line)) {
        return line;
      }
    }
    return null;
  }

  // Adds the product to the cart the way the user would: each attribute's
  // button in turn, then Add to Cart, then a watch for the answer — the
  // site's own logged verdict, its cart API, an error appearing, or the
  // cart badge changing. `choices` is { "Color": "Tuxedo", "Size": "L",
  // "Inseam": "32" }, by the page's own names for its rows; rows it does
  // not name are pressed in the page's order regardless of the order here.
  // Answers over the bridge once, with `added`, or `failed` and a reason.
  // Never `timeout` into the cart: a cart page with nothing in it is the
  // one outcome worse than a refusal.
  window.__livelookCheckout = function (choices) {
    var answered = false;
    function answer(status, reason) {
      if (answered) return;
      answered = true;
      netLog = null;
      console.log('livelook: checkout ' + status + (reason ? ' — ' + reason : ''));
      LiveLookBridge.postMessage(JSON.stringify({
        type: 'checkout',
        status: status,
        reason: reason || '',
        cartUrl: cartLink()
      }));
    }

    addToCartVerdict = null;
    var itemsBefore = null;
    cartItems().then(function (count) { itemsBefore = count; });
    var badgeBefore = cartCount();
    var started = Date.now();

    // The choices to make on the page, in the order the page wants them.
    // Each is looked up afresh at every step: choosing a colour can
    // redraw the size row, and a node held from before is then nobody's.
    var steps = [];
    var groups = optionGroups();
    var wanted = choices && typeof choices === 'object' ? choices : {};
    for (var g = 0; g < groups.length; g++) {
      var label = null;
      for (var key in wanted) {
        if (sameName(key, groups[g].name) && wanted[key]) { label = String(wanted[key]); break; }
      }
      if (label) steps.push({ kind: groups[g].name, label: label, wait: 2500 });
    }

    function choose(step, done) {
      function current() {
        var group = groupNamed(step.kind);
        return group ? named(group.values, step.label) : null;
      }
      var target = current();
      if (!target) return answer('failed', step.kind + ' ' + step.label + ' is no longer offered on the page.');
      if (isDisabled(target.el)) return answer('failed', step.kind + ' ' + step.label + ' is out of stock.');
      if (target.selected) {
        console.log('livelook: ' + step.kind.toLowerCase() + ' already chosen: ' + describe(target.el));
        return done();
      }
      console.log('livelook: pressing ' + step.kind.toLowerCase() + ' ' + describe(target.el));
      press(target.el);
      var from = Date.now();
      (function until() {
        var now = current();
        var taken = !!(now && now.selected);
        if (!taken && Date.now() - from < step.wait) return setTimeout(until, 150);
        console.log('livelook: ' + step.kind.toLowerCase() + ' ' + (taken ? 'taken' : 'not marked selected') +
          ' after ' + (Date.now() - from) + 'ms: ' + describe(now ? now.el : null));
        done();
      })();
    }

    (function next(index) {
      if (index < steps.length) return choose(steps[index], function () { next(index + 1); });
      addToCart();
    })(0);

    function addToCart() {

      // The page checks stock for the size before it will sell it, and
      // disables Add To Cart while it does. Press only once the button has
      // been enabled for a few readings in a row, or five seconds have gone.
      var settled = 0;
      var settleFrom = Date.now();
      (function untilSettled() {
        var add = addToCartControl();
        settled = add && !isDisabled(add) ? settled + 1 : 0;
        if (settled < 3 && Date.now() - settleFrom < 5000) return setTimeout(untilSettled, 200);

        add = addToCartControl();
        if (!add) return answer('failed', 'The page has no Add To Cart button right now.');
        if (isDisabled(add)) return answer('failed', 'Add To Cart is not available for this selection.');
        var errorBefore = errorText();
        var dialogsBefore = dialogsNow();
        var panel = purchasePanel();
        var panelBefore = panelLines(panel);
        netLog = [];
        console.log('livelook: pressing ' + describe(add) + ' after ' + (Date.now() - started) + 'ms');
        press(add);
        var pressedAt = Date.now();
        setTimeout(function () {
          if (answered) return;
          var fresh = dialogsNow().filter(function (t) { return dialogsBefore.indexOf(t) < 0; });
          console.log('livelook: 2s after press — ' + netLog.length + ' requests' +
            (fresh.length ? '; new on screen: ' + JSON.stringify(fresh) : '; nothing new on screen'));
        }, 2000);

        var checking = false;
        (function watch() {
          if (addToCartVerdict) {
            if (addToCartVerdict.success) return answer('added');
            return answer('failed', addToCartVerdict.error || 'The page could not add this to the cart.');
          }
          var error = errorText();
          if (error && error !== errorBefore) return answer('failed', error);
          var refusal = newRefusal(panelBefore, panelLines(panel));
          if (refusal) return answer('failed', refusal);

          var badge = cartCount();
          if (badge !== null && (badgeBefore === null ? badge > 0 : badge > badgeBefore)) {
            return answer('added');
          }
          var dialog = document.querySelector('[role="dialog"]');
          if (dialog && visible(dialog) && /added to (your )?(cart|bag)/i.test(words(dialog))) {
            return answer('added');
          }

          var elapsed = Date.now() - pressedAt;
          // Every second or so, ask the store itself.
          if (!checking && elapsed > 1200 && Math.floor(elapsed / 1000) !== Math.floor((elapsed - 250) / 1000)) {
            checking = true;
            cartItems().then(function (count) {
              checking = false;
              if (answered || count === null) return;
              if (itemsBefore === null ? count > 0 : count > itemsBefore) answer('added');
            });
          }
          // A disabled button is the page still working on it; give it
          // time. One that has come back with nothing to show is not.
          var button = addToCartControl();
          var busy = button && isDisabled(button);
          if ((elapsed > 12000 && !busy) || elapsed > 30000) {
            console.log('livelook: checkout gave up after ' + elapsed + 'ms; add button now ' + describe(button));
            console.log('livelook: requests since press: ' + (netLog.length ? '\n  ' + netLog.join('\n  ') : 'none'));
            var fresh = dialogsNow().filter(function (t) { return dialogsBefore.indexOf(t) < 0; });
            console.log('livelook: on screen now: ' + (fresh.length ? JSON.stringify(fresh) : 'nothing new'));
            netLog = null;
            return answer('failed', 'The page did not confirm the item was added. Try Add To Cart on the page.');
          }
          setTimeout(watch, 250);
        })();
      })();
    }
  };

  // For a page whose controls could not be read: bring the buying part of
  // it into view so the user can finish there.
  window.__livelookGuide = function () {
    var groups = optionGroups();
    var target = groups.length ? groups[0].values[0].el : addToCartControl();
    if (target && target.scrollIntoView) {
      target.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }
  };

  // Called again from the app on every injection, so a page that arrives
  // in pieces is looked at each time rather than only on its own schedule.
  window.__livelookScan = function () {
    reportProduct();
    reportOptions();
  };

  window.__livelookScan();
  // Retail pages fill themselves in after the first paint, and a single-page
  // site swaps products without ever loading again.
  setInterval(window.__livelookScan, 2000);

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

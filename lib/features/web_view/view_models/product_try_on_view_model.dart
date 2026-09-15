import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/web_product.dart';
import '../models/web_purchase_options.dart';
import '../repositories/try_on_repository.dart';
import 'product_try_on_state.dart';

part 'product_try_on_view_model.g.dart';

/// What the browser should do when the user asks to check out from the
/// preview. Decided here, from what the page has said about itself; carried
/// out by the browser, which is the only thing that can drive the page.
enum CheckoutPlan {
  /// Ask the user for one of the page's attributes first — the one in
  /// `state.choosing`. The page offers several values and neither it nor
  /// its address has settled on one.
  pick,

  /// Press add-to-cart now: every attribute has an answer.
  add,

  /// The page's controls could not be read. Close the preview and hand the
  /// user the page to finish on.
  guide,
}

/// The try-on offer shown over a product page, and the request behind it.
///
/// Scoped to the browser screen: leaving the browser should forget the
/// product, not carry it into the next session.
@riverpod
class ProductTryOnViewModel extends _$ProductTryOnViewModel {
  @override
  ProductTryOnState build() => const ProductTryOnState();

  TryOnRepository get _repo => ref.read(tryOnRepositoryProvider);

  /// Called as the page reports what it is showing. Null means the page is
  /// not a product page any more.
  void setProduct(WebProduct? product) {
    if (product == state.product) return;
    state = product == null
        ? const ProductTryOnState()
        : ProductTryOnState(
            product: product,
            category: TryOnRepository.categoryFor(product),
          );
  }

  void dismissError() => state = state.copyWith(clearError: true);

  /// Closes the try-on, leaving the user on the page they were reading. Any
  /// checkout half-started from it goes with it.
  void dismissResult() =>
      state = state.copyWith(clearResult: true, clearCheckout: true);

  /// Called as the page reports its buying controls. Ignored for a page
  /// other than the product's own: the report can arrive from the page
  /// being left, after the next one's product has been set.
  void setOptions(WebPurchaseOptions options) {
    final product = state.product;
    if (product == null || options.pageUrl != product.pageUrl) return;
    if (options == state.options) return;
    state = state.copyWith(options: options);
  }

  /// The user asked to check out from the preview.
  ///
  /// Whatever the page has settled already — a size it shows selected, the
  /// colour its address names — is taken as given; the first attribute
  /// left open is asked for, in the page's own order, since a colour can
  /// redraw the sizes under it.
  CheckoutPlan startCheckout() {
    final options = state.options;
    if (options == null || !options.canAddToCart) return CheckoutPlan.guide;
    return _advance(options, options.settledChoices);
  }

  /// The user chose [label] for the group being asked about. What comes
  /// next is the next open attribute, or the cart.
  CheckoutPlan choose(String label) {
    final options = state.options;
    final group = state.pickingGroup;
    if (options == null || group == null) return CheckoutPlan.guide;
    return _advance(options, {...state.checkoutChoices, group: label});
  }

  CheckoutPlan _advance(
    WebPurchaseOptions options,
    Map<String, String> choices,
  ) {
    final next = options.nextToChoose(choices);
    if (next != null) {
      state = state.copyWith(
        checkoutStep: CheckoutStep.picking,
        pickingGroup: next.name,
        checkoutChoices: Map.unmodifiable(choices),
      );
      return CheckoutPlan.pick;
    }
    state = state.copyWith(
      checkoutStep: CheckoutStep.adding,
      checkoutChoices: Map.unmodifiable(choices),
    );
    return CheckoutPlan.add;
  }

  /// Back from a question to the picture, nothing sent.
  void cancelCheckout() => state = state.copyWith(clearCheckout: true);

  /// The page refused, or never answered.
  void checkoutFailed(String reason) =>
      state = state.copyWith(clearCheckout: true, error: reason);

  /// Asks the service to try the product on.
  ///
  /// The answer is an image, left in `state.resultUrl` for the view to show
  /// over the page. On failure the reason is left in `state.error` instead.
  Future<void> requestTryOn() async {
    final product = state.product;
    if (product == null || state.isLoading) return;

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearResult: true,
    );
    final response = await _repo.requestTryOn(product);

    // The browser can be gone by the time the service answers.
    if (!ref.mounted) return;

    if (response.isSuccess && response.data != null) {
      state = state.copyWith(isLoading: false, resultUrl: response.data!.url);
      return;
    }

    state = state.copyWith(
      isLoading: false,
      error: response.error ?? 'Try-on failed',
    );
  }
}

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
  /// Ask the user for a colour first; the page offers several and neither
  /// it nor its address has settled on one.
  pickColor,

  /// Ask the user for a size first; the page has a size row and nothing
  /// picked on it.
  pickSize,

  /// Press add-to-cart now — no sizes to choose, or one already chosen.
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
  /// Colour before size: the page will not sell without both, and the
  /// colour is usually already settled — by the page, or by the address the
  /// product shot was taken from — so it rarely has to be asked for.
  CheckoutPlan startCheckout() {
    final options = state.options;
    if (options == null || !options.canAddToCart) return CheckoutPlan.guide;

    if (options.needsColor) {
      state = state.copyWith(checkoutStep: CheckoutStep.pickingColor);
      return CheckoutPlan.pickColor;
    }
    return _withColor(options, options.resolvedColor?.label);
  }

  /// The user picked a colour in the preview. What comes next is the size
  /// question, or the cart.
  CheckoutPlan chooseColor(String label) {
    final options = state.options;
    if (options == null) return CheckoutPlan.guide;
    return _withColor(options, label);
  }

  CheckoutPlan _withColor(WebPurchaseOptions options, String? color) {
    if (options.needsSize) {
      state = state.copyWith(
        checkoutStep: CheckoutStep.pickingSize,
        checkoutColor: color,
      );
      return CheckoutPlan.pickSize;
    }

    state = state.copyWith(
      checkoutStep: CheckoutStep.adding,
      checkoutColor: color,
      checkoutSize: options.selectedSize?.label,
    );
    return CheckoutPlan.add;
  }

  /// The user picked a size in the preview; the page is about to be asked.
  void chooseSize(String label) {
    state = state.copyWith(
      checkoutStep: CheckoutStep.adding,
      checkoutSize: label,
    );
  }

  /// Back from the size row to the picture, nothing sent.
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

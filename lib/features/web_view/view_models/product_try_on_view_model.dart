import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/web_product.dart';
import '../repositories/try_on_repository.dart';
import 'product_try_on_state.dart';

part 'product_try_on_view_model.g.dart';

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

  /// Closes the try-on, leaving the user on the page they were reading.
  void dismissResult() => state = state.copyWith(clearResult: true);

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

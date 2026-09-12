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

  /// Asks for a page to open, and returns its URL.
  ///
  /// Returns null on failure, with the reason left in `state.error` for the
  /// overlay to show.
  Future<String?> requestTryOnUrl() async {
    final product = state.product;
    if (product == null || state.isLoading) return null;

    state = state.copyWith(isLoading: true, clearError: true);
    final response = await _repo.requestTryOn(product);

    // The browser can be gone by the time the service answers.
    if (!ref.mounted) return null;

    if (response.isSuccess && response.data != null) {
      state = state.copyWith(isLoading: false);
      return response.data!.url;
    }

    state = state.copyWith(
      isLoading: false,
      error: response.error ?? 'Try-on failed',
    );
    return null;
  }
}

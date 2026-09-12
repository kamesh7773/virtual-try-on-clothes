import 'package:flutter/foundation.dart';

import '../models/try_on_category.dart';
import '../models/web_product.dart';

@immutable
class ProductTryOnState {
  /// What the page in front of the user is selling, if anything.
  final WebProduct? product;

  /// Which of the service's four categories [product] would be tried on as.
  /// Null with no product.
  final TryOnCategory? category;

  /// True while the try-on service is being asked for a link.
  final bool isLoading;

  final String? error;

  const ProductTryOnState({
    this.product,
    this.category,
    this.isLoading = false,
    this.error,
  });

  bool get hasProduct => product != null;

  /// The overlay is worth showing only with both a product and the category
  /// it would be sent as.
  bool get canTryOn => product != null && category != null;

  ProductTryOnState copyWith({
    WebProduct? product,
    TryOnCategory? category,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) => ProductTryOnState(
    product: product ?? this.product,
    category: category ?? this.category,
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductTryOnState &&
          other.product == product &&
          other.category == category &&
          other.isLoading == isLoading &&
          other.error == error;

  @override
  int get hashCode => Object.hash(product, category, isLoading, error);
}

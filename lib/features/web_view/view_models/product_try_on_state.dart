import 'package:flutter/foundation.dart';

import '../models/try_on_category.dart';
import '../models/web_product.dart';
import '../models/web_purchase_options.dart';

/// Where a checkout started from the try-on preview has got to.
enum CheckoutStep {
  /// Nothing under way.
  none,

  /// Waiting for the user to pick a colour in the preview.
  pickingColor,

  /// Waiting for the user to pick a size in the preview.
  pickingSize,

  /// The page has been asked to add the product; waiting for its answer.
  adding,
}

@immutable
class ProductTryOnState {
  /// What the page in front of the user is selling, if anything.
  final WebProduct? product;

  /// Which of the service's four categories [product] would be tried on as.
  /// Null with no product.
  final TryOnCategory? category;

  /// True while the try-on service is being asked for a try-on.
  final bool isLoading;

  /// The try-on image the service answered with, shown over the page until
  /// the user closes it. Null when there is nothing to show.
  final String? resultUrl;

  final String? error;

  /// What the product page offers by way of buying — sizes, an add-to-cart
  /// control. Null until the page has said, and for pages that never do.
  final WebPurchaseOptions? options;

  final CheckoutStep checkoutStep;

  /// The size the user picked in the preview, once they have.
  final String? checkoutSize;

  /// The colour the checkout will ask the page for: the user's pick, or the
  /// one the page or its address had already settled on.
  final String? checkoutColor;

  const ProductTryOnState({
    this.product,
    this.category,
    this.isLoading = false,
    this.resultUrl,
    this.error,
    this.options,
    this.checkoutStep = CheckoutStep.none,
    this.checkoutSize,
    this.checkoutColor,
  });

  bool get hasProduct => product != null;

  /// The overlay is worth showing only with both a product and the category
  /// it would be sent as.
  bool get canTryOn => product != null && category != null;

  bool get hasResult => resultUrl != null;

  /// Whether the preview can offer a checkout at all. It can whenever the
  /// page has a product: with no reading of the page's controls the offer
  /// still stands, it just hands the user back to the page to finish.
  bool get canCheckout => product != null && resultUrl != null;

  /// The sizes to offer in the preview, in the page's order.
  List<WebSizeOption> get sizes => options?.sizes ?? const [];

  /// The colours to offer in the preview, in the page's order.
  List<WebColorOption> get colors => options?.colors ?? const [];

  ProductTryOnState copyWith({
    WebProduct? product,
    TryOnCategory? category,
    bool? isLoading,
    String? resultUrl,
    String? error,
    WebPurchaseOptions? options,
    CheckoutStep? checkoutStep,
    String? checkoutSize,
    String? checkoutColor,
    bool clearResult = false,
    bool clearError = false,
    bool clearCheckout = false,
  }) => ProductTryOnState(
    product: product ?? this.product,
    category: category ?? this.category,
    isLoading: isLoading ?? this.isLoading,
    resultUrl: clearResult ? null : (resultUrl ?? this.resultUrl),
    error: clearError ? null : (error ?? this.error),
    options: options ?? this.options,
    checkoutStep: clearCheckout
        ? CheckoutStep.none
        : (checkoutStep ?? this.checkoutStep),
    checkoutSize: clearCheckout ? null : (checkoutSize ?? this.checkoutSize),
    checkoutColor: clearCheckout ? null : (checkoutColor ?? this.checkoutColor),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductTryOnState &&
          other.product == product &&
          other.category == category &&
          other.isLoading == isLoading &&
          other.resultUrl == resultUrl &&
          other.error == error &&
          other.options == options &&
          other.checkoutStep == checkoutStep &&
          other.checkoutSize == checkoutSize &&
          other.checkoutColor == checkoutColor;

  @override
  int get hashCode => Object.hash(
    product,
    category,
    isLoading,
    resultUrl,
    error,
    options,
    checkoutStep,
    checkoutSize,
    checkoutColor,
  );
}

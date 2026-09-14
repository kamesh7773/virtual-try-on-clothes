// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_try_on_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The try-on offer shown over a product page, and the request behind it.
///
/// Scoped to the browser screen: leaving the browser should forget the
/// product, not carry it into the next session.

@ProviderFor(ProductTryOnViewModel)
final productTryOnViewModelProvider = ProductTryOnViewModelProvider._();

/// The try-on offer shown over a product page, and the request behind it.
///
/// Scoped to the browser screen: leaving the browser should forget the
/// product, not carry it into the next session.
final class ProductTryOnViewModelProvider
    extends $NotifierProvider<ProductTryOnViewModel, ProductTryOnState> {
  /// The try-on offer shown over a product page, and the request behind it.
  ///
  /// Scoped to the browser screen: leaving the browser should forget the
  /// product, not carry it into the next session.
  ProductTryOnViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'productTryOnViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$productTryOnViewModelHash();

  @$internal
  @override
  ProductTryOnViewModel create() => ProductTryOnViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProductTryOnState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProductTryOnState>(value),
    );
  }
}

String _$productTryOnViewModelHash() =>
    r'e0509d60b206dcb5a69a25cd9bb5ef9c84ccc831';

/// The try-on offer shown over a product page, and the request behind it.
///
/// Scoped to the browser screen: leaving the browser should forget the
/// product, not carry it into the next session.

abstract class _$ProductTryOnViewModel extends $Notifier<ProductTryOnState> {
  ProductTryOnState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ProductTryOnState, ProductTryOnState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ProductTryOnState, ProductTryOnState>,
              ProductTryOnState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

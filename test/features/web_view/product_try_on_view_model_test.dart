import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:virtual_try_on/core/services/api_client.dart';
import 'package:virtual_try_on/features/web_view/models/try_on_category.dart';
import 'package:virtual_try_on/features/web_view/models/web_product.dart';
import 'package:virtual_try_on/features/web_view/models/web_purchase_options.dart';
import 'package:virtual_try_on/features/web_view/view_models/product_try_on_state.dart';
import 'package:virtual_try_on/features/web_view/view_models/product_try_on_view_model.dart';

import '../../support/stub_http_adapter.dart';

const _product = WebProduct(
  pageUrl: 'https://www.dickssportinggoods.com/p/walter-hagen-polo',
  title: "Walter Hagen Men's Performance 11 Tailgate Print Golf Polo",
  imageUrl: 'https://dks.scene7.com/is/image/dkscdn/polo',
);

/// The view model over a real repository with canned HTTP behind it — the
/// layer being tested is the state it keeps, not the parsing below it.
(ProviderContainer, StubHttpAdapter) _container(StubHttpAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  final container = ProviderContainer(
    overrides: [apiClientProvider.overrideWithValue(dio)],
  );
  container.listen(
    productTryOnViewModelProvider,
    (_, _) {},
    fireImmediately: true,
  );
  addTearDown(container.dispose);
  return (container, adapter);
}

void main() {
  test('no product until the page reports one', () {
    final (container, _) = _container(
      StubHttpAdapter(body: {'url': 'https://mirror.maxaix.com/tryon/1'}),
    );

    expect(container.read(productTryOnViewModelProvider).hasProduct, isFalse);
    expect(container.read(productTryOnViewModelProvider).canTryOn, isFalse);

    container.read(productTryOnViewModelProvider.notifier).setProduct(_product);

    final state = container.read(productTryOnViewModelProvider);
    expect(state.product, _product);
    // The category the overlay shows is worked out here, not in the widget.
    expect(state.category, TryOnCategory.golf);
    expect(state.canTryOn, isTrue);
  });

  test('leaving a product page clears the offer', () {
    final (container, _) = _container(StubHttpAdapter(body: null));
    final viewModel = container.read(productTryOnViewModelProvider.notifier);
    viewModel.setProduct(_product);

    viewModel.setProduct(null);

    final state = container.read(productTryOnViewModelProvider);
    expect(state.hasProduct, isFalse);
    expect(state.category, isNull);
  });

  test('leaves the try-on image on the state for the preview', () async {
    final (container, _) = _container(
      StubHttpAdapter(
        body: {
          'success': true,
          'image': 'https://mirror.maxaix.com/images/Golf.png',
          'url': 'https://mirror.maxaix.com/images/Golf.png',
        },
      ),
    );
    final viewModel = container.read(productTryOnViewModelProvider.notifier);
    viewModel.setProduct(_product);

    await viewModel.requestTryOn();
    final state = container.read(productTryOnViewModelProvider);

    expect(state.resultUrl, 'https://mirror.maxaix.com/images/Golf.png');
    expect(state.hasResult, isTrue);
    expect(state.isLoading, isFalse);
    expect(state.error, isNull);
  });

  test('closing the try-on leaves the product it was for', () async {
    final (container, _) = _container(
      StubHttpAdapter(
        body: {'image': 'https://mirror.maxaix.com/images/Golf.png'},
      ),
    );
    final viewModel = container.read(productTryOnViewModelProvider.notifier);
    viewModel.setProduct(_product);
    await viewModel.requestTryOn();

    viewModel.dismissResult();
    final state = container.read(productTryOnViewModelProvider);

    expect(state.hasResult, isFalse);
    expect(state.canTryOn, isTrue);
  });

  test('asking again clears the try-on already on screen', () async {
    final (container, _) = _container(
      StubHttpAdapter(body: {'status': 'queued'}),
    );
    final viewModel = container.read(productTryOnViewModelProvider.notifier);
    viewModel.setProduct(_product);

    await viewModel.requestTryOn();

    expect(container.read(productTryOnViewModelProvider).resultUrl, isNull);
  });

  test('a failure leaves the reason on the state for the overlay', () async {
    final (container, _) = _container(
      StubHttpAdapter(body: {'status': 'queued'}),
    );
    final viewModel = container.read(productTryOnViewModelProvider.notifier);
    viewModel.setProduct(_product);

    await viewModel.requestTryOn();

    expect(container.read(productTryOnViewModelProvider).resultUrl, isNull);
    expect(
      container.read(productTryOnViewModelProvider).error,
      contains('did not return an image'),
    );
    expect(container.read(productTryOnViewModelProvider).isLoading, isFalse);
  });

  test('no product means no request', () async {
    final (container, adapter) = _container(
      StubHttpAdapter(body: {'url': 'https://mirror.maxaix.com/tryon/1'}),
    );

    await container.read(productTryOnViewModelProvider.notifier).requestTryOn();

    expect(adapter.postCount, 0);
  });

  test('a second tap while the first is in flight is ignored', () async {
    final (container, adapter) = _container(
      StubHttpAdapter(body: {'url': 'https://mirror.maxaix.com/tryon/1'}),
    );
    final viewModel = container.read(productTryOnViewModelProvider.notifier);
    viewModel.setProduct(_product);

    await Future.wait([viewModel.requestTryOn(), viewModel.requestTryOn()]);

    expect(adapter.postCount, 1);
  });

  test('a new product clears the error left by the last one', () async {
    final (container, _) = _container(
      StubHttpAdapter(body: {'status': 'queued'}),
    );
    final viewModel = container.read(productTryOnViewModelProvider.notifier);
    viewModel.setProduct(_product);
    await viewModel.requestTryOn();

    viewModel.setProduct(
      const WebProduct(
        pageUrl: 'https://example.com/p/2',
        title: 'Another',
        imageUrl: 'https://example.com/2.jpg',
      ),
    );

    expect(container.read(productTryOnViewModelProvider).error, isNull);
  });

  group('checkout from the preview', () {
    const withSizes = WebPurchaseOptions(
      pageUrl: 'https://www.dickssportinggoods.com/p/walter-hagen-polo',
      sizes: [
        WebSizeOption(label: 'S'),
        WebSizeOption(label: 'M'),
      ],
      canAddToCart: true,
    );

    test('options from another page are not taken for this one', () {
      final (container, _) = _container(StubHttpAdapter(body: null));
      final viewModel = container.read(productTryOnViewModelProvider.notifier);
      viewModel.setProduct(_product);

      viewModel.setOptions(
        const WebPurchaseOptions(
          pageUrl: 'https://www.dickssportinggoods.com/p/something-else',
          canAddToCart: true,
        ),
      );

      expect(container.read(productTryOnViewModelProvider).options, isNull);
    });

    test('with no reading of the page, the user is handed the page', () {
      final (container, _) = _container(StubHttpAdapter(body: null));
      final viewModel = container.read(productTryOnViewModelProvider.notifier);
      viewModel.setProduct(_product);

      expect(viewModel.startCheckout(), CheckoutPlan.guide);
      expect(
        container.read(productTryOnViewModelProvider).checkoutStep,
        CheckoutStep.none,
      );
    });

    test('a size row with nothing picked asks for a size first', () {
      final (container, _) = _container(StubHttpAdapter(body: null));
      final viewModel = container.read(productTryOnViewModelProvider.notifier);
      viewModel.setProduct(_product);
      viewModel.setOptions(withSizes);

      expect(viewModel.startCheckout(), CheckoutPlan.pickSize);
      expect(
        container.read(productTryOnViewModelProvider).checkoutStep,
        CheckoutStep.pickingSize,
      );

      viewModel.chooseSize('M');
      final state = container.read(productTryOnViewModelProvider);
      expect(state.checkoutStep, CheckoutStep.adding);
      expect(state.checkoutSize, 'M');
    });

    test('a size the page already has picked goes straight to the cart', () {
      final (container, _) = _container(StubHttpAdapter(body: null));
      final viewModel = container.read(productTryOnViewModelProvider.notifier);
      viewModel.setProduct(_product);
      viewModel.setOptions(
        const WebPurchaseOptions(
          pageUrl: 'https://www.dickssportinggoods.com/p/walter-hagen-polo',
          sizes: [
            WebSizeOption(label: 'S'),
            WebSizeOption(label: 'L', selected: true),
          ],
          canAddToCart: true,
        ),
      );

      expect(viewModel.startCheckout(), CheckoutPlan.add);
      final state = container.read(productTryOnViewModelProvider);
      expect(state.checkoutStep, CheckoutStep.adding);
      expect(state.checkoutSize, 'L');
    });

    test('colours the page has not settled are asked for before the size', () {
      final (container, _) = _container(StubHttpAdapter(body: null));
      final viewModel = container.read(productTryOnViewModelProvider.notifier);
      viewModel.setProduct(_product);
      viewModel.setOptions(
        const WebPurchaseOptions(
          pageUrl: 'https://www.dickssportinggoods.com/p/walter-hagen-polo',
          colors: [
            WebColorOption(label: 'Red'),
            WebColorOption(label: 'Blue'),
          ],
          sizes: [
            WebSizeOption(label: 'S'),
            WebSizeOption(label: 'M'),
          ],
          canAddToCart: true,
        ),
      );

      expect(viewModel.startCheckout(), CheckoutPlan.pickColor);
      expect(
        container.read(productTryOnViewModelProvider).checkoutStep,
        CheckoutStep.pickingColor,
      );

      expect(viewModel.chooseColor('Blue'), CheckoutPlan.pickSize);
      var state = container.read(productTryOnViewModelProvider);
      expect(state.checkoutStep, CheckoutStep.pickingSize);
      expect(state.checkoutColor, 'Blue');

      viewModel.chooseSize('M');
      state = container.read(productTryOnViewModelProvider);
      expect(state.checkoutStep, CheckoutStep.adding);
      expect(state.checkoutColor, 'Blue');
      expect(state.checkoutSize, 'M');
    });

    test('a colour the address names is taken without asking', () {
      final (container, _) = _container(StubHttpAdapter(body: null));
      final viewModel = container.read(productTryOnViewModelProvider.notifier);
      viewModel.setProduct(
        const WebProduct(
          pageUrl:
              'https://www.dickssportinggoods.com/p/walter-hagen-polo?color=Red',
          title: "Walter Hagen Men's Golf Polo",
          imageUrl: 'https://dks.scene7.com/is/image/dkscdn/polo',
        ),
      );
      viewModel.setOptions(
        const WebPurchaseOptions(
          pageUrl:
              'https://www.dickssportinggoods.com/p/walter-hagen-polo?color=Red',
          colors: [
            WebColorOption(label: 'Red'),
            WebColorOption(label: 'Blue'),
          ],
          sizes: [WebSizeOption(label: 'S', selected: true)],
          canAddToCart: true,
        ),
      );

      expect(viewModel.startCheckout(), CheckoutPlan.add);
      final state = container.read(productTryOnViewModelProvider);
      expect(state.checkoutColor, 'Red');
      expect(state.checkoutSize, 'S');
    });

    test('a refusal ends the checkout and keeps the reason', () {
      final (container, _) = _container(StubHttpAdapter(body: null));
      final viewModel = container.read(productTryOnViewModelProvider.notifier);
      viewModel.setProduct(_product);
      viewModel.setOptions(withSizes);
      viewModel.startCheckout();
      viewModel.chooseSize('S');

      viewModel.checkoutFailed('Size S is out of stock.');

      final state = container.read(productTryOnViewModelProvider);
      expect(state.checkoutStep, CheckoutStep.none);
      expect(state.checkoutSize, isNull);
      expect(state.error, 'Size S is out of stock.');
    });

    test('closing the try-on drops a checkout half-started from it', () {
      final (container, _) = _container(StubHttpAdapter(body: null));
      final viewModel = container.read(productTryOnViewModelProvider.notifier);
      viewModel.setProduct(_product);
      viewModel.setOptions(withSizes);
      viewModel.startCheckout();

      viewModel.dismissResult();

      expect(
        container.read(productTryOnViewModelProvider).checkoutStep,
        CheckoutStep.none,
      );
    });

    test('leaving the page forgets its options', () {
      final (container, _) = _container(StubHttpAdapter(body: null));
      final viewModel = container.read(productTryOnViewModelProvider.notifier);
      viewModel.setProduct(_product);
      viewModel.setOptions(withSizes);

      viewModel.setProduct(null);

      expect(container.read(productTryOnViewModelProvider).options, isNull);
    });
  });
}

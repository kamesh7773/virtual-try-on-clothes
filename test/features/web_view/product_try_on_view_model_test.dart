import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:virtual_try_on/core/services/api_client.dart';
import 'package:virtual_try_on/features/web_view/models/try_on_category.dart';
import 'package:virtual_try_on/features/web_view/models/web_product.dart';
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

  test('returns the link the service answers with', () async {
    final (container, _) = _container(
      StubHttpAdapter(body: {'url': 'https://mirror.maxaix.com/tryon/1'}),
    );
    final viewModel = container.read(productTryOnViewModelProvider.notifier);
    viewModel.setProduct(_product);

    final url = await viewModel.requestTryOnUrl();

    expect(url, 'https://mirror.maxaix.com/tryon/1');
    expect(container.read(productTryOnViewModelProvider).isLoading, isFalse);
    expect(container.read(productTryOnViewModelProvider).error, isNull);
  });

  test('a failure leaves the reason on the state for the overlay', () async {
    final (container, _) = _container(
      StubHttpAdapter(body: {'status': 'queued'}),
    );
    final viewModel = container.read(productTryOnViewModelProvider.notifier);
    viewModel.setProduct(_product);

    final url = await viewModel.requestTryOnUrl();

    expect(url, isNull);
    expect(
      container.read(productTryOnViewModelProvider).error,
      contains('did not return a link'),
    );
    expect(container.read(productTryOnViewModelProvider).isLoading, isFalse);
  });

  test('no product means no request', () async {
    final (container, adapter) = _container(
      StubHttpAdapter(body: {'url': 'https://mirror.maxaix.com/tryon/1'}),
    );

    final url = await container
        .read(productTryOnViewModelProvider.notifier)
        .requestTryOnUrl();

    expect(url, isNull);
    expect(adapter.postCount, 0);
  });

  test('a second tap while the first is in flight is ignored', () async {
    final (container, adapter) = _container(
      StubHttpAdapter(body: {'url': 'https://mirror.maxaix.com/tryon/1'}),
    );
    final viewModel = container.read(productTryOnViewModelProvider.notifier);
    viewModel.setProduct(_product);

    await Future.wait([
      viewModel.requestTryOnUrl(),
      viewModel.requestTryOnUrl(),
    ]);

    expect(adapter.postCount, 1);
  });

  test('a new product clears the error left by the last one', () async {
    final (container, _) = _container(
      StubHttpAdapter(body: {'status': 'queued'}),
    );
    final viewModel = container.read(productTryOnViewModelProvider.notifier);
    viewModel.setProduct(_product);
    await viewModel.requestTryOnUrl();

    viewModel.setProduct(
      const WebProduct(
        pageUrl: 'https://example.com/p/2',
        title: 'Another',
        imageUrl: 'https://example.com/2.jpg',
      ),
    );

    expect(container.read(productTryOnViewModelProvider).error, isNull);
  });
}

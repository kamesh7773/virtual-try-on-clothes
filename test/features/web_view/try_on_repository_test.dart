import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:virtual_try_on/core/constants/api_endpoints.dart';
import 'package:virtual_try_on/core/services/api_client.dart';
import 'package:virtual_try_on/features/web_view/models/web_product.dart';
import 'package:virtual_try_on/features/web_view/repositories/try_on_repository.dart';

import '../../support/stub_http_adapter.dart';

const _product = WebProduct(
  pageUrl: 'https://www.dickssportinggoods.com/p/walter-hagen-polo',
  title: "Walter Hagen Men's Performance 11 Tailgate Print Golf Polo",
  imageUrl: 'https://dks.scene7.com/is/image/dkscdn/polo',
  brand: 'Walter Hagen',
);

(TryOnRepository, StubHttpAdapter) _repository(StubHttpAdapter adapter) {
  // No base URL: every call this repository makes is to an absolute one.
  final dio = Dio()..httpClientAdapter = adapter;
  // Through the provider, so the repository is built the way the app builds
  // it — Dio and all.
  final container = ProviderContainer(
    overrides: [apiClientProvider.overrideWithValue(dio)],
  );
  addTearDown(container.dispose);
  return (container.read(tryOnRepositoryProvider), adapter);
}

void main() {
  test(
    'posts the category and the downloaded shot to the try-on endpoint',
    () async {
      final (repository, adapter) = _repository(
        StubHttpAdapter(body: {'url': 'https://mirror.maxaix.com/tryon/1'}),
      );

      await repository.requestTryOn(_product);

      // The shot is fetched from the retailer first…
      expect(adapter.imageRequest!.uri.toString(), _product.imageUrl);
      // …then posted to the endpoint the constants name.
      expect(adapter.postRequest!.uri.toString(), ApiEndpoints.tryOn);

      final sent = adapter.postRequest!.data as FormData;
      // MapEntry has no value equality, so the pair is checked by hand. The
      // service takes one of its four categories, not the product's name.
      final category = sent.fields.singleWhere((f) => f.key == 'category');
      expect(category.value, 'golf');

      final image = sent.files.single;
      expect(image.key, 'image');
      expect(image.value.filename, 'product.png');
      expect(image.value.length, 4);
    },
  );

  test('names the file by what the CDN says it served', () async {
    final (repository, adapter) = _repository(
      StubHttpAdapter(
        body: {'url': 'https://mirror.maxaix.com/tryon/1'},
        imageContentType: 'image/jpeg;charset=utf-8',
      ),
    );

    await repository.requestTryOn(_product);

    final image = (adapter.postRequest!.data as FormData).files.single;
    expect(image.value.filename, 'product.jpg');
  });

  test(
    'reads the link back out of the shapes a service may answer in',
    () async {
      for (final body in <Object>[
        {'url': 'https://mirror.maxaix.com/tryon/1'},
        {'tryOnUrl': 'https://mirror.maxaix.com/tryon/1'},
        {'resultUrl': 'https://mirror.maxaix.com/tryon/1'},
        {'data': 'https://mirror.maxaix.com/tryon/1'},
        {
          'data': {'url': 'https://mirror.maxaix.com/tryon/1'},
        },
        'https://mirror.maxaix.com/tryon/1',
      ]) {
        final (repository, _) = _repository(StubHttpAdapter(body: body));
        final response = await repository.requestTryOn(_product);

        expect(response.isSuccess, isTrue, reason: '$body');
        expect(
          response.data!.url,
          'https://mirror.maxaix.com/tryon/1',
          reason: '$body',
        );
      }
    },
  );

  test('a path is completed against the try-on host', () async {
    final (repository, _) = _repository(
      StubHttpAdapter(body: {'url': '/tryon/1'}),
    );

    final response = await repository.requestTryOn(_product);

    expect(response.data!.url, 'https://mirror.maxaix.com/tryon/1');
  });

  test('an answer without a link is a failure, not an empty success', () async {
    final (repository, _) = _repository(
      StubHttpAdapter(body: {'status': 'queued'}),
    );

    final response = await repository.requestTryOn(_product);

    expect(response.isSuccess, isFalse);
    expect(response.error, contains('did not return a link'));
  });

  test('a shot the CDN refuses stops the request before it is sent', () async {
    final (repository, adapter) = _repository(
      StubHttpAdapter(body: {'url': 'https://x'}, imageStatus: 403),
    );

    final response = await repository.requestTryOn(_product);

    expect(response.isSuccess, isFalse);
    expect(response.error, contains('download the product image'));
    expect(adapter.postRequest, isNull);
  });

  test('a shot too large to be a product photo is refused', () async {
    final (repository, adapter) = _repository(
      StubHttpAdapter(
        body: {'url': 'https://x'},
        imageBytes: List<int>.filled(TryOnRepository.maxImageBytes + 1, 7),
      ),
    );

    expect((await repository.requestTryOn(_product)).isSuccess, isFalse);
    expect(adapter.postRequest, isNull);
  });

  test('a server error comes back readable', () async {
    final (repository, _) = _repository(
      StubHttpAdapter(body: {'error': 'nope'}, statusCode: 500),
    );

    final response = await repository.requestTryOn(_product);

    expect(response.isSuccess, isFalse);
    expect(response.error, 'Server error');
    expect(response.statusCode, 500);
  });
}

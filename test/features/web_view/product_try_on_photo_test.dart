import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:virtual_try_on/core/constants/api_endpoints.dart';
import 'package:virtual_try_on/core/services/api_client.dart';
import 'package:virtual_try_on/features/style_me/models/style_photo.dart';
import 'package:virtual_try_on/features/style_me/view_models/style_session_view_model.dart';
import 'package:virtual_try_on/features/web_view/models/web_product.dart';
import 'package:virtual_try_on/features/web_view/view_models/product_try_on_view_model.dart';

import '../../support/test_env.dart';

const _product = WebProduct(
  pageUrl: 'https://www.dickssportinggoods.com/p/walter-hagen-polo',
  title: "Walter Hagen Men's Performance 11 Tailgate Print Golf Polo",
  imageUrl: 'https://dks.scene7.com/is/image/dkscdn/polo',
);

const _result = 'https://mirror.maxaix.com/storage/tryon/1.webp';

/// The retailer's image CDN, the photo upload and the try-on service, in
/// one: hands out photo ids in order and records which id each try-on named.
class _Adapter implements HttpClientAdapter {
  /// Ids the try-on service refuses as expired.
  final Set<String> expired = {};

  int uploads = 0;

  /// The `photo_id` field of each try-on, in order. Null where none was sent.
  final List<String?> named = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'GET') {
      return ResponseBody.fromBytes(
        [1, 2, 3, 4],
        200,
        headers: {
          Headers.contentTypeHeader: ['image/png'],
        },
      );
    }

    final url = options.uri.toString();
    if (url == ApiEndpoints.stylePhoto) {
      uploads++;
      return _json(201, {
        'photo_id': 'ph_$uploads',
        'expires_at': DateTime.now()
            .add(const Duration(hours: 6))
            .toIso8601String(),
      });
    }

    final fields = (options.data as FormData).fields;
    final photoId = fields
        .where((f) => f.key == 'photo_id')
        .map((f) => f.value)
        .firstOrNull;
    named.add(photoId);
    if (photoId != null && expired.contains(photoId)) {
      return _json(404, {
        'success': false,
        'code': 'photo_expired',
        'message': 'That photo_id has expired or does not exist.',
      });
    }
    return _json(200, {'success': true, 'image': _result, 'url': _result});
  }

  ResponseBody _json(int status, Object payload) => ResponseBody.fromString(
    jsonEncode(payload),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

(ProviderContainer, _Adapter) _container() {
  final adapter = _Adapter();
  final container = ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue(Dio()..httpClientAdapter = adapter),
    ],
  );
  container.listen(
    productTryOnViewModelProvider,
    (_, _) {},
    fireImmediately: true,
  );
  addTearDown(container.dispose);
  return (container, adapter);
}

void _takePhoto(ProviderContainer container) => container
    .read(styleSessionViewModelProvider.notifier)
    .usePhoto(StylePhoto(Uint8List.fromList([9, 9, 9])));

void main() {
  setUpAll(loadTestEnv);

  test("a try-on names the shopper's own photo", () async {
    final (container, adapter) = _container();
    _takePhoto(container);
    final viewModel = container.read(productTryOnViewModelProvider.notifier)
      ..setProduct(_product);

    await viewModel.requestTryOn();

    expect(adapter.named, ['ph_1']);
    expect(adapter.uploads, 1, reason: 'the upload from the capture is reused');
    expect(container.read(productTryOnViewModelProvider).resultUrl, _result);
  });

  test('without a photo the try-on is still sent, naming none', () async {
    final (container, adapter) = _container();
    final viewModel = container.read(productTryOnViewModelProvider.notifier)
      ..setProduct(_product);

    await viewModel.requestTryOn();

    expect(adapter.named, [null]);
    expect(adapter.uploads, 0);
    expect(container.read(productTryOnViewModelProvider).resultUrl, _result);
  });

  test('an expired photo is uploaded again and the try-on retried', () async {
    final (container, adapter) = _container();
    adapter.expired.add('ph_1');
    _takePhoto(container);
    final viewModel = container.read(productTryOnViewModelProvider.notifier)
      ..setProduct(_product);

    await viewModel.requestTryOn();

    expect(adapter.named, ['ph_1', 'ph_2']);
    expect(adapter.uploads, 2);
    expect(container.read(styleSessionViewModelProvider).upload?.id, 'ph_2');
    final state = container.read(productTryOnViewModelProvider);
    expect(state.resultUrl, _result);
    expect(state.error, isNull);
  });

  test('a photo that keeps expiring is reported, not chased', () async {
    final (container, adapter) = _container();
    adapter.expired.addAll(['ph_1', 'ph_2']);
    _takePhoto(container);
    final viewModel = container.read(productTryOnViewModelProvider.notifier)
      ..setProduct(_product);

    await viewModel.requestTryOn();

    expect(adapter.named, ['ph_1', 'ph_2'], reason: 'one retry, no more');
    final state = container.read(productTryOnViewModelProvider);
    expect(state.resultUrl, isNull);
    expect(state.error, contains('photo has expired'));
    expect(state.isLoading, isFalse);
  });
}

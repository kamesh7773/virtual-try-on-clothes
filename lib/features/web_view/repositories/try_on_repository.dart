import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/models/api_response.dart';
import '../../../core/services/base_api_service.dart';
import '../models/try_on_category.dart';
import '../models/try_on_result.dart';
import '../models/web_product.dart';

part 'try_on_repository.g.dart';

@riverpod
TryOnRepository tryOnRepository(Ref ref) => TryOnRepository(ref);

/// Turns a product found in the browser into a try-on page to open.
///
/// The product shot is fetched from the retailer and posted as a file rather
/// than as a link: the service is asked to try a garment on, and a URL it
/// cannot reach — a CDN behind a referer check, a signed link that has since
/// expired — is no use to it.
class TryOnRepository extends BaseApiService {
  TryOnRepository(super.ref);

  /// Beyond this the shot is not a product photo but something the app has no
  /// business holding in memory.
  static const int maxImageBytes = 12 * 1024 * 1024;

  /// Which of the service's four categories a product is tried on as.
  static TryOnCategory categoryFor(WebProduct product) =>
      resolveTryOnCategory(title: product.title, url: product.pageUrl);

  Future<ApiResponse<TryOnResult>> requestTryOn(WebProduct product) async {
    final category = categoryFor(product);

    final image = await _downloadImage(product.imageUrl);
    if (image == null) {
      return ApiResponse.failure('Could not download the product image');
    }

    try {
      final response = await _postForm(category, image);
      debugPrint(
        '[try-on] ${response.statusCode} from ${response.realUri} — '
        '${response.data}',
      );

      final result = TryOnResult.tryParse(response.data);
      if (result == null) {
        return ApiResponse.failure(
          'The try-on service did not return an image',
          statusCode: response.statusCode,
        );
      }

      return ApiResponse.success(
        TryOnResult(url: _resolve(result.url)),
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      debugPrint('[try-on] failed: ${e.response?.statusCode} ${e.message}');
      return ApiResponse.failure(
        getDioErrorType(e).message,
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      return ApiResponse.failure('Could not reach the try-on service: $e');
    }
  }

  /// Posts the form, following any redirect as another POST.
  ///
  /// Left to itself an HTTP client turns a redirected POST into a GET and
  /// drops the body — the server then sees a bare GET with no `category` and
  /// no file, which is exactly what a missing trailing slash produces. The
  /// form is rebuilt for each attempt rather than reused: a `FormData`
  /// streams its bytes once and cannot be replayed.
  Future<Response<dynamic>> _postForm(
    TryOnCategory category,
    _ProductImage image, {
    int maxRedirects = 3,
  }) async {
    var url = ApiEndpoints.tryOn;

    for (var attempt = 0; ; attempt++) {
      debugPrint(
        '[try-on] POST $url — category=${category.wireName}, '
        '${image.filename}, ${image.bytes.length} bytes',
      );

      final response = await post(
        url,
        data: FormData.fromMap({
          // The service takes one of its four categories, not a product name.
          'category': category.wireName,
          'image': MultipartFile.fromBytes(
            image.bytes,
            filename: image.filename,
            contentType: image.contentType,
          ),
        }),
        options: Options(
          followRedirects: false,
          validateStatus: (status) => status != null && status < 400,
        ),
      );

      final status = response.statusCode ?? 0;
      final location = response.headers.value('location');
      if (status < 300 || location == null || attempt >= maxRedirects) {
        return response;
      }

      url = Uri.parse(url).resolve(location).toString();
      debugPrint('[try-on] $status redirect → $url, posting again');
    }
  }

  Future<_ProductImage?> _downloadImage(String url) async {
    try {
      debugPrint('[try-on] downloading product shot $url');
      final response = await get(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          // Retail CDNs answer a bare client with a redirect or a 403 more
          // often than they answer it with an image.
          headers: const {'Accept': 'image/*'},
        ),
      );

      final bytes = response.data;
      if (bytes is! List<int> || bytes.isEmpty) return null;
      if (bytes.length > maxImageBytes) return null;

      return _ProductImage(
        bytes: Uint8List.fromList(bytes),
        contentType: response.headers.value(Headers.contentTypeHeader),
      );
    } catch (e) {
      // The reason a CDN refused is not something the user can act on; the
      // caller reports that the shot could not be fetched.
      debugPrint('[try-on] product shot could not be downloaded: $e');
      return null;
    }
  }

  /// A service that answers with a path is answering about its own host.
  String _resolve(String url) => url.startsWith('http')
      ? url
      : Uri.parse(ApiEndpoints.tryOn).resolve(url).toString();
}

/// A product shot, in memory, on its way to the try-on service.
class _ProductImage {
  final Uint8List bytes;
  final String? _contentType;

  const _ProductImage({required this.bytes, String? contentType})
    : _contentType = contentType;

  /// What the server should be told this file is. Retail CDNs serve images
  /// from extensionless URLs, so the header is the more reliable source.
  DioMediaType? get contentType {
    final raw = _contentType?.split(';').first.trim();
    if (raw == null || !raw.startsWith('image/')) return null;
    final parts = raw.split('/');
    return parts.length == 2 ? DioMediaType(parts[0], parts[1]) : null;
  }

  String get filename {
    final extension = switch (contentType?.subtype) {
      'jpeg' || 'jpg' => 'jpg',
      'png' => 'png',
      'webp' => 'webp',
      'avif' => 'avif',
      'gif' => 'gif',
      // Named a JPEG only by convention — the bytes are whatever the CDN
      // served, and the service reads those, not the name.
      _ => 'jpg',
    };
    return 'product.$extension';
  }
}

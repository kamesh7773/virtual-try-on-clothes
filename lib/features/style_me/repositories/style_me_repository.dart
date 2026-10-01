import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/base_api_service.dart';
import '../../web_view/models/shop_link.dart';
import '../../web_view/models/try_on_category.dart';
import '../models/style_photo.dart';

part 'style_me_repository.g.dart';

@riverpod
StyleMeRepository styleMeRepository(Ref ref) => StyleMeRepository(ref);

/// What one request for a look came back with.
sealed class LookAttempt {
  const LookAttempt();
}

class LookReady extends LookAttempt {
  final String image;

  /// Where the service sells this look. Null when it sent none.
  final Uri? shopUrl;

  const LookReady(this.image, {this.shopUrl});
}

/// The photo id has expired or was never known. Upload again, then ask
/// again.
class LookPhotoExpired extends LookAttempt {
  const LookPhotoExpired();
}

class LookFailed extends LookAttempt {
  /// False when the service refused the request itself — asking again with
  /// the same fields gets the same answer.
  final bool retryable;
  final String reason;
  const LookFailed(this.reason, {this.retryable = true});
}

/// Talks to the Style Me app API on the mirror's host.
class StyleMeRepository extends BaseApiService {
  StyleMeRepository(super.ref);

  /// A service that answers with a path (`/storage/...webp`) is answering
  /// about its own host. The API doc promises a full URL; the server sends
  /// a path, and either way the picture is on [ApiEndpoints.styleLook]'s
  /// host.
  static String _resolve(String image) => image.startsWith('http')
      ? image
      : Uri.parse(ApiEndpoints.styleLook).resolve(image).toString();

  /// The server gives its provider 150s; the app waits a little longer than
  /// that so a slow look is a result, not a timeout.
  static const Duration lookTimeout = Duration(seconds: 170);

  /// Uploads the snapshot for a `photo_id`. Null when the upload failed.
  Future<UploadedPhoto?> uploadPhoto(StylePhoto photo) async {
    debugPrint('[style-me] POST photo, ${photo.bytes.length} bytes');
    try {
      final response = await post(
        ApiEndpoints.stylePhoto,
        data: FormData.fromMap({
          'photo': MultipartFile.fromBytes(
            photo.bytes,
            filename: 'photo.jpg',
            contentType: DioMediaType('image', 'jpeg'),
          ),
        }),
      );

      final data = response.data;
      final id = data is Map ? data['photo_id'] : null;
      final expiresAt = data is Map
          ? DateTime.tryParse('${data['expires_at']}')
          : null;
      if (id is! String || id.isEmpty) {
        debugPrint('[style-me] photo upload answered without an id: $data');
        return null;
      }
      debugPrint('[style-me] photo uploaded as $id');
      return UploadedPhoto(
        id: id,
        // Six hours, per the API; the field is only a confirmation of it.
        expiresAt: expiresAt ?? DateTime.now().add(const Duration(hours: 6)),
      );
    } on DioException catch (e) {
      debugPrint(
        '[style-me] photo upload failed: ${e.response?.statusCode} ${e.message}',
      );
      return null;
    }
  }

  /// Best effort: lets the server drop a photo the shopper is done with
  /// rather than keep it for the full six hours.
  Future<void> deletePhoto(String photoId) async {
    try {
      await dio.delete('${ApiEndpoints.stylePhoto}/$photoId');
    } on DioException catch (e) {
      debugPrint('[style-me] photo delete failed: ${e.response?.statusCode}');
    }
  }

  Future<LookAttempt> requestLook({
    required String photoId,
    required TryOnCategory category,
    required ShopVariant variant,
    required ShopDept dept,
  }) async {
    debugPrint(
      '[style-me] POST look ${category.wireName} '
      'variant=${variant.wireName} dept=${dept.wireName}',
    );
    try {
      final response = await post(
        ApiEndpoints.styleLook,
        data: {
          'photo_id': photoId,
          'category': category.wireName,
          'variant': variant.wireName,
          'dept': dept.wireName,
        },
        options: Options(sendTimeout: lookTimeout, receiveTimeout: lookTimeout),
      );

      final data = response.data;
      final image = data is Map ? data['image'] : null;
      if (image is! String || image.isEmpty) {
        return const LookFailed('The response carried no image');
      }
      if (data['test'] == true) {
        debugPrint('[style-me] ${category.wireName}: placeholder (test mode)');
      }
      final shop = data['shop_url'];
      return LookReady(
        _resolve(image),
        shopUrl: shop is String ? Uri.tryParse(shop) : null,
      );
    } on DioException catch (e) {
      final body = e.response?.data;
      final code = body is Map ? '${body['code'] ?? ''}' : '';
      final message = body is Map ? '${body['message'] ?? ''}' : '';

      if (code == 'photo_expired' || e.response?.statusCode == 404) {
        return const LookPhotoExpired();
      }

      // A validation answer lists the fields it refused. A provider failure
      // is also a 422, but one the API says is safe to retry.
      final refused =
          body is Map && body['errors'] != null && code != 'generation_failed';
      return LookFailed(
        message.isNotEmpty ? message : (e.message ?? 'Request failed'),
        retryable: !refused,
      );
    } catch (e) {
      return LookFailed('$e');
    }
  }
}

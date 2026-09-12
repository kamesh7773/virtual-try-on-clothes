import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Serves a product shot on a GET and a canned JSON body on a POST, and
/// remembers what was asked for.
///
/// Keeps the try-on tests off the network: the repository fetches an image
/// from a retailer and posts it on, and both halves have to be stood in for.
class StubHttpAdapter implements HttpClientAdapter {
  StubHttpAdapter({
    required this.body,
    this.statusCode = 200,
    this.imageBytes = const [1, 2, 3, 4],
    this.imageContentType = 'image/png',
    this.imageStatus = 200,
    this.redirectTo,
  });

  final Object? body;
  final int statusCode;
  final List<int> imageBytes;
  final String imageContentType;
  final int imageStatus;

  /// When set, the first POST is answered with a 307 pointing here — the
  /// trailing-slash redirect a server hands back for a path it normalises.
  final String? redirectTo;

  RequestOptions? imageRequest;
  RequestOptions? postRequest;
  int postCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'GET') {
      imageRequest = options;
      if (imageStatus != 200) {
        throw DioException.badResponse(
          statusCode: imageStatus,
          requestOptions: options,
          response: Response<void>(requestOptions: options),
        );
      }
      return ResponseBody.fromBytes(
        imageBytes,
        imageStatus,
        headers: {
          Headers.contentTypeHeader: [imageContentType],
        },
      );
    }

    postRequest = options;
    postCount++;

    if (redirectTo != null && postCount == 1) {
      return ResponseBody.fromString(
        '',
        307,
        headers: {
          'location': [redirectTo!],
        },
      );
    }

    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

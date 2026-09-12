import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../config/env.dart';
import '../constants/api_endpoints.dart';
import '../constants/app_constants.dart';
import 'secure_storage_service.dart';

part 'api_client.g.dart';

/// Function-style provider — returns a fully configured Dio instance.
/// Consumers read `ref.watch(apiClientProvider)` to get the Dio directly.
@Riverpod(keepAlive: true)
Dio apiClient(Ref ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiEndpoints.baseUrl,
      connectTimeout: AppConstants.connectionTimeout,
      receiveTimeout: AppConstants.receiveTimeout,
      sendTimeout: AppConstants.sendTimeout,
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );

  dio.interceptors.add(_apiKeyInterceptor(ref));

  if (Env.enableLogs && kDebugMode) {
    dio.interceptors.add(
      PrettyDioLogger(
        requestHeader: false,
        requestBody: true,
        responseBody: true,
        responseHeader: false,
        error: true,
        compact: true,
        maxWidth: 90,
      ),
    );
  }

  return dio;
}

/// Attaches the Decart API key as a bearer token and normalises Dio errors
/// into a human-readable message.
///
/// The key is resolved the same way the web app resolves it: a user-supplied
/// key in secure storage wins, otherwise the build-time key from `.env.*`.
/// There is no login or refresh-token flow — Decart authenticates with a
/// single API key, so a 401 here means the key is missing or invalid.
/// Whether a request is bound for Decart, and so should carry its key.
///
/// A relative path resolves against the Decart base URL and is always theirs;
/// an absolute URL is only theirs when its host matches.
@visibleForTesting
bool isDecartRequest(String url) {
  final requested = Uri.tryParse(url);
  if (requested == null || !requested.hasScheme) return true;

  final base = Uri.tryParse(ApiEndpoints.baseUrl);
  return base != null && requested.host == base.host;
}

Interceptor _apiKeyInterceptor(Ref ref) {
  return InterceptorsWrapper(
    onRequest: (options, handler) async {
      // Repositories call third-party hosts through this same Dio by passing
      // an absolute URL — a try-on service, a retailer's image CDN. Decart's
      // key is a full account credential; it goes to Decart and nowhere else.
      if (!isDecartRequest(options.path)) return handler.next(options);

      final storage = ref.read(secureStorageServiceProvider.notifier);
      final apiKey = await storage.getApiKey() ?? Env.decartApiKey;

      if (apiKey != null && apiKey.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $apiKey';
      }

      return handler.next(options);
    },
    onError: (error, handler) {
      String message = 'Something went wrong';

      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.connectionError) {
        message = 'No internet connection, please check your connection';
      } else if (error.response?.statusCode == 401 ||
          error.response?.statusCode == 403) {
        message = 'Invalid or missing Decart API key';
      } else if (error.response?.data is Map<String, dynamic>) {
        final data = error.response!.data as Map<String, dynamic>;
        if (data['message'] != null) {
          message = data['message'].toString();
        } else if (data['error'] != null) {
          message = data['error'].toString();
        }
      }

      return handler.next(
        DioException(
          requestOptions: error.requestOptions,
          error: message,
          type: error.type,
          message: message,
          response: error.response,
        ),
      );
    },
  );
}

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../config/env.dart';
import '../constants/app_constants.dart';

part 'api_client.g.dart';

/// Function-style provider — returns a fully configured Dio instance.
/// Consumers read `ref.watch(apiClientProvider)` to get the Dio directly.
///
/// No base URL: every endpoint in `ApiEndpoints` is a full URL, and the
/// repositories also fetch from retailers' image CDNs through this same Dio.
/// No credentials either — none of the app's services take one.
@Riverpod(keepAlive: true)
Dio apiClient(Ref ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: AppConstants.connectionTimeout,
      receiveTimeout: AppConstants.receiveTimeout,
      sendTimeout: AppConstants.sendTimeout,
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );

  dio.interceptors.add(_errorInterceptor());

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
        // A product shot fetched as bytes is a picture, not a payload worth
        // reading. Printed as a list of numbers it runs to thousands of
        // lines, and `debugPrint` throttles every log after it for seconds,
        // which is long enough to make the timing lines lie.
        filter: (options, args) =>
            !args.isResponse ||
            (options.responseType != ResponseType.bytes &&
                args.data is! List<int>),
      ),
    );
  }

  return dio;
}

/// Normalises Dio errors into a human-readable message.
Interceptor _errorInterceptor() {
  return InterceptorsWrapper(
    onError: (error, handler) {
      String message = 'Something went wrong';

      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.connectionError) {
        message = 'No internet connection, please check your connection';
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

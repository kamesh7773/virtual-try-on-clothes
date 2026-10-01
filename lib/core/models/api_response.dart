import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

@immutable
class ApiResponse<T> {
  final bool isSuccess;
  final T? data;
  final String? error;
  final String? message;
  final int? statusCode;

  const ApiResponse({
    required this.isSuccess,
    this.data,
    this.error,
    this.message,
    this.statusCode,
  });

  factory ApiResponse.success(T data, {String? message, int? statusCode}) =>
      ApiResponse(
        isSuccess: true,
        data: data,
        message: message,
        statusCode: statusCode,
      );

  factory ApiResponse.failure(String error, {int? statusCode}) =>
      ApiResponse(isSuccess: false, error: error, statusCode: statusCode);

  @override
  String toString() =>
      'ApiResponse(isSuccess: $isSuccess, message: $message, error: $error, statusCode: $statusCode)';
}

enum ApiErrorType {
  network,
  auth,
  server,
  validation,
  unknown;

  String get message {
    switch (this) {
      case ApiErrorType.network:
        return 'Network connection error';
      case ApiErrorType.auth:
        return 'Authentication failed';
      case ApiErrorType.server:
        return 'Server error';
      case ApiErrorType.validation:
        return 'Validation error';
      case ApiErrorType.unknown:
        return 'Unknown error occurred';
    }
  }
}

ApiErrorType getDioErrorType(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
      return ApiErrorType.network;
    case DioExceptionType.badResponse:
      final code = e.response?.statusCode ?? 0;
      if (code == 401 || code == 403) return ApiErrorType.auth;
      if (code == 422) return ApiErrorType.validation;
      if (code >= 500) return ApiErrorType.server;
      return ApiErrorType.unknown;
    default:
      return ApiErrorType.unknown;
  }
}

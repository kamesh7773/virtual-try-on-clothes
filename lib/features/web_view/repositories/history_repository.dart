import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/config/env.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/models/api_response.dart';
import '../../../core/services/base_api_service.dart';
import '../models/history_payload.dart';
import '../models/url_visit.dart';

part 'history_repository.g.dart';

@riverpod
HistoryRepository historyRepository(Ref ref) => HistoryRepository(ref);

/// Reports a finished browsing flow to the backend.
///
/// The local history stays where it is: this sends a copy, and a send that
/// fails costs the user nothing — the flow is already recorded on the
/// device, and the next one is reported on its own.
class HistoryRepository extends BaseApiService {
  HistoryRepository(super.ref);

  /// Sends [visits] as one flow, and answers with how many it carried.
  Future<ApiResponse<int>> send(List<UrlVisit> visits) async {
    if (visits.isEmpty) {
      return ApiResponse.failure('There is nothing in this flow to send');
    }

    final payload = HistoryPayload(
      sentAt: DateTime.now(),
      app: await _appInfo(),
      device: _deviceInfo(),
      visits: visits,
    );

    try {
      debugPrint(
        '[history] POST ${ApiEndpoints.history} — ${visits.length} visits',
      );
      final response = await post(ApiEndpoints.history, data: payload.toJson());
      debugPrint('[history] ${response.statusCode} — ${response.data}');

      return ApiResponse.success(
        visits.length,
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      debugPrint('[history] failed: ${e.message}');
      return ApiResponse.failure(
        e.message ?? 'The flow could not be reported',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Never fails the send: a batch missing its version number is still worth
  /// far more to the backend than no batch at all.
  Future<AppInfo> _appInfo() async {
    final flavor = _flavor();
    try {
      final info = await PackageInfo.fromPlatform();
      return AppInfo(
        id: info.packageName,
        version: info.version,
        build: info.buildNumber,
        flavor: flavor,
      );
    } catch (e) {
      debugPrint('[history] package info unavailable: $e');
      return AppInfo(
        id: 'unknown',
        version: 'unknown',
        build: 'unknown',
        flavor: flavor,
      );
    }
  }

  /// `Env` throws until the app has initialised it, which every entry point
  /// does — but reporting a flow is the last thing that should be allowed to
  /// bring the app down over it.
  String _flavor() {
    try {
      return Env.environment.name;
    } catch (_) {
      return 'unknown';
    }
  }

  DeviceInfo _deviceInfo() => DeviceInfo(
    platform: Platform.operatingSystem,
    osVersion: Platform.operatingSystemVersion,
  );
}

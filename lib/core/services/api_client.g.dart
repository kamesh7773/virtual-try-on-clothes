// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_client.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Function-style provider — returns a fully configured Dio instance.
/// Consumers read `ref.watch(apiClientProvider)` to get the Dio directly.
///
/// No base URL: every endpoint in `ApiEndpoints` is a full URL, and the
/// repositories also fetch from retailers' image CDNs through this same Dio.
/// No credentials either — none of the app's services take one.

@ProviderFor(apiClient)
final apiClientProvider = ApiClientProvider._();

/// Function-style provider — returns a fully configured Dio instance.
/// Consumers read `ref.watch(apiClientProvider)` to get the Dio directly.
///
/// No base URL: every endpoint in `ApiEndpoints` is a full URL, and the
/// repositories also fetch from retailers' image CDNs through this same Dio.
/// No credentials either — none of the app's services take one.

final class ApiClientProvider extends $FunctionalProvider<Dio, Dio, Dio>
    with $Provider<Dio> {
  /// Function-style provider — returns a fully configured Dio instance.
  /// Consumers read `ref.watch(apiClientProvider)` to get the Dio directly.
  ///
  /// No base URL: every endpoint in `ApiEndpoints` is a full URL, and the
  /// repositories also fetch from retailers' image CDNs through this same Dio.
  /// No credentials either — none of the app's services take one.
  ApiClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'apiClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$apiClientHash();

  @$internal
  @override
  $ProviderElement<Dio> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Dio create(Ref ref) {
    return apiClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Dio value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Dio>(value),
    );
  }
}

String _$apiClientHash() => r'ff68f8923f57180e8e009180f8e4bcc5667a5da3';

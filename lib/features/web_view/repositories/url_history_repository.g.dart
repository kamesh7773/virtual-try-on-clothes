// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'url_history_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(urlHistoryRepository)
final urlHistoryRepositoryProvider = UrlHistoryRepositoryProvider._();

final class UrlHistoryRepositoryProvider
    extends
        $FunctionalProvider<
          UrlHistoryRepository,
          UrlHistoryRepository,
          UrlHistoryRepository
        >
    with $Provider<UrlHistoryRepository> {
  UrlHistoryRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'urlHistoryRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$urlHistoryRepositoryHash();

  @$internal
  @override
  $ProviderElement<UrlHistoryRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  UrlHistoryRepository create(Ref ref) {
    return urlHistoryRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UrlHistoryRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UrlHistoryRepository>(value),
    );
  }
}

String _$urlHistoryRepositoryHash() =>
    r'e0f4e24926f793d57af81df9d6bafec8739dd3a5';

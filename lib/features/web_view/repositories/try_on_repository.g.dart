// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'try_on_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(tryOnRepository)
final tryOnRepositoryProvider = TryOnRepositoryProvider._();

final class TryOnRepositoryProvider
    extends
        $FunctionalProvider<TryOnRepository, TryOnRepository, TryOnRepository>
    with $Provider<TryOnRepository> {
  TryOnRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tryOnRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tryOnRepositoryHash();

  @$internal
  @override
  $ProviderElement<TryOnRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TryOnRepository create(Ref ref) {
    return tryOnRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TryOnRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TryOnRepository>(value),
    );
  }
}

String _$tryOnRepositoryHash() => r'1728b6919786199d9cb369288f6800df1afd67d3';

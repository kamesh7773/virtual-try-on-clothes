// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'style_me_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(styleMeRepository)
final styleMeRepositoryProvider = StyleMeRepositoryProvider._();

final class StyleMeRepositoryProvider
    extends
        $FunctionalProvider<
          StyleMeRepository,
          StyleMeRepository,
          StyleMeRepository
        >
    with $Provider<StyleMeRepository> {
  StyleMeRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'styleMeRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$styleMeRepositoryHash();

  @$internal
  @override
  $ProviderElement<StyleMeRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  StyleMeRepository create(Ref ref) {
    return styleMeRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StyleMeRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StyleMeRepository>(value),
    );
  }
}

String _$styleMeRepositoryHash() => r'00b5b5dedf1d2cad77ccd8a45ed5571b44b74c0b';

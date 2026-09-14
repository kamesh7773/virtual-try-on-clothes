// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'url_history_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Every page the in-app browser has opened, newest first.
///
/// Kept alive for the app's lifetime: the browser writes to it from a page
/// callback, and the history screen reads it much later. A provider that
/// disposed with either one would lose whatever the other had not yet saved.

@ProviderFor(UrlHistoryViewModel)
final urlHistoryViewModelProvider = UrlHistoryViewModelProvider._();

/// Every page the in-app browser has opened, newest first.
///
/// Kept alive for the app's lifetime: the browser writes to it from a page
/// callback, and the history screen reads it much later. A provider that
/// disposed with either one would lose whatever the other had not yet saved.
final class UrlHistoryViewModelProvider
    extends $NotifierProvider<UrlHistoryViewModel, UrlHistoryState> {
  /// Every page the in-app browser has opened, newest first.
  ///
  /// Kept alive for the app's lifetime: the browser writes to it from a page
  /// callback, and the history screen reads it much later. A provider that
  /// disposed with either one would lose whatever the other had not yet saved.
  UrlHistoryViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'urlHistoryViewModelProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$urlHistoryViewModelHash();

  @$internal
  @override
  UrlHistoryViewModel create() => UrlHistoryViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UrlHistoryState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UrlHistoryState>(value),
    );
  }
}

String _$urlHistoryViewModelHash() =>
    r'14e35d88263fd560acb72b8b7c5ed73e91089090';

/// Every page the in-app browser has opened, newest first.
///
/// Kept alive for the app's lifetime: the browser writes to it from a page
/// callback, and the history screen reads it much later. A provider that
/// disposed with either one would lose whatever the other had not yet saved.

abstract class _$UrlHistoryViewModel extends $Notifier<UrlHistoryState> {
  UrlHistoryState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<UrlHistoryState, UrlHistoryState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<UrlHistoryState, UrlHistoryState>,
              UrlHistoryState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

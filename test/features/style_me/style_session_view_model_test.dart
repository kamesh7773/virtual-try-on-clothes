import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:virtual_try_on/core/constants/api_endpoints.dart';
import 'package:virtual_try_on/core/services/api_client.dart';
import 'package:virtual_try_on/features/style_me/models/look_preview.dart';
import 'package:virtual_try_on/features/style_me/models/style_catalog.dart';
import 'package:virtual_try_on/features/style_me/models/style_photo.dart';
import 'package:virtual_try_on/features/style_me/view_models/style_session_view_model.dart';
import 'package:virtual_try_on/features/web_view/models/shop_link.dart';
import 'package:virtual_try_on/features/web_view/models/try_on_category.dart';

import '../../support/test_env.dart';

final _photo = StylePhoto(Uint8List.fromList([1, 2, 3]));

/// Answers each look request with whatever [respond] says for it, hands
/// out photo ids in order, and keeps what was asked.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.respond);

  final FutureOr<(int, Object?)> Function(Map<String, dynamic> body) respond;

  final List<Map<String, dynamic>> looks = [];
  final List<String> deleted = [];
  int uploads = 0;

  /// When set, every upload waits on it before answering.
  Completer<void>? uploadGate;

  /// What the next upload is answered with. `null` means it fails.
  (int, Object?) Function(int upload) uploadResponse = (n) => (
    201,
    {
      'success': true,
      'photo_id': 'ph_$n',
      'expires_at': DateTime.now()
          .add(const Duration(hours: 6))
          .toIso8601String(),
    },
  );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final url = options.uri.toString();
    if (url == ApiEndpoints.stylePhoto) {
      uploads++;
      expect(options.data, isA<FormData>());
      await uploadGate?.future;
      final (status, payload) = uploadResponse(uploads);
      return _json(status, payload);
    }
    if (url.startsWith('${ApiEndpoints.stylePhoto}/')) {
      expect(options.method, 'DELETE');
      deleted.add(url.split('/').last);
      return _json(200, {'success': true});
    }
    final body = options.data as Map<String, dynamic>;
    looks.add(body);
    final (status, payload) = await respond(body);
    return _json(status, payload);
  }

  ResponseBody _json(int status, Object? payload) => ResponseBody.fromString(
    jsonEncode(payload),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

(ProviderContainer, StyleSessionViewModel) _session(_ScriptedAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  final container = ProviderContainer(
    overrides: [apiClientProvider.overrideWithValue(dio)],
  );
  addTearDown(container.dispose);
  final viewModel = container.read(styleSessionViewModelProvider.notifier)
    // Retries wait for nothing here.
    ..wait = (_) async {};
  return (container, viewModel);
}

String _category(Map<String, dynamic> body) => body['category'] as String;

(int, Object?) _ok(Map<String, dynamic> body) => (
  200,
  {
    'image': 'https://cdn.test/${_category(body)}.webp',
    'shop_url': 'https://shop.test/${body['variant']}/${body['dept']}',
  },
);

/// Lets every queued request and the retries behind them run out.
Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  setUpAll(loadTestEnv);

  test('a new photo is uploaded, and nothing is styled from it', () async {
    final adapter = _ScriptedAdapter(_ok);
    final (container, viewModel) = _session(adapter);

    viewModel.usePhoto(_photo);
    await _settle();

    final state = container.read(styleSessionViewModelProvider);
    expect(adapter.uploads, 1);
    expect(state.upload?.id, 'ph_1');
    expect(adapter.looks, isEmpty, reason: 'a look costs a generation');
    expect(state.previews, isEmpty);
  });

  test('the previews screen asks for all four looks at once', () async {
    final adapter = _ScriptedAdapter(_ok);
    final (container, viewModel) = _session(adapter);
    viewModel.usePhoto(_photo);
    await _settle();

    final showing = viewModel.showLooks();
    final loading = container.read(styleSessionViewModelProvider);
    expect(
      loading.previews.values.every((p) => p.isLoading),
      isTrue,
      reason: 'every look shows as loading straight away',
    );
    await showing;

    final state = container.read(styleSessionViewModelProvider);
    expect(adapter.looks, hasLength(4));
    expect(adapter.looks.every((b) => b['photo_id'] == 'ph_1'), isTrue);
    expect(adapter.looks.first['variant'], 'men');
    expect(adapter.looks.first['dept'], 'apparel');
    expect(state.readyCount, 4);
    expect(
      state.previewFor(TryOnCategory.golf),
      LookPreview.done(
        'https://cdn.test/golf.webp',
        shopUrl: Uri.parse('https://shop.test/men/apparel'),
      ),
    );
  });

  test('opening the previews again for the same shelf asks nothing', () async {
    final adapter = _ScriptedAdapter(_ok);
    final (_, viewModel) = _session(adapter);
    viewModel.usePhoto(_photo);
    await viewModel.showLooks();
    adapter.looks.clear();

    viewModel.chooseExplore(StyleCatalog.explore.first);
    viewModel.chooseApparel(StyleCatalog.apparel.first);
    await viewModel.showLooks();

    expect(adapter.looks, isEmpty);
  });

  test('a different shelf is styled afresh, only once it is shown', () async {
    final adapter = _ScriptedAdapter(_ok);
    final (container, viewModel) = _session(adapter);
    viewModel.usePhoto(_photo);
    await viewModel.showLooks();
    adapter.looks.clear();

    viewModel.chooseApparel(StyleCatalog.apparel[1]);
    await _settle();
    expect(adapter.looks, isEmpty, reason: 'choosing is not showing');

    await viewModel.showLooks();

    final state = container.read(styleSessionViewModelProvider);
    expect(state.variant, ShopVariant.women);
    expect(state.heading, "WOMEN'S APPAREL");
    expect(adapter.looks, hasLength(4));
    expect(adapter.looks.every((b) => b['variant'] == 'women'), isTrue);
    expect(
      state.previewFor(TryOnCategory.golf).shopUrl,
      Uri.parse('https://shop.test/women/apparel'),
    );
  });

  test('shoes are styled for the shoe shelf', () async {
    final adapter = _ScriptedAdapter(_ok);
    final (container, viewModel) = _session(adapter);
    viewModel.usePhoto(_photo);

    viewModel.chooseApparel(
      StyleCatalog.apparel.firstWhere((t) => t.label == 'SHOES'),
    );
    await viewModel.showLooks();

    expect(container.read(styleSessionViewModelProvider).dept, ShopDept.shoes);
    expect(adapter.looks.every((b) => b['dept'] == 'shoes'), isTrue);
  });

  ApparelTile row(String label) =>
      StyleCatalog.apparel.firstWhere((t) => t.label == label);

  test("the youth row styles a man's boys and a woman's girls", () async {
    final adapter = _ScriptedAdapter(_ok);
    final (container, viewModel) = _session(adapter);
    viewModel.usePhoto(_photo);

    viewModel.chooseApparel(row('YOUTH APPAREL'));
    expect(
      container.read(styleSessionViewModelProvider).variant,
      ShopVariant.boys,
    );

    viewModel.setAdult(ShopVariant.women);
    viewModel.chooseApparel(row('YOUTH APPAREL'));
    await viewModel.showLooks();

    final state = container.read(styleSessionViewModelProvider);
    expect(state.variant, ShopVariant.girls);
    expect(state.adult, ShopVariant.women, reason: 'still her session');
    expect(adapter.looks.every((b) => b['variant'] == 'girls'), isTrue);
  });

  test('shoes after the youth row are the shopper\'s own', () async {
    final adapter = _ScriptedAdapter(_ok);
    final (container, viewModel) = _session(adapter);
    viewModel.setAdult(ShopVariant.women);
    viewModel.usePhoto(_photo);

    viewModel.chooseApparel(row('YOUTH APPAREL'));
    viewModel.chooseApparel(row('SHOES'));
    await viewModel.showLooks();

    final state = container.read(styleSessionViewModelProvider);
    expect(state.variant, ShopVariant.women);
    expect(state.dept, ShopDept.shoes);
    expect(state.shops, isTrue);
    expect(adapter.looks.every((b) => b['variant'] == 'women'), isTrue);
    expect(adapter.looks.every((b) => b['dept'] == 'shoes'), isTrue);
  });

  test('accessories and the fan shop are styled but lead nowhere', () {
    final (container, viewModel) = _session(_ScriptedAdapter(_ok));

    for (final label in ['ACCESSORIES', 'FAN SHOP']) {
      viewModel.chooseApparel(row('YOUTH APPAREL'));
      viewModel.chooseApparel(row(label));

      final state = container.read(styleSessionViewModelProvider);
      expect(state.heading, label);
      expect(state.shops, isFalse, reason: label);
      expect(state.variant, ShopVariant.men, reason: 'the shopper, not a boy');
      expect(state.dept, ShopDept.apparel);
    }

    viewModel.chooseApparel(row("MEN'S APPAREL"));
    expect(container.read(styleSessionViewModelProvider).shops, isTrue);
  });

  test('a department off the explore screen leads nowhere either', () {
    final (container, viewModel) = _session(_ScriptedAdapter(_ok));
    viewModel.chooseApparel(row('YOUTH APPAREL'));

    viewModel.chooseExplore(
      StyleCatalog.explore.firstWhere((t) => t.label == 'FAN SHOP'),
    );

    final state = container.read(styleSessionViewModelProvider);
    expect(state.shops, isFalse);
    expect(state.variant, ShopVariant.men);
  });

  test('the looks wait for the upload still in flight', () async {
    final adapter = _ScriptedAdapter(_ok)..uploadGate = Completer<void>();
    final (_, viewModel) = _session(adapter);
    viewModel.usePhoto(_photo);

    // Shown before the upload has answered: nothing to send yet.
    final showing = viewModel.showLooks();
    await _settle();
    expect(adapter.looks, isEmpty);

    adapter.uploadGate!.complete();
    await showing;

    expect(adapter.uploads, 1, reason: 'one upload, shared by all four');
    expect(adapter.looks, hasLength(4));
    expect(adapter.looks.every((b) => b['photo_id'] == 'ph_1'), isTrue);
  });

  test('an expired photo id is uploaded again, once', () async {
    final adapter = _ScriptedAdapter((body) {
      if (body['photo_id'] == 'ph_1') {
        return (404, {'code': 'photo_expired', 'message': 'gone'});
      }
      return _ok(body);
    });
    final (container, viewModel) = _session(adapter);
    viewModel.usePhoto(_photo);
    await _settle();

    await viewModel.showLooks();

    expect(adapter.uploads, 2, reason: 'one fresh upload, shared by all');
    expect(container.read(styleSessionViewModelProvider).upload?.id, 'ph_2');
    expect(container.read(styleSessionViewModelProvider).readyCount, 4);
    expect(adapter.looks.where((b) => b['photo_id'] == 'ph_2'), hasLength(4));
  });

  test(
    'a provider failure is tried three times, then shown as failed',
    () async {
      final adapter = _ScriptedAdapter((body) {
        if (_category(body) == 'sports') {
          return (
            422,
            {'code': 'generation_failed', 'message': 'provider down'},
          );
        }
        return _ok(body);
      });
      final (container, viewModel) = _session(adapter);
      viewModel.usePhoto(_photo);

      await viewModel.showLooks();

      final state = container.read(styleSessionViewModelProvider);
      expect(
        adapter.looks.where((b) => _category(b) == 'sports'),
        hasLength(3),
      );
      expect(
        state.previewFor(TryOnCategory.sports).status,
        LookPreviewStatus.error,
      );
      expect(state.readyCount, 3);
    },
  );

  test('a request the service refuses is not asked again', () async {
    final adapter = _ScriptedAdapter(
      (_) => (
        422,
        {
          'message': 'The category field is required.',
          'errors': {
            'category': ['The category field is required.'],
          },
        },
      ),
    );
    final (container, viewModel) = _session(adapter);
    viewModel.usePhoto(_photo);

    await viewModel.showLooks();

    expect(adapter.looks, hasLength(4));
    expect(container.read(styleSessionViewModelProvider).readyCount, 0);
  });

  test('showing the previews again retries only the failed looks', () async {
    var sportsFails = true;
    final adapter = _ScriptedAdapter((body) {
      if (_category(body) == 'sports' && sportsFails) {
        return (422, {'message': 'no', 'errors': {}});
      }
      return _ok(body);
    });
    final (container, viewModel) = _session(adapter);
    viewModel.usePhoto(_photo);
    await viewModel.showLooks();
    adapter.looks.clear();
    sportsFails = false;

    await viewModel.showLooks();

    expect(adapter.looks.map(_category), ['sports']);
    expect(container.read(styleSessionViewModelProvider).readyCount, 4);
  });

  test('a failed upload fails the looks, and is tried again later', () async {
    final adapter = _ScriptedAdapter(_ok);
    adapter.uploadResponse = (_) => (500, {'message': 'boom'});
    final (container, viewModel) = _session(adapter);
    viewModel.usePhoto(_photo);
    await _settle();
    expect(container.read(styleSessionViewModelProvider).upload, isNull);

    await viewModel.showLooks();
    expect(adapter.looks, isEmpty);
    expect(container.read(styleSessionViewModelProvider).readyCount, 0);

    // The network is back: the next opening uploads and styles.
    adapter.uploadResponse = (n) => (
      201,
      {
        'photo_id': 'ph_$n',
        'expires_at': DateTime.now()
            .add(const Duration(hours: 6))
            .toIso8601String(),
      },
    );
    await viewModel.showLooks();
    expect(container.read(styleSessionViewModelProvider).readyCount, 4);
  });

  test('looks for a session that was reset are dropped', () async {
    final pending = Completer<void>();
    final adapter = _ScriptedAdapter((body) async {
      await pending.future;
      return _ok(body);
    });
    final (container, viewModel) = _session(adapter);
    viewModel.usePhoto(_photo);
    await _settle();

    final showing = viewModel.showLooks();
    viewModel.reset();
    pending.complete();
    await showing;
    await _settle();

    final state = container.read(styleSessionViewModelProvider);
    expect(state.photo, isNull);
    expect(state.previews, isEmpty);
    expect(adapter.deleted, ['ph_1'], reason: 'the server can drop it now');
  });

  test('a new photo replaces the old one on the server too', () async {
    final adapter = _ScriptedAdapter(_ok);
    final (container, viewModel) = _session(adapter);
    viewModel.usePhoto(_photo);
    await _settle();

    viewModel.usePhoto(StylePhoto(Uint8List.fromList([4, 5, 6])));
    await _settle();

    expect(adapter.deleted, ['ph_1']);
    expect(container.read(styleSessionViewModelProvider).upload?.id, 'ph_2');
  });

  test('a look sent as a path is resolved against the service host', () async {
    final adapter = _ScriptedAdapter(
      (body) => (
        200,
        {
          'image': '/storage/adcampaign/2026/10/01/${_category(body)}.webp',
          'shop_url': 'https://shop.test/x',
        },
      ),
    );
    final (container, viewModel) = _session(adapter);
    viewModel.usePhoto(_photo);

    await viewModel.showLooks();

    expect(
      container
          .read(styleSessionViewModelProvider)
          .previewFor(TryOnCategory.golf)
          .image,
      'https://mirror.maxaix.com/storage/adcampaign/2026/10/01/golf.webp',
    );
  });

  test('the switch over the camera picks the shopper', () {
    final (container, viewModel) = _session(_ScriptedAdapter(_ok));

    viewModel.setAdult(ShopVariant.women);

    final state = container.read(styleSessionViewModelProvider);
    expect(state.adult, ShopVariant.women);
    expect(state.variant, ShopVariant.women);
  });
}

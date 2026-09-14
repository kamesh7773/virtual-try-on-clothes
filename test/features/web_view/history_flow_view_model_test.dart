import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:virtual_try_on/core/services/api_client.dart';
import 'package:virtual_try_on/features/web_view/models/visit_trigger.dart';
import 'package:virtual_try_on/features/web_view/view_models/history_flow_view_model.dart';
import 'package:virtual_try_on/features/web_view/view_models/url_history_view_model.dart';

import '../../support/stub_http_adapter.dart';

const String _mirror = 'https://mirror.maxaix.com/';
const String _retailer = 'https://www.dickssportinggoods.com/f/mens-golf-polos';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late StubHttpAdapter adapter;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    adapter = StubHttpAdapter(body: {'ok': true});
    container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(Dio()..httpClientAdapter = adapter),
      ],
    );
    container.listen(historyFlowViewModelProvider, (_, _) {});
    container.listen(urlHistoryViewModelProvider, (_, _) {});
  });
  tearDown(() => container.dispose());

  HistoryFlowViewModel flow() =>
      container.read(historyFlowViewModelProvider.notifier);
  UrlHistoryViewModel history() =>
      container.read(urlHistoryViewModelProvider.notifier);

  /// Records a page the way the browser does, and tells the flow about it.
  Future<String> visit(String url, {required bool isOwnSite}) async {
    final id = history().record(
      url: url,
      destinationId: 'mirror',
      trigger: isOwnSite ? VisitTrigger.direct : VisitTrigger.element,
    );
    history().markLoaded(id, title: 'A page', loadTime: Duration.zero);
    await flow().noteVisit(id, isOwnSite: isOwnSite);
    return id;
  }

  Map<String, dynamic> sentBody() =>
      jsonDecode(jsonEncode(adapter.postRequest!.data)) as Map<String, dynamic>;

  test('a flow that never leaves the mirror is not a journey', () async {
    await visit(_mirror, isOwnSite: true);
    await visit('https://mirror.maxaix.com/about', isOwnSite: true);

    await flow().completeFlow();

    expect(adapter.postCount, 0);
    expect(container.read(historyFlowViewModelProvider).sentFlows, 0);
  });

  test('reaching a retailer makes it one', () async {
    await visit(_mirror, isOwnSite: true);
    await visit(_retailer, isOwnSite: false);

    await flow().completeFlow();

    expect(adapter.postCount, 1);
    expect(container.read(historyFlowViewModelProvider).sentFlows, 1);
  });

  test('coming back to the mirror reports the flow just walked', () async {
    await visit(_mirror, isOwnSite: true);
    await visit(_retailer, isOwnSite: false);

    // The user taps back until they are on the mirror again.
    await visit(_mirror, isOwnSite: true);

    expect(adapter.postCount, 1);
    final visits = sentBody()['visits'] as List<dynamic>;
    expect(visits, hasLength(2));
    expect(
      visits.map((visit) => (visit as Map<String, dynamic>)['url']),
      containsAll(<String>[_mirror, _retailer]),
    );
  });

  test('the next flow starts empty, and is its own report', () async {
    await visit(_mirror, isOwnSite: true);
    await visit(_retailer, isOwnSite: false);
    await visit(_mirror, isOwnSite: true);

    await visit(_retailer, isOwnSite: false);
    await flow().completeFlow();

    expect(adapter.postCount, 2);
    final visits = sentBody()['visits'] as List<dynamic>;
    expect(visits, hasLength(2));
  });

  test('the batch carries the envelope the backend was given', () async {
    await visit(_mirror, isOwnSite: true);
    await visit(_retailer, isOwnSite: false);
    await flow().completeFlow();

    final body = sentBody();

    expect(body['schemaVersion'], 1);
    expect(DateTime.tryParse(body['sentAt'] as String)?.isUtc, isTrue);
    expect((body['app'] as Map<String, dynamic>)['flavor'], isNotNull);
    expect((body['device'] as Map<String, dynamic>)['platform'], isNotNull);
  });

  test('every visit is sent with its time in UTC', () async {
    await visit(_mirror, isOwnSite: true);
    await visit(_retailer, isOwnSite: false);
    await flow().completeFlow();

    final visits = sentBody()['visits'] as List<dynamic>;

    for (final visit in visits.cast<Map<String, dynamic>>()) {
      expect(
        DateTime.tryParse(visit['openedAt'] as String)?.isUtc,
        isTrue,
        reason: visit['url'] as String,
      );
    }
  });

  test('a flow already reported is not reported twice', () async {
    await visit(_mirror, isOwnSite: true);
    await visit(_retailer, isOwnSite: false);

    await flow().completeFlow();
    await flow().completeFlow();

    expect(adapter.postCount, 1);
  });

  test(
    'a send that fails leaves the reason, and does not block the next',
    () async {
      adapter = StubHttpAdapter(body: {'error': 'nope'}, statusCode: 500);
      container.dispose();
      container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(
            Dio()..httpClientAdapter = adapter,
          ),
        ],
      );
      container.listen(historyFlowViewModelProvider, (_, _) {});
      container.listen(urlHistoryViewModelProvider, (_, _) {});

      await visit(_mirror, isOwnSite: true);
      await visit(_retailer, isOwnSite: false);
      await flow().completeFlow();

      final state = container.read(historyFlowViewModelProvider);
      expect(state.error, isNotNull);
      expect(state.sentFlows, 0);
      expect(state.visitIds, isEmpty);
    },
  );
}

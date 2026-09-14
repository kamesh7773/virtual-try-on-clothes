import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_try_on/features/web_view/models/history_payload.dart';
import 'package:virtual_try_on/features/web_view/models/url_visit.dart';
import 'package:virtual_try_on/features/web_view/models/visit_trigger.dart';

final _visit = UrlVisit(
  id: '1789234927318000-7',
  url: 'https://www.dickssportinggoods.com/f/mens-golf-polos',
  destinationId: 'mirror',
  openedAt: DateTime.utc(2026, 9, 12, 11, 41, 58, 104),
  title: "Men's Golf Polos | Dick's Sporting Goods",
  loadTime: const Duration(milliseconds: 2140),
  trigger: VisitTrigger.element,
  tappedLabel: 'Golf apparel',
  sourceUrl: 'https://mirror.maxaix.com/',
);

HistoryPayload _payload({List<UrlVisit>? visits}) => HistoryPayload(
  sentAt: DateTime.utc(2026, 9, 12, 11, 42, 7, 318),
  app: const AppInfo(
    id: 'com.maxaix.virtualTryOn.dev',
    version: '1.0.0',
    build: '12',
    flavor: 'development',
  ),
  device: const DeviceInfo(platform: 'android', osVersion: '15'),
  visits: visits ?? [_visit],
);

void main() {
  group('the envelope the backend was promised', () {
    test('names its schema version', () {
      expect(_payload().toJson()['schemaVersion'], 1);
    });

    test('stamps when the batch left, in UTC', () {
      expect(_payload().toJson()['sentAt'], '2026-09-12T11:42:07.318Z');
    });

    test('says what the app and the device were', () {
      final json = _payload().toJson();

      expect(json['app'], {
        'id': 'com.maxaix.virtualTryOn.dev',
        'version': '1.0.0',
        'build': '12',
        'flavor': 'development',
      });
      expect(json['device'], {'platform': 'android', 'osVersion': '15'});
    });

    test('carries the visits of the flow', () {
      final visits = _payload().toJson()['visits'] as List<dynamic>;
      final visit = visits.single as Map<String, dynamic>;

      expect(visit['id'], '1789234927318000-7');
      expect(
        visit['url'],
        'https://www.dickssportinggoods.com/f/mens-golf-polos',
      );
      expect(visit['openedAt'], '2026-09-12T11:41:58.104Z');
      expect(visit['loadTimeMs'], 2140);
      expect(visit['trigger'], 'element');
      expect(visit['tappedLabel'], 'Golf apparel');
      expect(visit['sourceUrl'], 'https://mirror.maxaix.com/');
    });

    test('leaves out what a visit does not have, rather than sending null', () {
      final visits =
          _payload(
                visits: [
                  UrlVisit(
                    id: '1',
                    url: 'https://example.com/a',
                    destinationId: 'mirror',
                    openedAt: DateTime.utc(2026, 9, 12),
                  ),
                ],
              ).toJson()['visits']
              as List<dynamic>;
      final visit = visits.single as Map<String, dynamic>;

      expect(visit.containsKey('title'), isFalse);
      expect(visit.containsKey('loadTimeMs'), isFalse);
      expect(visit.containsKey('error'), isFalse);
      expect(visit.containsKey('tappedLabel'), isFalse);
    });

    test('an empty flow is still a well-formed batch', () {
      expect(_payload(visits: const []).toJson()['visits'], isEmpty);
    });
  });
}

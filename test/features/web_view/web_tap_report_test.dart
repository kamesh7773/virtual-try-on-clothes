import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_try_on/features/web_view/models/visit_trigger.dart';
import 'package:virtual_try_on/features/web_view/models/web_tap_report.dart';

void main() {
  test('reads what the page reported about a tap', () {
    final report = WebTapReport.tryParse(
      jsonEncode({
        'url': 'https://www.dickssportinggoods.com/f/mens-golf-apparel',
        'trigger': 'element',
        'promote': true,
        'label': '  GET THIS STYLE  ',
        'context': "MEN'S APPAREL",
        'sourceUrl': 'https://mirror.maxaix.com/',
        'sourceTitle': 'LiveLook Mirror',
      }),
    );

    expect(report, isNotNull);
    expect(report!.promote, isTrue);
    expect(report.trigger, VisitTrigger.element);
    expect(report.label, 'GET THIS STYLE');
    expect(report.context, "MEN'S APPAREL");
    expect(report.sourceUrl, 'https://mirror.maxaix.com/');
  });

  test('an unknown trigger falls back rather than failing', () {
    final report = WebTapReport.tryParse(
      jsonEncode({'url': 'https://example.com', 'trigger': 'nonsense'}),
    );

    expect(report?.trigger, VisitTrigger.direct);
    expect(report?.promote, isFalse);
  });

  test('anything that is not a report is ignored', () {
    // The bridge is reachable by every script on the page, so junk arriving
    // on it has to be survivable.
    expect(WebTapReport.tryParse('hello'), isNull);
    expect(WebTapReport.tryParse('[]'), isNull);
    expect(WebTapReport.tryParse('{}'), isNull);
    expect(WebTapReport.tryParse(jsonEncode({'url': 42})), isNull);
    expect(WebTapReport.tryParse(jsonEncode({'url': ''})), isNull);
  });

  test('a runaway label is cut rather than carried into the history', () {
    final report = WebTapReport.tryParse(
      jsonEncode({'url': 'https://example.com', 'label': 'x' * 5000}),
    );

    expect(report!.label!.length, 200);
    expect(report.label, endsWith('…'));
  });

  test('empty strings are dropped, not stored as blanks', () {
    final report = WebTapReport.tryParse(
      jsonEncode({'url': 'https://example.com', 'label': '   '}),
    );

    expect(report?.label, isNull);
  });
}

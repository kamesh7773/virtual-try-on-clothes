import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_try_on/features/web_view/models/web_load_failure.dart';
import 'package:webview_flutter/webview_flutter.dart';

const String _loading = 'https://www.dickssportinggoods.com/f/mens-golf-polos';

void main() {
  group('what counts as the page failing', () {
    test('a page that could not be reached', () {
      const error = WebResourceError(
        errorCode: -2,
        description: 'net::ERR_NAME_NOT_RESOLVED',
        errorType: WebResourceErrorType.hostLookup,
        isForMainFrame: true,
        url: _loading,
      );

      expect(isPageFailure(error, loadingUrl: _loading), isTrue);
    });

    test('one that does not say which page it was for', () {
      const error = WebResourceError(
        errorCode: -8,
        description: 'net::ERR_TIMED_OUT',
        errorType: WebResourceErrorType.timeout,
        isForMainFrame: true,
      );

      expect(isPageFailure(error, loadingUrl: _loading), isTrue);
    });
  });

  group('what does not', () {
    test('a navigation iOS cancelled, which is what going back does', () {
      const error = WebResourceError(
        errorCode: -999,
        description: 'cancelled',
        errorType: WebResourceErrorType.unknown,
        isForMainFrame: true,
        url: _loading,
      );

      expect(isPageFailure(error, loadingUrl: _loading), isFalse);
    });

    test('a load Chromium aborted, which is the same thing on Android', () {
      const error = WebResourceError(
        errorCode: -1,
        description: 'net::ERR_ABORTED',
        errorType: WebResourceErrorType.unknown,
        isForMainFrame: true,
        url: _loading,
      );

      expect(isPageFailure(error, loadingUrl: _loading), isFalse);
    });

    test('an error for the page that was just left', () {
      const error = WebResourceError(
        errorCode: -2,
        description: 'net::ERR_NAME_NOT_RESOLVED',
        errorType: WebResourceErrorType.hostLookup,
        isForMainFrame: true,
        url: 'https://www.dickssportinggoods.com/p/left-behind',
      );

      expect(isPageFailure(error, loadingUrl: _loading), isFalse);
    });

    test('anything below the main frame — a tracker, a missing image', () {
      const error = WebResourceError(
        errorCode: -2,
        description: 'net::ERR_BLOCKED_BY_CLIENT',
        errorType: WebResourceErrorType.unknown,
        isForMainFrame: false,
        url: 'https://cdn.example.com/pixel.gif',
      );

      expect(isPageFailure(error, loadingUrl: _loading), isFalse);
    });

    test('one the platform will not say the frame of', () {
      const error = WebResourceError(
        errorCode: -2,
        description: 'net::ERR_FAILED',
        errorType: WebResourceErrorType.unknown,
      );

      expect(isPageFailure(error, loadingUrl: _loading), isFalse);
    });
  });
}

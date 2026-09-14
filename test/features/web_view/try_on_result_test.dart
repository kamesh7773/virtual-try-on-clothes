import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_try_on/features/web_view/models/try_on_result.dart';

void main() {
  group('reading what the try-on service answered', () {
    test('takes the image it sends the try-on as', () {
      final result = TryOnResult.tryParse({
        'success': true,
        'image': 'https://mirror.maxaix.com/images/Golf.png',
        'url': 'https://mirror.maxaix.com/images/Golf.png',
        'test': true,
      });

      expect(result?.url, 'https://mirror.maxaix.com/images/Golf.png');
    });

    test('prefers the image over anything else the body names', () {
      final result = TryOnResult.tryParse({
        'url': 'https://mirror.maxaix.com/tryon/1',
        'image': 'https://mirror.maxaix.com/images/Golf.png',
      });

      expect(result?.url, 'https://mirror.maxaix.com/images/Golf.png');
    });

    test('still reads a body that names only a url', () {
      final result = TryOnResult.tryParse({
        'url': 'https://mirror.maxaix.com/tryon/1',
      });

      expect(result?.url, 'https://mirror.maxaix.com/tryon/1');
    });

    test('reads one nested under data', () {
      final result = TryOnResult.tryParse({
        'data': {'image': '/images/Golf.png'},
      });

      expect(result?.url, '/images/Golf.png');
    });

    test('a job that is only queued has nothing to show yet', () {
      expect(
        TryOnResult.tryParse({'success': true, 'status': 'queued'}),
        isNull,
      );
    });

    test('nothing at all', () {
      expect(TryOnResult.tryParse(null), isNull);
      expect(TryOnResult.tryParse(const {}), isNull);
      expect(TryOnResult.tryParse({'image': ''}), isNull);
      expect(TryOnResult.tryParse({'image': 42}), isNull);
    });
  });
}

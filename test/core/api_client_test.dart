import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:virtual_try_on/core/services/api_client.dart';

void main() {
  setUpAll(() {
    dotenv.loadFromString(envString: 'API_BASE_URL=https://api.decart.ai');
  });

  group('what carries the Decart key', () {
    test('a path is a Decart call — it resolves against their base URL', () {
      expect(isDecartRequest('/v1/client/tokens'), isTrue);
    });

    test('an absolute URL on their host is theirs too', () {
      expect(isDecartRequest('https://api.decart.ai/v1/client/tokens'), isTrue);
    });

    test('a third-party host is not', () {
      // The key is a full account credential: repositories reach the try-on
      // service and retailers' image CDNs through this same Dio, and it must
      // not travel with those.
      expect(isDecartRequest('https://mirror.maxaix.com/api/tryon'), isFalse);
      expect(isDecartRequest('https://dks.scene7.com/is/image/polo'), isFalse);
    });
  });
}

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Stands in for the `.env.*` file an entry point loads. Any test that
/// reaches `ApiEndpoints` — directly, or through a repository — needs it, or
/// the first endpoint read throws.
void loadTestEnv({String apiBaseUrl = 'https://mirror.maxaix.com'}) {
  dotenv.loadFromString(
    envString: 'API_BASE_URL=$apiBaseUrl\nENABLE_LOGS=false',
  );
}

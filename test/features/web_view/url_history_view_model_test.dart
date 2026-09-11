import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:virtual_try_on/features/web_view/repositories/url_history_repository.dart';
import 'package:virtual_try_on/features/web_view/view_models/url_history_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() {
    // An in-memory store, so each test starts with no history behind it.
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
    container.listen(
      urlHistoryViewModelProvider,
      (_, _) {},
      fireImmediately: true,
    );
  });
  tearDown(() => container.dispose());

  UrlHistoryViewModel viewModel() =>
      container.read(urlHistoryViewModelProvider.notifier);

  test('records a visit the moment a page starts loading', () {
    viewModel().record(url: 'https://example.com/a', destinationId: 'mirror');

    final visit = container.read(urlHistoryViewModelProvider).visits.single;
    expect(visit.url, 'https://example.com/a');
    expect(visit.destinationId, 'mirror');
    expect(visit.host, 'example.com');
    // Not loaded, not failed: the page is still on its way.
    expect(visit.isLoading, isTrue);
  });

  test('completes the visit with its title and load time', () {
    final id = viewModel().record(
      url: 'https://example.com',
      destinationId: 'mirror',
    );

    viewModel().markLoaded(
      id,
      title: 'Example',
      loadTime: const Duration(milliseconds: 1200),
    );

    final visit = container.read(urlHistoryViewModelProvider).visits.single;
    expect(visit.title, 'Example');
    expect(visit.loadTime, const Duration(milliseconds: 1200));
    expect(visit.isLoading, isFalse);
    expect(visit.didFail, isFalse);
  });

  test('a failed load is kept, with its reason', () {
    final id = viewModel().record(
      url: 'https://example.com',
      destinationId: 'mirror',
    );

    viewModel().markFailed(id, 'net::ERR_TIMED_OUT');

    final visit = container.read(urlHistoryViewModelProvider).visits.single;
    expect(visit.didFail, isTrue);
    expect(visit.error, 'net::ERR_TIMED_OUT');
  });

  test('newest visits come first', () {
    viewModel().record(url: 'https://a.com', destinationId: 'mirror');
    viewModel().record(url: 'https://b.com', destinationId: 'mirror');

    final visits = container.read(urlHistoryViewModelProvider).visits;
    expect(visits.map((visit) => visit.url), [
      'https://b.com',
      'https://a.com',
    ]);
  });

  test('the oldest visits fall off once the cap is reached', () {
    for (var i = 0; i <= UrlHistoryRepository.maxEntries; i++) {
      viewModel().record(url: 'https://example.com/$i', destinationId: 'm');
    }

    final state = container.read(urlHistoryViewModelProvider);
    expect(state.total, UrlHistoryRepository.maxEntries);
    expect(state.visits.last.url, 'https://example.com/1');
  });

  test('history survives a restart', () async {
    final id = viewModel().record(
      url: 'https://example.com',
      destinationId: 'mirror',
    );
    viewModel().markLoaded(id, title: 'Example');
    // The write is fire-and-forget, so let it reach the store.
    await Future<void>.delayed(Duration.zero);

    final restarted = ProviderContainer();
    addTearDown(restarted.dispose);
    restarted.listen(
      urlHistoryViewModelProvider,
      (_, _) {},
      fireImmediately: true,
    );
    await restarted.read(urlHistoryViewModelProvider.notifier).load();

    final visits = restarted.read(urlHistoryViewModelProvider).visits;
    expect(visits, hasLength(1));
    expect(visits.single.title, 'Example');
  });

  test('clear empties both the list and the store', () async {
    viewModel().record(url: 'https://example.com', destinationId: 'mirror');
    await Future<void>.delayed(Duration.zero);

    await viewModel().clear();

    expect(container.read(urlHistoryViewModelProvider).isEmpty, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(UrlHistoryRepository.storageKey), isNull);
  });
}

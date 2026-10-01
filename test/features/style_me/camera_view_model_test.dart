import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:virtual_try_on/features/try_on/view_models/camera_state.dart';
import 'package:virtual_try_on/features/try_on/view_models/camera_view_model.dart';

/// Stands in for the platform channel so permission outcomes can be scripted.
class _FakePermissionHandler extends PermissionHandlerPlatform {
  PermissionStatus statusToReturn = PermissionStatus.denied;
  PermissionStatus requestResult = PermissionStatus.denied;
  int requestCount = 0;
  bool openedSettings = false;

  @override
  Future<PermissionStatus> checkPermissionStatus(Permission permission) async =>
      statusToReturn;

  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  ) async {
    requestCount++;
    statusToReturn = requestResult;
    return {for (final p in permissions) p: requestResult};
  }

  @override
  Future<bool> openAppSettings() async {
    openedSettings = true;
    return true;
  }

  @override
  Future<ServiceStatus> checkServiceStatus(Permission permission) async =>
      ServiceStatus.enabled;

  @override
  Future<bool> shouldShowRequestPermissionRationale(
    Permission permission,
  ) async =>
      false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakePermissionHandler handler;
  late ProviderContainer container;

  setUp(() {
    handler = _FakePermissionHandler();
    PermissionHandlerPlatform.instance = handler;
    container = ProviderContainer();
    container.listen(cameraViewModelProvider, (_, _) {}, fireImmediately: true);
  });
  tearDown(() => container.dispose());

  CameraViewModel viewModel() =>
      container.read(cameraViewModelProvider.notifier);
  CameraState state() => container.read(cameraViewModelProvider);

  test('starts unknown so the gate does not flash before the first read', () {
    expect(state().permission, CameraPermission.unknown);
    expect(state().isUnknown, isTrue);
  });

  test('refresh reports granted without prompting', () async {
    handler.statusToReturn = PermissionStatus.granted;

    await viewModel().refresh();

    expect(state().isGranted, isTrue);
    expect(handler.requestCount, 0);
  });

  test('request that is allowed flips to granted', () async {
    handler.requestResult = PermissionStatus.granted;

    await viewModel().request();

    expect(state().isGranted, isTrue);
    expect(state().isRequesting, isFalse);
    expect(handler.requestCount, 1);
  });

  test('a plain denial stays re-promptable', () async {
    handler.requestResult = PermissionStatus.denied;

    await viewModel().request();

    expect(state().permission, CameraPermission.denied);
    expect(state().needsSettings, isFalse);
  });

  test('a permanent denial routes to Settings instead of re-prompting',
      () async {
    handler.requestResult = PermissionStatus.permanentlyDenied;

    await viewModel().request();

    expect(state().permission, CameraPermission.permanentlyDenied);
    expect(state().needsSettings, isTrue);
  });

  test('restricted is treated as needing Settings', () async {
    handler.statusToReturn = PermissionStatus.restricted;

    await viewModel().refresh();

    expect(state().needsSettings, isTrue);
  });

  test('concurrent requests do not double-prompt', () async {
    handler.requestResult = PermissionStatus.granted;

    await Future.wait([viewModel().request(), viewModel().request()]);

    expect(handler.requestCount, 1);
  });

  test('openSettings delegates to the platform', () async {
    await viewModel().openSettings();

    expect(handler.openedSettings, isTrue);
  });
}

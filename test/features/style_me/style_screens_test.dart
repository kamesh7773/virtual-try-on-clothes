import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:camera/camera.dart' show CameraPreview;
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:virtual_try_on/core/constants/api_endpoints.dart';
import 'package:virtual_try_on/core/constants/app_constants.dart';
import 'package:virtual_try_on/core/routes/route_arguments.dart';
import 'package:virtual_try_on/core/routes/routes.dart';
import 'package:virtual_try_on/core/services/api_client.dart';
import 'package:virtual_try_on/features/style_me/models/style_catalog.dart';
import 'package:virtual_try_on/features/style_me/models/style_photo.dart';
import 'package:virtual_try_on/features/style_me/view_models/style_session_view_model.dart';
import 'package:virtual_try_on/features/style_me/views/apparel_screen.dart';
import 'package:virtual_try_on/features/style_me/views/explore_screen.dart';
import 'package:virtual_try_on/features/style_me/views/get_ready_screen.dart';
import 'package:virtual_try_on/features/style_me/views/look_previews_screen.dart';
import 'package:virtual_try_on/features/style_me/views/widgets/style_stage.dart';
import 'package:virtual_try_on/features/web_view/models/web_destination.dart';

import '../../support/test_env.dart';

class _Permissions extends PermissionHandlerPlatform {
  _Permissions(this.result);

  final PermissionStatus result;

  @override
  Future<PermissionStatus> checkPermissionStatus(Permission permission) async =>
      result;

  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  ) async => {for (final p in permissions) p: result};

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<ServiceStatus> checkServiceStatus(Permission permission) async =>
      ServiceStatus.enabled;

  @override
  Future<bool> shouldShowRequestPermissionRationale(
    Permission permission,
  ) async => false;
}

/// Golf comes back, athletics is refused, the other two never answer — one
/// card in each state. The photo upload is answered with an id.
class _LooksAdapter implements HttpClientAdapter {
  final Completer<void> never = Completer<void>();

  /// The bodies of the look requests, in order.
  final List<Map<String, dynamic>> looks = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.uri.toString() == ApiEndpoints.stylePhoto) {
      return _json(201, {
        'success': true,
        'photo_id': 'ph_test',
        'expires_at': DateTime.now()
            .add(const Duration(hours: 6))
            .toIso8601String(),
      });
    }
    final body = options.data as Map<String, dynamic>;
    looks.add(body);
    switch (body['category']) {
      case 'golf':
        return _json(200, {
          'image': 'https://cdn.test/golf.webp',
          'shop_url': 'https://www.dickssportinggoods.com/f/from-the-server',
        });
      case 'athletics':
        return _json(422, {
          'message': 'refused',
          'errors': {'x': []},
        });
      default:
        await never.future;
        return _json(200, {});
    }
  }

  ResponseBody _json(int status, Object payload) => ResponseBody.fromString(
    jsonEncode(payload),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

/// A device with no cameras at all.
class _NoCameras extends CameraPlatform {
  @override
  Future<List<CameraDescription>> availableCameras() async => const [];
}

/// A device with a front camera, whose shutter waits on [shot] so a test
/// can look at the screen while the photo is still being taken.
class _FrontCamera extends CameraPlatform {
  final Completer<void> shot = Completer<void>();

  /// When set, the list of cameras waits on it — as it does on a device,
  /// where the answer is some hundreds of milliseconds coming.
  Completer<void>? listing;

  /// Cameras opened, and cameras let go.
  int opened = 0;
  int closed = 0;

  @override
  Future<List<CameraDescription>> availableCameras() async {
    await listing?.future;
    return const [
      CameraDescription(
        name: 'front',
        lensDirection: CameraLensDirection.front,
        sensorOrientation: 270,
      ),
    ];
  }

  @override
  Future<int> createCameraWithSettings(
    CameraDescription cameraDescription,
    MediaSettings? mediaSettings,
  ) async => ++opened;

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {}

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      Stream.value(
        CameraInitializedEvent(
          cameraId,
          1920,
          1080,
          ExposureMode.auto,
          false,
          FocusMode.auto,
          false,
        ),
      );

  // Never closed: the controller reads its first event, and an empty stream
  // has none to give.
  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) =>
      StreamController<CameraErrorEvent>().stream;

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      const Stream.empty();

  @override
  Widget buildPreview(int cameraId) => const SizedBox.expand();

  @override
  Future<XFile> takePicture(int cameraId) async {
    await shot.future;
    return XFile.fromData(_png);
  }

  @override
  Future<void> dispose(int cameraId) async => closed++;
}

final Uint8List _png = img.encodePng(img.Image(width: 4, height: 4));

final Finder _still = find.byWidgetPredicate(
  (widget) => widget is Image && widget.image is ResizeImage,
  skipOffstage: false,
);

/// Lets work that is really asynchronous — a decode, an isolate — get on,
/// then draws a frame, until [done] or the tries run out.
Future<void> _until(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

const _sizes = {'iPhone 14': Size(390, 844), 'iPhone SE (1st)': Size(320, 568)};

Future<(ProviderContainer, List<RouteSettings>, _LooksAdapter)> _pump(
  WidgetTester tester,
  Widget screen,
  Size size, {
  void Function(ProviderContainer container)? before,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final adapter = _LooksAdapter();
  final container = ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue(Dio()..httpClientAdapter = adapter),
    ],
  );
  addTearDown(container.dispose);
  before?.call(container);

  final pushed = <RouteSettings>[];
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        onGenerateRoute: (settings) {
          pushed.add(settings);
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const SizedBox.shrink(),
          );
        },
        home: Builder(
          builder: (context) {
            ScreenUtil.init(
              context,
              designSize: const Size(
                AppConstants.designWidth,
                AppConstants.designHeight,
              ),
            );
            return screen;
          },
        ),
      ),
    ),
  );
  return (container, pushed, adapter);
}

void main() {
  setUpAll(loadTestEnv);

  for (final MapEntry(key: device, value: size) in _sizes.entries) {
    group(device, () {
      testWidgets('explore lays out and opens apparel', (tester) async {
        final (_, pushed, _) = await _pump(tester, const ExploreScreen(), size);
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('APPAREL'), findsOneWidget);
        expect(find.text('FAN SHOP'), findsOneWidget);

        await tester.ensureVisible(find.text('APPAREL'));
        await tester.tap(find.text('APPAREL'));
        await tester.pump();
        expect(pushed.single.name, Routes.styleApparel);
      });

      testWidgets('apparel lays out and opens the looks', (tester) async {
        final (container, pushed, _) = await _pump(
          tester,
          const ApparelScreen(),
          size,
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text("MEN'S APPAREL"), findsOneWidget);
        expect(find.text("WOMEN'S APPAREL"), findsNothing);

        await tester.ensureVisible(find.text('SHOES'));
        await tester.tap(find.text('SHOES'));
        await tester.pump();
        expect(pushed.single.name, Routes.stylePreviews);
        expect(container.read(styleSessionViewModelProvider).heading, 'SHOES');
      });

      testWidgets('the looks show every state and open Dick\'s', (
        tester,
      ) async {
        // The photo was taken on the way here; nothing has been styled yet.
        final (_, pushed, adapter) = await _pump(
          tester,
          const LookPreviewsScreen(),
          size,
          before: (container) => container
              .read(styleSessionViewModelProvider.notifier)
              .usePhoto(StylePhoto(_png)),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 500));

        // Opening the screen is what asked for the looks, all four at once.
        expect(adapter.looks, hasLength(4));
        expect(adapter.looks.every((b) => b['photo_id'] == 'ph_test'), isTrue);
        expect(find.text('1/4'), findsOneWidget);
        expect(find.text('GET THIS STYLE →'), findsOneWidget);

        // A finished look opens the shelf the service named for it.
        await tester.ensureVisible(find.text('Golf'));
        await tester.tap(find.text('Golf'));
        await tester.pump();
        final args = pushed.single.arguments as WebViewScreenArgs;
        expect(pushed.single.name, Routes.webView);
        expect(args.destination, WebDestinations.dicksSportingGoods);
        expect(
          args.initialUrl,
          'https://www.dickssportinggoods.com/f/from-the-server',
        );

        // Back from the shelf. Not settled: the loading cards animate for
        // as long as they load.
        tester.state<NavigatorState>(find.byType(Navigator)).pop();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));

        // A failed look still opens its shelf, from the app's own table.
        pushed.clear();
        await tester.ensureVisible(find.text('Athletics'));
        await tester.tap(find.text('Athletics'));
        await tester.pump();
        expect(
          (pushed.single.arguments as WebViewScreenArgs).initialUrl,
          'https://www.dickssportinggoods.com/f/mens-running-apparel',
        );

        // A look still being made does not open anything.
        pushed.clear();
        await tester.ensureVisible(find.text('Workout'));
        await tester.tap(find.text('Workout'));
        await tester.pump();
        expect(pushed, isEmpty);
      });

      testWidgets('the looks under FAN SHOP open nothing', (tester) async {
        final (_, pushed, adapter) = await _pump(
          tester,
          const LookPreviewsScreen(),
          size,
          before: (container) {
            container.read(styleSessionViewModelProvider.notifier)
              ..usePhoto(StylePhoto(_png))
              ..chooseApparel(
                StyleCatalog.apparel.firstWhere((t) => t.label == 'FAN SHOP'),
              );
          },
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 500));

        // Styled like any other shelf, and shown.
        expect(adapter.looks, hasLength(4));
        expect(find.text('FAN SHOP'), findsOneWidget);
        expect(find.text('1/4'), findsOneWidget);

        // But with no button, and nothing behind the card.
        expect(find.text('GET THIS STYLE →'), findsNothing);
        for (final look in ['Golf', 'Athletics']) {
          await tester.ensureVisible(find.text(look));
          await tester.tap(find.text(look));
          await tester.pump();
        }
        expect(pushed, isEmpty);
      });

      testWidgets('a photo alone styles nothing', (tester) async {
        // The explore screen is where a shopper lands after the photo; no
        // look is asked for until the previews screen itself opens.
        final (_, _, adapter) = await _pump(
          tester,
          const ExploreScreen(),
          size,
          before: (container) => container
              .read(styleSessionViewModelProvider.notifier)
              .usePhoto(StylePhoto(_png)),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(adapter.looks, isEmpty);
      });

      testWidgets('get ready says so when the camera is blocked', (
        tester,
      ) async {
        PermissionHandlerPlatform.instance = _Permissions(
          PermissionStatus.permanentlyDenied,
        );
        await _pump(tester, const GetReadyScreen(), size);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('GET READY!'), findsOneWidget);
        expect(find.textContaining('Camera permission was blocked'), findsOne);
        expect(find.text('OPEN SETTINGS'), findsOneWidget);
        expect(find.text('OR UPLOAD A PHOTO INSTEAD'), findsOneWidget);
      });

      testWidgets('get ready falls back to upload without a camera', (
        tester,
      ) async {
        PermissionHandlerPlatform.instance = _Permissions(
          PermissionStatus.granted,
        );
        CameraPlatform.instance = _NoCameras();
        await _pump(tester, const GetReadyScreen(), size);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // The screen still works, through the upload.
        expect(find.textContaining('No camera found'), findsOne);
        expect(find.text('OR UPLOAD A PHOTO INSTEAD'), findsOneWidget);
        expect(find.text("MEN'S"), findsOneWidget);
      });

      testWidgets('get ready opens the camera once when asked twice', (
        tester,
      ) async {
        PermissionHandlerPlatform.instance = _Permissions(
          PermissionStatus.granted,
        );
        final camera = _FrontCamera()..listing = Completer<void>();
        CameraPlatform.instance = camera;
        await _pump(tester, const GetReadyScreen(), size);
        await tester.pump();

        // The permission prompt closing brings the app back to the front
        // while the camera it allowed is already being opened.
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        camera.listing!.complete();
        await _until(
          tester,
          () => find.byType(CameraPreview).evaluate().isNotEmpty,
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(camera.opened, 1);
        expect(find.textContaining('Could not start'), findsNothing);
      });

      testWidgets('get ready holds the shot still while it is prepared', (
        tester,
      ) async {
        PermissionHandlerPlatform.instance = _Permissions(
          PermissionStatus.granted,
        );
        final camera = _FrontCamera();
        CameraPlatform.instance = camera;
        final (container, pushed, _) = await _pump(
          tester,
          const GetReadyScreen(),
          size,
        );
        await _until(
          tester,
          () => find.byType(CameraPreview).evaluate().isNotEmpty,
        );
        expect(find.byType(CameraPreview), findsOneWidget);

        final shutter = find.byType(StylePressable);
        await tester.ensureVisible(shutter);
        await tester.pump();
        await tester.tap(shutter);
        await tester.pump();

        // The camera has not answered yet: still live, and saying so.
        expect(find.text('HOLD STILL…'), findsOneWidget);
        expect(find.byType(CameraPreview), findsOneWidget);
        expect(_still, findsNothing);

        camera.shot.complete();
        await _until(tester, () => pushed.isNotEmpty);

        // The photo stands where the live picture was, turned the way the
        // mirror showed it, and the camera has been let go.
        expect(pushed.single.name, Routes.styleExplore);
        expect(_still, findsOneWidget);
        expect(
          tester
              .widget<Transform>(
                find
                    .ancestor(
                      of: _still,
                      matching: find.byType(Transform, skipOffstage: false),
                    )
                    .first,
              )
              .transform
              .storage[0],
          -1,
        );
        expect(find.byType(CameraPreview, skipOffstage: false), findsNothing);
        expect(camera.closed, 1);
        expect(container.read(styleSessionViewModelProvider).photo, isNotNull);

        // Back for another: the still is gone and the camera is live again.
        tester.state<NavigatorState>(find.byType(Navigator)).pop();
        await _until(tester, () => camera.opened == 2);
        await _until(
          tester,
          () => find.byType(CameraPreview).evaluate().isNotEmpty,
        );
        expect(_still, findsNothing);
        expect(find.text('TAKE MY PHOTO'), findsOneWidget);

        // The upload the photo set off, seen through to its answer.
        await tester.pump(const Duration(milliseconds: 100));
      });
    });
  }
}

import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/routes/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../view_models/camera_state.dart';
import '../view_models/camera_view_model.dart';
import '../../web_view/models/shop_link.dart';
import '../models/style_catalog.dart';
import '../models/style_photo.dart';
import '../view_models/style_session_view_model.dart';
import 'widgets/capture_frame.dart';
import 'widgets/style_stage.dart';

/// AI BODY SNAPSHOT: asks for the camera, shows the shopper to themselves
/// inside a framing guide, and takes the photo every look is styled from.
///
/// The camera runs only while this screen is on top. It is released before
/// the next screen opens and started again on the way back, so it is never
/// held — or its light left on — behind a screen that is not using it.
class GetReadyScreen extends ConsumerStatefulWidget {
  const GetReadyScreen({super.key});

  @override
  ConsumerState<GetReadyScreen> createState() => _GetReadyScreenState();
}

class _GetReadyScreenState extends ConsumerState<GetReadyScreen>
    with WidgetsBindingObserver {
  CameraController? _camera;

  /// The camera could not start for a reason other than permission.
  String? _cameraError;

  /// Between the shutter and the next screen: shrinking the photo.
  bool _preparing = false;

  /// Between the shutter and the photo coming back from the camera, which
  /// on a slow device is long enough to move in.
  bool _capturing = false;

  /// The photo just taken or picked, shown in place of the live picture
  /// until the next screen opens. A slow device spends seconds shrinking
  /// it, and a camera still running through that reads as a photo that was
  /// never taken.
  ImageProvider? _still;

  /// The preview shows a front camera as a mirror and the photo it takes is
  /// not one; the still is turned to match what was on screen.
  bool _stillMirrored = false;

  /// A photo that could not be used, shown under the shutter.
  String? _photoError;

  /// Whether this screen is the one on top, and so allowed the camera.
  bool _onTop = true;

  /// The camera being opened, while it is. See [_startCamera].
  Future<void>? _opening;

  /// The photo picker is open, or on its way.
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _askForCamera());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    _still?.evict();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The camera plugin asks to be let go while the app is in the
    // background and started again on return.
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _releaseCamera();
    } else if (state == AppLifecycleState.resumed && _onTop) {
      // The shopper may have granted access in Settings meanwhile.
      ref.read(cameraViewModelProvider.notifier).refresh().then((_) {
        if (mounted) _startCamera();
      });
    }
  }

  Future<void> _askForCamera() async {
    final permissions = ref.read(cameraViewModelProvider.notifier);
    await permissions.request();
    if (!mounted) return;
    await _startCamera();
  }

  Future<void> _startCamera() async {
    // One open at a time. The permission prompt closing brings the app back
    // to the front just as the camera it allowed is being opened, and both
    // ask for it. The plugin holds a single camera: two opens at once
    // tangle in it, and the device refuses the result — "No supported
    // surface combination" — on the very first launch.
    while (_opening != null) {
      await _opening;
    }
    if (!mounted || _camera != null || !_onTop || _still != null) return;
    if (!ref.read(cameraViewModelProvider).isGranted) return;

    final opening = _openCamera();
    _opening = opening;
    try {
      await opening;
    } finally {
      _opening = null;
    }
  }

  Future<void> _openCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _setCameraError(
          'No camera found on this device — upload a photo instead.',
        );
        return;
      }
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        front,
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      _camera = controller;
      await controller.initialize();
      if (!mounted || _camera != controller) {
        await controller.dispose();
        return;
      }
      setState(() => _cameraError = null);
    } on CameraException catch (e) {
      debugPrint('[style-me] camera open failed: ${e.code} ${e.description}');
      _camera = null;
      _setCameraError(
        e.code == 'CameraAccessDenied'
            ? 'Camera permission was blocked — allow access, or upload a '
                  'photo instead.'
            : 'Could not start the camera — upload a photo instead.',
      );
    } catch (e) {
      // A device with no camera plugin behind it, or one that failed in a
      // way the plugin does not wrap. The upload still works.
      debugPrint('[style-me] camera unavailable: $e');
      _camera = null;
      _setCameraError('Could not start the camera — upload a photo instead.');
    }
  }

  void _setCameraError(String message) {
    if (mounted) setState(() => _cameraError = message);
  }

  Future<void> _releaseCamera() async {
    final camera = _camera;
    if (camera == null) return;
    _camera = null;
    if (mounted) setState(() {});
    await camera.dispose();
  }

  bool get _cameraReady => _camera?.value.isInitialized ?? false;

  Future<void> _capture() async {
    final camera = _camera;
    if (camera == null || !_cameraReady || _preparing) return;

    setState(() {
      _preparing = true;
      _capturing = true;
      _photoError = null;
    });
    final Uint8List bytes;
    try {
      final shot = await camera.takePicture();
      bytes = await shot.readAsBytes();
    } on CameraException catch (e) {
      debugPrint('[style-me] capture failed: ${e.code} ${e.description}');
      _showPhotoError("We couldn't take that photo — please try again.");
      return;
    }
    if (!mounted) return;

    await _usePhoto(
      bytes,
      mirrored: camera.description.lensDirection == CameraLensDirection.front,
    );
  }

  Future<void> _upload() async {
    // A second tap while the picker is on its way up would ask for another,
    // which the plugin refuses — and the refusal would be shown as an error
    // under a picker that opened perfectly well.
    if (_preparing || _picking) return;
    setState(() => _photoError = null);

    final XFile? picked;
    _picking = true;
    try {
      picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    } catch (e) {
      debugPrint('[style-me] photo picker failed: $e');
      _showPhotoError("We couldn't open your photos — please try again.");
      return;
    } finally {
      _picking = false;
    }
    if (picked == null || !mounted) return;

    setState(() => _preparing = true);
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    await _usePhoto(bytes, mirrored: false);
  }

  Future<void> _usePhoto(Uint8List bytes, {required bool mirrored}) async {
    // Started before the still goes up, so putting it up costs the shopper
    // no time: the shrinking runs on its own isolate meanwhile.
    final preparing = StylePhoto.prepare(bytes);
    await _showStill(bytes, mirrored: mirrored);

    final photo = await preparing;
    if (!mounted) return;
    if (photo == null) {
      _showPhotoError("We couldn't read that photo — please try another one.");
      return;
    }

    ref.read(styleSessionViewModelProvider.notifier).usePhoto(photo);

    _onTop = false;
    await _releaseCamera();
    if (!mounted) return;
    setState(() {
      _preparing = false;
      _capturing = false;
    });

    await Navigator.of(context).pushNamed(Routes.styleExplore);

    _onTop = true;
    if (!mounted) return;
    setState(_dropStill);
    await _startCamera();
  }

  /// Takes the still down, and out of the image cache: it is keyed by its
  /// own bytes, so nothing would ever ask for it again, and a kiosk would
  /// otherwise keep one per shopper.
  void _dropStill() {
    _still?.evict();
    _still = null;
  }

  /// Puts [bytes] up in place of the live picture and lets the camera go —
  /// the shrinking that follows wants the processor and the memory more
  /// than a preview nobody can see does.
  Future<void> _showStill(Uint8List bytes, {required bool mirrored}) async {
    // Decoded at the screen's width: the photo is several times that, and
    // the still never shows larger.
    final view = MediaQuery.of(context);
    final still = ResizeImage(
      MemoryImage(bytes),
      width: (view.size.width * view.devicePixelRatio).round(),
    );

    // Decoded before it is shown, so the live picture stays up until there
    // is something to replace it with. Bytes that will not decode are left
    // to the shrinking to refuse, with the camera still running behind.
    var readable = true;
    await precacheImage(still, context, onError: (_, _) => readable = false);
    if (!mounted) return;
    if (!readable) {
      setState(() => _capturing = false);
      return;
    }

    setState(() {
      _still = still;
      _stillMirrored = mirrored;
      _capturing = false;
    });
    await _releaseCamera();
  }

  void _showPhotoError(String message) {
    if (!mounted) return;
    setState(() {
      _preparing = false;
      _capturing = false;
      _dropStill();
      _photoError = message;
    });
    // The still let the camera go; a second try needs it back.
    _startCamera();
  }

  @override
  Widget build(BuildContext context) {
    final permission = ref.watch(cameraViewModelProvider);
    final session = ref.watch(styleSessionViewModelProvider);
    final camera = _camera;
    final ready = _cameraReady;
    final still = _still;

    final blocked = switch (permission.permission) {
      CameraPermission.denied || CameraPermission.permanentlyDenied =>
        'Camera permission was blocked — allow access, or upload a photo '
            'instead.',
      _ => null,
    };
    final problem = blocked ?? _cameraError;

    return StyleStage(
      glow: false,
      overlay: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0, 0.24, 0.36, 0.48, 0.74, 1],
        colors: [
          Color(0xF0000000),
          Color(0xE6000000),
          Color(0x8C000000),
          Color(0x1F000000),
          Color(0x4D000000),
          Color(0xE6000000),
        ],
      ),
      background: Stack(
        fit: StackFit.expand,
        children: [
          const DriftingBackdrop(),
          AnimatedOpacity(
            opacity: ready && problem == null ? 1 : 0,
            duration: const Duration(milliseconds: 500),
            child: ready && camera != null
                ? ColoredBox(
                    color: Colors.black,
                    child: Center(child: CameraPreview(camera)),
                  )
                : const SizedBox.shrink(),
          ),
          if (still != null)
            ColoredBox(
              color: Colors.black,
              child: Transform.flip(
                flipX: _stillMirrored,
                child: Image(
                  image: still,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  excludeFromSemantics: true,
                ),
              ),
            ),
        ],
      ),
      children: [
        const StyleMasthead(),
        SizedBox(height: 24.r),
        Text(
          'AI BODY SNAPSHOT',
          textAlign: TextAlign.center,
          style: styleText(
            11,
            weight: FontWeight.w600,
            tracking: 0.45,
            color: AppColors.styleTeal,
          ),
        ),
        SizedBox(height: 6.r),
        Text(
          'GET READY!',
          textAlign: TextAlign.center,
          style: styleText(
            40,
            weight: FontWeight.w700,
            tracking: -0.025,
            height: 1,
            shadows: styleTextShadow,
          ),
        ),
        SizedBox(height: 10.r),
        Text(
          'Stand in the frame for a full-body photo.',
          textAlign: TextAlign.center,
          style: styleText(
            13,
            height: 1.35,
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),
        SizedBox(height: 20.r),
        const _Features(),
        SizedBox(height: 16.r),
        _ShoppingFor(
          selected: session.adult,
          onSelected: ref.read(styleSessionViewModelProvider.notifier).setAdult,
        ),
        SizedBox(height: 24.r),
        Expanded(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: 300.r + (problem == null ? _shutterBelowFrame : 0),
            ),
            child: problem != null
                ? _CameraProblem(
                    message: problem,
                    onOpenSettings: permission.needsSettings
                        ? ref
                              .read(cameraViewModelProvider.notifier)
                              .openSettings
                        : null,
                  )
                : Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        bottom: _shutterBelowFrame,
                        child: Stack(
                          clipBehavior: Clip.none,
                          fit: StackFit.expand,
                          children: [
                            CaptureFrame(showNotes: ready && still == null),
                            if (!ready && still == null)
                              const Center(child: _Spinner(size: 36)),
                          ],
                        ),
                      ),
                      // The shutter overlaps the bottom of the frame, as on
                      // the site, and stays inside this box so all of it
                      // answers a tap.
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: _Shutter.height,
                        child: _Shutter(
                          enabled: ready && !_preparing,
                          preparing: _preparing,
                          capturing: _capturing,
                          onTap: _capture,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        SizedBox(height: 4.r),
        if (_photoError != null)
          Padding(
            padding: EdgeInsets.only(top: 8.r),
            child: Text(
              _photoError!,
              textAlign: TextAlign.center,
              style: styleText(
                12,
                weight: FontWeight.w500,
                color: const Color(0xFFFCA5A5),
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.only(top: 8.r),
          child: _UploadInstead(onTap: _preparing ? null : _upload),
        ),
        SizedBox(height: 16.r),
        const _PrivacyCard(),
      ],
    );
  }
}

class _Features extends StatelessWidget {
  const _Features();

  @override
  Widget build(BuildContext context) {
    final divider = BorderSide(color: Colors.white.withValues(alpha: 0.2));
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < StyleCatalog.features.length; i++)
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 6.r),
                decoration: BoxDecoration(
                  border: i == 0 ? null : Border(left: divider),
                ),
                child: Column(
                  children: [
                    SvgPicture.asset(
                      StyleCatalog.features[i].icon,
                      height: 26.r,
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                    SizedBox(height: 8.r),
                    Text(
                      StyleCatalog.features[i].label.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: styleText(
                        10,
                        weight: FontWeight.w600,
                        tracking: 0.1,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ShoppingFor extends StatelessWidget {
  final ShopVariant selected;
  final ValueChanged<ShopVariant> onSelected;

  const _ShoppingFor({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'SHOPPING FOR',
          style: styleText(
            8.5,
            weight: FontWeight.w600,
            tracking: 0.3,
            color: Colors.white.withValues(alpha: 0.55),
          ),
        ),
        SizedBox(height: 8.r),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: EdgeInsets.all(4.r),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final variant in StyleCatalog.adultVariants)
                    Semantics(
                      inMutuallyExclusiveGroup: true,
                      selected: variant == selected,
                      button: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onSelected(variant),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: EdgeInsets.symmetric(
                            horizontal: 22.r,
                            vertical: 11.r,
                          ),
                          decoration: BoxDecoration(
                            color: variant == selected
                                ? AppColors.styleTeal
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            variant.label.toUpperCase(),
                            style: styleText(
                              11,
                              weight: FontWeight.w600,
                              tracking: 0.18,
                              color: variant == selected
                                  ? AppColors.styleOnTeal
                                  : Colors.white.withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// How far the shutter hangs below the framing guide: all of it but the
/// 52 points that overlap the frame.
double get _shutterBelowFrame => _Shutter.height - 52.r;

class _Shutter extends StatelessWidget {
  /// The button, the gap and its one line of label.
  static double get height => 80.r + 12.r + 20.r;

  final bool enabled;
  final bool preparing;

  /// The part of [preparing] in which the camera is still taking the photo.
  final bool capturing;
  final VoidCallback onTap;

  const _Shutter({
    required this.enabled,
    required this.preparing,
    required this.capturing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Opacity(
          opacity: enabled || preparing ? 1 : 0.4,
          child: StylePressable(
            onTap: enabled ? onTap : null,
            pressedScale: 0.95,
            child: Semantics(
              button: true,
              enabled: enabled,
              label: 'Take my photo',
              child: Container(
                width: 80.r,
                height: 80.r,
                padding: EdgeInsets.all(5.r),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.styleTeal,
                  boxShadow: [
                    BoxShadow(color: Color(0x8C16E0C9), blurRadius: 30),
                  ],
                ),
                child: Container(
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF050B09),
                  ),
                  child: preparing
                      ? const _Spinner(size: 28)
                      : Container(
                          width: 58.r,
                          height: 58.r,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 12.r),
        Text(
          capturing
              ? 'HOLD STILL…'
              : preparing
              ? 'PREPARING PHOTO…'
              : 'TAKE MY PHOTO',
          style: styleText(
            11,
            weight: FontWeight.w600,
            tracking: 0.3,
            shadows: styleTextShadow,
          ),
        ),
      ],
    );
  }
}

class _UploadInstead extends StatelessWidget {
  final VoidCallback? onTap;

  const _UploadInstead({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Colors.white.withValues(alpha: onTap == null ? 0.3 : 0.5);
    return Semantics(
      button: true,
      label: 'Upload a photo instead',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 6.r),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.file_upload_outlined, size: 14.r, color: color),
              SizedBox(width: 6.r),
              Flexible(
                child: Text(
                  'OR UPLOAD A PHOTO INSTEAD',
                  textAlign: TextAlign.center,
                  style:
                      styleText(
                        10,
                        weight: FontWeight.w500,
                        tracking: 0.2,
                        color: color,
                      ).copyWith(
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white.withValues(alpha: 0.25),
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.r, vertical: 14.r),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: radius,
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Container(
                width: 28.r,
                height: 28.r,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.styleTeal,
                ),
                child: Icon(
                  Icons.verified_user_outlined,
                  size: 16.r,
                  color: AppColors.styleOnTeal,
                ),
              ),
              SizedBox(width: 14.r),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your photo is used only to create your styling '
                      'preview and is not stored or saved.',
                      style: styleText(
                        12.5,
                        height: 1.35,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    SizedBox(height: 6.r),
                    Text(
                      'PRIVACY FIRST. ALWAYS.',
                      style: styleText(
                        8.5,
                        weight: FontWeight.w600,
                        tracking: 0.22,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CameraProblem extends StatelessWidget {
  final String message;
  final VoidCallback? onOpenSettings;

  const _CameraProblem({required this.message, this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 32.r),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: styleText(
              13,
              height: 1.6,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
          if (onOpenSettings != null) ...[
            SizedBox(height: 16.r),
            OutlinedButton(
              onPressed: onOpenSettings,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.styleTeal,
                side: const BorderSide(color: AppColors.styleTeal),
                shape: const StadiumBorder(),
              ),
              child: Text(
                'OPEN SETTINGS',
                style: styleText(
                  11,
                  weight: FontWeight.w600,
                  tracking: 0.2,
                  color: AppColors.styleTeal,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  final double size;

  const _Spinner({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.r,
      height: size.r,
      child: CircularProgressIndicator(
        strokeWidth: 3,
        color: Colors.white,
        backgroundColor: Colors.white.withValues(alpha: 0.3),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/stage_back_button.dart';
import '../view_models/camera_state.dart';
import '../view_models/camera_view_model.dart';
import '../view_models/catalog_state.dart';
import '../view_models/catalog_view_model.dart';
import '../view_models/session_state.dart';
import '../view_models/session_view_model.dart';
import 'widgets/camera_permission_gate.dart';
import 'widgets/decart_video_view.dart';
import 'widgets/garment_overlay_card.dart';
import 'widgets/garment_strip.dart';
import 'widgets/live_look_wordmark.dart';
import 'widgets/session_controls.dart';

/// The try-on screen.
///
/// Shows the camera until a session starts, then Decart's transformed feed.
/// Changing garments pushes the new prompt and reference image to a live
/// session; while disconnected the catalog still browses freely.
class TryOnScreen extends HookConsumerWidget {
  const TryOnScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogViewModelProvider);
    final catalogViewModel = ref.read(catalogViewModelProvider.notifier);
    final camera = ref.watch(cameraViewModelProvider);
    final cameraViewModel = ref.read(cameraViewModelProvider.notifier);
    final session = ref.watch(sessionViewModelProvider);
    final sessionViewModel = ref.read(sessionViewModelProvider.notifier);

    useEffect(() {
      // flutter_hooks runs an effect synchronously inside initHook, i.e. while
      // this widget is still building. Touching a provider there throws, so
      // the first load has to wait for the frame to finish.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        catalogViewModel.load();
        cameraViewModel.refresh();
      });
      return null;
    }, const []);

    // The SDK owns the camera, so it can only start once access is granted.
    useEffect(() {
      if (camera.isGranted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          sessionViewModel.prepare();
        });
      }
      return null;
    }, [camera.isGranted]);

    // Coming back from the Settings app is the only way a permanent denial
    // gets reversed, and it produces no callback of its own.
    final lifecycle = useAppLifecycleState();
    useEffect(() {
      if (lifecycle == AppLifecycleState.resumed) {
        cameraViewModel.refresh();
      }
      return null;
    }, [lifecycle]);

    // Keep a live session in step with the catalog. Nothing happens when no
    // session is running.
    final selected = catalog.selected;
    useEffect(() {
      if (selected != null && session.isLive) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          sessionViewModel.applyGarment(selected);
        });
      }
      return null;
    }, [selected?.id, session.isLive]);

    return Scaffold(
      backgroundColor: AppColors.stageBackground,
      body: SafeArea(
        child: Column(
          children: [
            const _Masthead(),
            Expanded(
              child: _Body(
                catalog: catalog,
                catalogViewModel: catalogViewModel,
                camera: camera,
                cameraViewModel: cameraViewModel,
                session: session,
                sessionViewModel: sessionViewModel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Masthead extends StatelessWidget {
  const _Masthead();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            children: [
              const LiveLookWordmark(),
              SizedBox(height: 2.h),
              Text(
                'VIRTUAL TRY-ON',
                style: TextStyle(
                  fontSize: 9.sp,
                  color: AppColors.onStageFaint,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
          // Stacked, not stitched into the column: the way back must not cost
          // the stage any height.
          if (Navigator.of(context).canPop())
            const Positioned(left: 0, child: StageBackButton()),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final CatalogState catalog;
  final CatalogViewModel catalogViewModel;
  final CameraState camera;
  final CameraViewModel cameraViewModel;
  final SessionState session;
  final SessionViewModel sessionViewModel;

  const _Body({
    required this.catalog,
    required this.catalogViewModel,
    required this.camera,
    required this.cameraViewModel,
    required this.session,
    required this.sessionViewModel,
  });

  @override
  Widget build(BuildContext context) {
    if (catalog.isLoading) {
      return const Center(child: LoadingWidget());
    }

    if (catalog.error != null) {
      return ErrorView(message: catalog.error!, onRetry: catalogViewModel.load);
    }

    final garment = catalog.selected;
    if (garment == null) {
      return Center(
        child: Text(
          'No garments available',
          style: TextStyle(color: AppColors.onStageMuted, fontSize: 13.sp),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: _Stage(
              camera: camera,
              cameraViewModel: cameraViewModel,
              catalog: catalog,
              catalogViewModel: catalogViewModel,
              session: session,
            ),
          ),
        ),
        if (session.message != null)
          _SessionMessage(
            message: session.message!,
            isError: session.status == DecartStatus.error,
          ),
        _GarmentLabel(
          name: garment.name,
          position: catalog.displayPosition,
          total: catalog.total,
        ),
        if (camera.isGranted)
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 14.h),
            child: SessionControls(
              session: session,
              onStart: () => sessionViewModel.start(garment),
              onStop: sessionViewModel.stop,
            ),
          ),
        GarmentStrip(
          garments: catalog.garments,
          selectedIndex: catalog.selectedIndex,
          onSelect: catalogViewModel.select,
        ),
        SizedBox(height: 16.h),
      ],
    );
  }
}

/// The video area: camera or transformed feed, the garment overlay, and the
/// swipe that moves through the catalog without leaving the mirror.
class _Stage extends StatelessWidget {
  final CameraState camera;
  final CameraViewModel cameraViewModel;
  final CatalogState catalog;
  final CatalogViewModel catalogViewModel;
  final SessionState session;

  const _Stage({
    required this.camera,
    required this.cameraViewModel,
    required this.catalog,
    required this.catalogViewModel,
    required this.session,
  });

  /// Below this speed a drag reads as an accidental brush, not a swipe.
  static const double _swipeVelocityThreshold = 200;

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < _swipeVelocityThreshold) return;
    velocity < 0 ? catalogViewModel.next() : catalogViewModel.previous();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.stageSurface,
        border: Border.all(
          color: session.isLive
              ? AppColors.stageBorderActive
              : AppColors.stageBorder,
        ),
      ),
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            _stageContent(),
            if (camera.isGranted) ...[
              Positioned.fill(
                child: GestureDetector(
                  onHorizontalDragEnd: _handleDragEnd,
                  behavior: HitTestBehavior.translucent,
                ),
              ),
              Positioned(
                top: 12.h,
                right: 12.w,
                child: GarmentOverlayCard(garment: catalog.selected!),
              ),
              if (session.isLive)
                Positioned(top: 12.h, left: 12.w, child: const LiveBadge()),
            ],
            if (session.isConnecting)
              const Positioned.fill(child: _ConnectingOverlay()),
          ],
        ),
      ),
    );
  }

  Widget _stageContent() {
    // Render nothing until the first status read lands, so the gate does not
    // flash before a granted permission resolves.
    if (camera.isUnknown) {
      return const ColoredBox(color: AppColors.stageSurface);
    }

    if (!camera.isGranted) {
      return CameraPermissionGate(
        state: camera,
        onRequest: cameraViewModel.request,
        onOpenSettings: cameraViewModel.openSettings,
      );
    }

    // One view for both feeds. Stacking a local and a remote renderer ran two
    // video pipelines at once — the hidden one still decoded every frame.
    return const DecartVideoView(source: DecartVideoSource.auto);
  }
}

class _ConnectingOverlay extends StatelessWidget {
  const _ConnectingOverlay();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20.r,
              height: 20.r,
              child: const CircularProgressIndicator(
                strokeWidth: 1.5,
                color: AppColors.onStagePrimary,
              ),
            ),
            SizedBox(height: 14.h),
            Text(
              'ENTERING THE TRIAL ROOM',
              style: TextStyle(
                fontSize: 10.sp,
                color: AppColors.onStageSecondary,
                letterSpacing: 2.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionMessage extends StatelessWidget {
  final String message;
  final bool isError;

  const _SessionMessage({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 0),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11.sp,
          height: 1.4,
          color: isError ? AppColors.error : AppColors.onStageMuted,
        ),
      ),
    );
  }
}

class _GarmentLabel extends StatelessWidget {
  final String name;
  final int position;
  final int total;

  const _GarmentLabel({
    required this.name,
    required this.position,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
      child: Column(
        children: [
          Text(
            name.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.sp,
              color: AppColors.onStagePrimary,
              letterSpacing: 1.8,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            '$position / $total',
            style: TextStyle(
              fontSize: 9.sp,
              color: AppColors.onStageFaint,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../core/routes/routes.dart';
import '../models/style_catalog.dart';
import '../view_models/style_session_view_model.dart';
import 'widgets/style_stage.dart';

/// The kiosk's front door: the model video, the brand, and STYLE ME.
///
/// Every shopper starts here, so tapping through clears whatever the last
/// one left behind.
class StyleIntroScreen extends HookConsumerWidget {
  const StyleIntroScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final video = useMemoized(
      () => VideoPlayerController.asset(
        StyleCatalog.introVideo,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      ),
    );
    final playing = useState(false);
    // Whether this screen is the one on top. The video pauses under the
    // others rather than decoding frames nobody can see.
    final onTop = useRef(true);

    useEffect(() {
      void listen() {
        final isPlaying = video.value.isPlaying;
        if (isPlaying && !playing.value) playing.value = true;
      }

      video.addListener(listen);
      video
          .initialize()
          .then((_) async {
            await video.setLooping(true);
            if (onTop.value) await video.play();
          })
          .catchError((Object e) {
            // The poster stays up; the screen works without its video.
            debugPrint('[style-me] intro video failed: $e');
          });
      return () {
        video.removeListener(listen);
        video.dispose();
      };
    }, [video]);

    useOnAppLifecycleStateChange((_, state) {
      if (!video.value.isInitialized) return;
      if (state == AppLifecycleState.resumed) {
        if (onTop.value) video.play();
      } else {
        video.pause();
      }
    });

    Future<void> styleMe() async {
      ref.read(styleSessionViewModelProvider.notifier).reset();
      onTop.value = false;
      if (video.value.isInitialized) await video.pause();
      if (!context.mounted) return;
      await Navigator.of(context).pushNamed(Routes.styleGetReady);
      onTop.value = true;
      if (video.value.isInitialized) {
        await video.seekTo(Duration.zero);
        await video.play();
      }
    }

    return StyleStage(
      glow: false,
      overlay: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0, 0.51],
        colors: [Color(0x99000000), Color(0x00000000)],
      ),
      background: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(StyleCatalog.introPoster, fit: BoxFit.cover),
          AnimatedOpacity(
            opacity: playing.value ? 1 : 0,
            duration: const Duration(milliseconds: 500),
            child: ValueListenableBuilder(
              valueListenable: video,
              builder: (context, value, _) {
                if (!value.isInitialized) return const SizedBox.shrink();
                return FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: value.size.width,
                    height: value.size.height,
                    child: VideoPlayer(video),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      scrollable: false,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) => Stack(
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DicksLogo(height: 52.r),
                      SizedBox(height: 8.r),
                      Text(
                        'SPORTING GOODS',
                        textAlign: TextAlign.center,
                        style: styleText(
                          9.5,
                          weight: FontWeight.w900,
                          tracking: 0.45,
                          shadows: styleTextShadow,
                        ),
                      ),
                    ],
                  ),
                ),
                // Where the site put it: about three quarters of the way
                // down, under the model rather than over them.
                Positioned(
                  top: box.maxHeight * 0.72,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      _StyleMeButton(onTap: styleMe),
                      SizedBox(height: 12.r),
                      Text(
                        'TAP BUTTON TO BEGIN',
                        textAlign: TextAlign.center,
                        style: styleText(
                          8.5,
                          weight: FontWeight.w600,
                          tracking: 0.25,
                          color: Colors.white.withValues(alpha: 0.5),
                          shadows: styleTextShadow,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StyleMeButton extends StatelessWidget {
  final VoidCallback onTap;

  const _StyleMeButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return StylePressable(
      onTap: onTap,
      pressedScale: 0.95,
      child: Semantics(
        button: true,
        label: 'Style Me',
        child: CustomPaint(
          painter: const _OutsideShadow(radius: 16),
          child: ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20.r, vertical: 10.r),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: radius,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'STYLE ME',
                      style: styleText(
                        13,
                        weight: FontWeight.w700,
                        tracking: 0.18,
                      ),
                    ),
                    SizedBox(width: 10.r),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 22.r,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A drop shadow kept outside the button, as CSS draws one. A [BoxShadow]
/// is painted under the box as well, and through the glass it reads as a
/// dark slab.
class _OutsideShadow extends CustomPainter {
  final double radius;

  const _OutsideShadow({required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final button = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    canvas
      ..save()
      ..clipPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect((Offset.zero & size).inflate(80))
          ..addRRect(button),
      )
      ..drawRRect(
        button.shift(const Offset(0, 12)),
        Paint()
          ..color = const Color(0x80000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_OutsideShadow oldDelegate) =>
      oldDelegate.radius != radius;
}

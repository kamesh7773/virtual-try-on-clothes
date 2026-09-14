import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:toastification/toastification.dart';

import 'core/config/env.dart';
import 'core/constants/app_constants.dart';
import 'core/routes/route_generator.dart';
import 'core/services/navigation_service.dart';
import 'core/theme/app_theme.dart';

class VirtualTryOnApp extends ConsumerWidget {
  const VirtualTryOnApp({super.key});

  String get _appTitle {
    if (Env.isDevelopment) return '${AppConstants.appName} Dev';
    if (Env.isStaging) return '${AppConstants.appName} Staging';
    return AppConstants.appName;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navigationService = ref.watch(navigationServiceProvider.notifier);

    return ScreenUtilInit(
      designSize: const Size(
        AppConstants.designWidth,
        AppConstants.designHeight,
      ),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, _) {
        return MaterialApp(
          title: _appTitle,
          debugShowCheckedModeBanner: false,
          navigatorKey: navigationService.navigatorKey,
          theme: AppTheme.light,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en', 'US')],
          locale: const Locale('en', 'US'),
          onGenerateInitialRoutes: (_) => [
            RouteGenerator.generateRoute(RouteGenerator.initialRoute),
          ],
          onGenerateRoute: RouteGenerator.generateRoute,
          builder: (context, child) {
            final content = ToastificationWrapper(
              child: AnnotatedRegion<SystemUiOverlayStyle>(
                value: const SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: Brightness.dark,
                  statusBarBrightness: Brightness.light,
                  systemNavigationBarColor: Colors.white,
                  systemNavigationBarIconBrightness: Brightness.dark,
                ),
                child: child ?? const SizedBox.shrink(),
              ),
            );

            if (Env.isProduction) return content;

            return Banner(
              message: Env.isDevelopment ? 'DEV' : 'STAGING',
              location: BannerLocation.topEnd,
              color: Env.isDevelopment ? Colors.green : Colors.orange,
              child: content,
            );
          },
        );
      },
    );
  }
}

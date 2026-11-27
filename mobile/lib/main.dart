import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'package:syntrace/core/cache/cache_service.dart';
import 'package:syntrace/core/network/api_client.dart';
import 'package:syntrace/core/router/app_router.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:syntrace/core/sync/services/sync_runtime.dart';
import 'package:syntrace/core/sync/services/sync_task_registration.dart';
import 'package:syntrace/core/theme/app_theme.dart';
import 'package:syntrace/core/theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  usePathUrlStrategy();

  ApiClient.instance.init();

  try {
    await CacheService.instance.initialize();
  } catch (_) {
    debugPrint('Local cache initialization failed.');
  }

  await Future.wait<void>([
    ThemeController.initialize(),
    CurrentUserService.instance.loadFromStorage(),
  ]);

  if (CacheService.instance.isInitialized) {
    SyncTaskRegistration.registerAll();
    SyncRuntime.instance.initialize();
  }

  runApp(const SynTraceApp());
}

class SynTraceApp extends StatelessWidget {
  const SynTraceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: SyncRuntime.instance.cubit,
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: ThemeController.themeMode,
        builder: (context, mode, _) {
          return MaterialApp.router(
            title: 'SynTrace',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: mode,
            themeAnimationDuration: const Duration(milliseconds: 180),
            themeAnimationCurve: Curves.easeInOut,
            routerConfig: appRouter,
          );
        },
      ),
    );
  }
}

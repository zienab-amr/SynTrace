import 'package:flutter/material.dart';
import 'package:syntrace/core/network/api_client.dart';
import 'package:syntrace/core/router/app_router.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:syntrace/core/theme/app_theme.dart';
import 'package:syntrace/core/theme/theme_controller.dart';

Future<void> main()
async {
  WidgetsFlutterBinding.ensureInitialized();
  ApiClient.instance.init();
    await CurrentUserService.instance.loadFromStorage();


  runApp(const SynTraceApp());
}

class SynTraceApp extends StatelessWidget
{
  const SynTraceApp({super.key});

  @override
  Widget build(BuildContext context)
  {
    return ValueListenableBuilder<ThemeMode>
    (
      valueListenable: ThemeController.themeMode,
      builder: (context, mode, _)
      {
        return MaterialApp.router(
          title: 'SynTrace',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode, 
          routerConfig: appRouter, 
        );
      },
    );
  }
}
       

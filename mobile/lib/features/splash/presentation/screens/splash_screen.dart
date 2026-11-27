import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:syntrace/core/router/routes.dart';
import 'package:syntrace/core/services/session_navigation_service.dart';
import 'package:syntrace/features/splash/presentation/widgets/splash_logo.dart';
import 'package:syntrace/features/splash/presentation/widgets/network_background.dart';
import 'package:syntrace/features/splash/presentation/widgets/splash_title.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkNavigation();
  }

  Future<void> _checkNavigation() async {
    await Future.delayed(const Duration(milliseconds: 2500));

    if (!mounted) return;

    try {
      final destination = await SessionNavigationService.resolveDestination();

      if (!mounted) return;

      context.go(
        destination == AppRoutes.login ? AppRoutes.intro : destination,
      );
    } catch (_) {
      if (!mounted) return;

      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Stack(
        children: [
          SplashBackground(),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [SplashLogo(), SizedBox(height: 32), SplashTitle()],
            ),
          ),
        ],
      ),
    );
  }
}

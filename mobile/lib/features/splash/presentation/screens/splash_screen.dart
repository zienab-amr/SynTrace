import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:syntrace/core/router/routes.dart';
import 'package:syntrace/core/services/secure_storage_service.dart';
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
      final isLoggedIn = await SecureStorageService.instance.isLoggedIn();
      final isOnboarded = await SecureStorageService.instance
          .isOnboardingCompleted();
      final userRole = await SecureStorageService.instance.getUserRole();

      if (isLoggedIn) {
        if (userRole?.toLowerCase() == 'admin' && !isOnboarded) {
          context.go(AppRoutes.onboarding);
        } else {
          context.go(AppRoutes.dashboard);
        }
      } else {
        context.go(AppRoutes.login);
      }
    } catch (e) {
      if (mounted) context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const SplashBackground(),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                SplashLogo(),
                SizedBox(height: 32),
                SplashTitle(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
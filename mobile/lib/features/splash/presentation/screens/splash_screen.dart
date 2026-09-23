import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:syntrace/core/router/routes.dart';
import 'package:syntrace/features/splash/presentation/widgets/splash_logo.dart';
import 'package:syntrace/features/splash/presentation/widgets/network_background.dart';
import 'package:syntrace/features/splash/presentation/widgets/splash_title.dart';

class SplashScreen extends StatefulWidget 
{
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> 
{
  Timer? _navigationTimer;

 @override
void initState() {
  super.initState();
  
  
  _navigationTimer = Timer(const Duration(milliseconds: 2500), () {
    if (mounted) context.go(AppRoutes.dashboard);
  });
}

  @override
  void dispose() {
    _navigationTimer?.cancel();
    super.dispose();
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
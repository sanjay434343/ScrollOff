import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'pages/splash_screen.dart';
import 'pages/onboarding_page.dart';
import 'pages/permissions_page.dart';
import 'pages/home_page.dart';
import 'pages/settings_page.dart';
import 'pages/apps_list_page.dart';
import 'pages/usage_statistics_page.dart';
import 'pages/blocked_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    DevicePreview(
      enabled: !kReleaseMode, // Only enable in debug mode
      builder: (context) => const ScrollOffApp(),
    ),
  );
}

class ScrollOffApp extends StatelessWidget {
    const ScrollOffApp({super.key});

    @override
    Widget build(BuildContext context) {
      return DynamicColorBuilder(
        builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
          ColorScheme lightColorScheme;
          ColorScheme darkColorScheme;

          if (lightDynamic != null && darkDynamic != null) {
            // Dynamic color is available, use it
            lightColorScheme = lightDynamic.harmonized();
            darkColorScheme = darkDynamic.harmonized();
          } else {
            // Dynamic color is not available, use fallback colors
            lightColorScheme = ColorScheme.fromSeed(seedColor: Colors.blue);
            darkColorScheme = ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            );
          }

          return MaterialApp(
            title: 'ScrollOff',
            // DevicePreview configuration
            useInheritedMediaQuery: true,
            locale: DevicePreview.locale(context),
            builder: DevicePreview.appBuilder,
            theme: ThemeData(
              colorScheme: lightColorScheme,
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              colorScheme: darkColorScheme,
              useMaterial3: true,
            ),
            themeMode: ThemeMode.system,
            home: const NavigationHandler(),
            routes: {
            '/onboarding': (context) => const OnboardingPage(),
            '/permissions': (context) => const PermissionsPage(),
            '/home': (context) => const HomePage(),
            '/settings': (context) => const SettingsPage(),
            '/apps': (context) => const AppsListPage(),
            '/usage': (context) => const UsageStatisticsPage(),
            '/blocked': (context) => const BlockedScreen(appName: 'Unknown App'),
          },
        );
      },
    );
  }
}

class NavigationHandler extends StatefulWidget {
  const NavigationHandler({super.key});

  @override
  State<NavigationHandler> createState() => _NavigationHandlerState();
}

class _NavigationHandlerState extends State<NavigationHandler> {
  static const platform = MethodChannel('com.example.scrolloff/navigation');
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _setupNavigationListener();
    _checkInitialRoute();
  }

  void _setupNavigationListener() {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'navigateToBlockedScreen') {
        final appName = call.arguments['appName'] ?? 'Unknown App';
        final packageName = call.arguments['packageName'] ?? '';
        
        print('Received blocked screen navigation for: $appName');
        
        if (mounted && !_hasNavigated) {
          _hasNavigated = true;
          
          // Navigate to blocked screen
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => BlockedScreen(
                appName: appName,
                motivationalMessage: 'Stay focused! $appName is blocked.',
              ),
            ),
            (route) => false, // Remove all previous routes
          );
        }
      }
    });
  }

  void _checkInitialRoute() async {
    // Add a small delay to ensure platform is ready
    await Future.delayed(const Duration(milliseconds: 500));
    
    final prefs = await SharedPreferences.getInstance();
    final hasCompletedOnboarding = prefs.getBool('completed_onboarding') ?? false;
    final hasGrantedPermissions = prefs.getBool('granted_permissions') ?? false;
    
    if (!mounted || _hasNavigated) return;

    if (!hasCompletedOnboarding) {
      Navigator.pushReplacementNamed(context, '/onboarding');
    } else if (!hasGrantedPermissions) {
      Navigator.pushReplacementNamed(context, '/permissions');
    } else {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SplashScreen(); // Show splash while determining route
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:simple_animations/simple_animations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_settings/app_settings.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:auto_size_text/auto_size_text.dart';

class PermissionsPage extends StatefulWidget {
  const PermissionsPage({super.key});

  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage> {
  static const platform = MethodChannel('com.example.scrolloff/permissions');
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  
  final Map<String, bool> _permissions = {
    'usage_stats': false,
    'overlay': false,
    'notifications': false,
  };

  final List<PermissionItem> _permissionItems = [
    PermissionItem(
      key: 'usage_stats',
      icon: Icons.analytics_rounded,
      title: 'Usage',
      description: 'Monitor apps',
      isRequired: true,
    ),
    PermissionItem(
      key: 'overlay',
      icon: Icons.layers_rounded,
      title: 'Overlay',
      description: 'Block screen',
      isRequired: true,
    ),
    PermissionItem(
      key: 'notifications',
      icon: Icons.notifications_rounded,
      title: 'Alerts',
      description: 'Reminders',
      isRequired: false,
    ),
  ];

  Timer? _permissionTimer;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _checkPermissions();
  }

  @override
  void dispose() {
    _permissionTimer?.cancel();
    super.dispose();
  }

  void _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    
    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  void _checkPermissions() async {
    try {
      // Check usage stats permission
      final usageStatsPermission = await platform.invokeMethod('checkUsageStatsPermission');
      
      // Check overlay permission
      final overlayPermission = await platform.invokeMethod('checkOverlayPermission');
      
      // Check notification permission
      final androidImplementation = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      final notificationPermission = await androidImplementation?.areNotificationsEnabled();
      
      if (mounted) {
        setState(() {
          _permissions['usage_stats'] = usageStatsPermission ?? false;
          _permissions['overlay'] = overlayPermission ?? false;
          _permissions['notifications'] = notificationPermission ?? false;
        });
      }
    } catch (e) {
      // If platform methods fail, keep default false values
      if (mounted) {
        setState(() {
          _permissions['usage_stats'] = false;
          _permissions['overlay'] = false;
          _permissions['notifications'] = false;
        });
      }
    }
  }

  void _requestPermission(String permissionKey) async {
    // First stop monitoring and clear any overlays
    try {
      await platform.invokeMethod('stopMonitoring');
      await platform.invokeMethod('clearOverlays');
    } catch (e) {
      print('Error clearing overlays: $e');
    }

    switch (permissionKey) {
      case 'usage_stats':
        try {
          await platform.invokeMethod('openUsageAccessSettings');
        } catch (e) {
          await AppSettings.openAppSettings();
        }
        break;
        
      case 'overlay':
        try {
          await platform.invokeMethod('openOverlaySettings');
        } catch (e) {
          await AppSettings.openAppSettings();
        }
        break;
        
      case 'notifications':
        _requestNotificationPermission();
        break;
    }
    
    _startPermissionCheckTimer();
  }

  void _startPermissionCheckTimer() {
    // Cancel any existing timer
    _permissionTimer?.cancel();
    
    // Start a new timer that checks permissions every 2 seconds
    _permissionTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      _checkPermissions();
      
      // Stop checking if all required permissions are granted
      if (_allRequiredPermissionsGranted) {
        timer.cancel();
      }
    });
  }

  void _requestNotificationPermission() async {
    final androidImplementation = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      final granted = await androidImplementation.areNotificationsEnabled();
      setState(() {
        _permissions['notifications'] = granted ?? false;
      });
      
      if (!(granted ?? false)) {
        await AppSettings.openAppSettings(type: AppSettingsType.notification);
      }
    }
  }

  void _completeSetup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('permissions_completed', true);
    
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  bool get _allRequiredPermissionsGranted {
    return _permissionItems
        .where((item) => item.isRequired)
        .every((item) => _permissions[item.key] == true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      extendBodyBehindAppBar: true,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: Container(
          // This container will hide the status bar content
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
          ),
          child: SafeArea(
            top: false, // Don't respect status bar area
            child: Padding(
              padding: const EdgeInsets.only(top: 40), // Add manual top padding
              child: CustomAnimationBuilder<double>(
                duration: const Duration(milliseconds: 600),
                tween: Tween(begin: 0.0, end: 1.0),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value.clamp(0.0, 1.0),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          
                          // Header
                          CustomAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 500),
                            delay: const Duration(milliseconds: 100),
                            tween: Tween(begin: 0.0, end: 1.0),
                            curve: Curves.easeOutBack,
                            builder: (context, animValue, child) {
                              return Transform.translate(
                                offset: Offset(0, 30 * (1 - animValue)),
                                child: Opacity(
                                  opacity: animValue.clamp(0.0, 1.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Permissions',
                                        style: TextStyle(
                                          fontSize: 36,
                                          fontWeight: FontWeight.w800,
                                          color: Theme.of(context).colorScheme.onSurface,
                                          height: 1.1,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Grant these permissions to protect your digital wellness',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          
                          const SizedBox(height: 40),
                          
                          // Permission cards
                          Expanded(
                            child: ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              itemCount: _permissionItems.length,
                              itemBuilder: (context, index) {
                                final item = _permissionItems[index];
                                final isGranted = _permissions[item.key] ?? false;
                                
                                return CustomAnimationBuilder<double>(
                                  duration: const Duration(milliseconds: 400),
                                  delay: Duration(milliseconds: 200 + (index * 150)),
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  curve: Curves.easeOutBack,
                                  builder: (context, animValue, child) {
                                    return Transform.translate(
                                      offset: Offset(50 * (1 - animValue), 0),
                                      child: Opacity(
                                        opacity: animValue.clamp(0.0, 1.0),
                                        child: Container(
                                          margin: const EdgeInsets.only(bottom: 12),
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                                            borderRadius: BorderRadius.circular(50),
                                            border: Border.all(
                                              color: isGranted 
                                                  ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
                                                  : Theme.of(context).colorScheme.outline.withOpacity(0.1),
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              // Icon
                                              Container(
                                                width: 40,
                                                height: 40,
                                                decoration: BoxDecoration(
                                                  color: isGranted
                                                      ? Theme.of(context).colorScheme.primary
                                                      : Theme.of(context).colorScheme.surfaceVariant,
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                child: Icon(
                                                  isGranted ? Icons.check_rounded : item.icon,
                                                  color: isGranted
                                                      ? Theme.of(context).colorScheme.onPrimary
                                                      : Theme.of(context).colorScheme.onSurfaceVariant,
                                                  size: 20,
                                                ),
                                              ),
                                              
                                              const SizedBox(width: 12),
                                              
                                              // Content
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Text(
                                                          item.title,
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight: FontWeight.w700,
                                                            color: Theme.of(context).colorScheme.onSurface,
                                                          ),
                                                        ),
                                                        if (item.isRequired) ...[
                                                          const SizedBox(width: 6),
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(
                                                              horizontal: 6,
                                                              vertical: 2,
                                                            ),
                                                            decoration: BoxDecoration(
                                                              color: Theme.of(context).colorScheme.error,
                                                              borderRadius: BorderRadius.circular(8),
                                                            ),
                                                            child: Text(
                                                              '!',
                                                              style: TextStyle(
                                                                fontSize: 8,
                                                                fontWeight: FontWeight.w700,
                                                                color: Theme.of(context).colorScheme.onError,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                    Text(
                                                      item.description,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              
                                              const SizedBox(width: 12),
                                              
                                              // Toggle-style button
                                              GestureDetector(
                                                onTap: isGranted ? null : () => _requestPermission(item.key),
                                                child: AnimatedContainer(
                                                  duration: const Duration(milliseconds: 300),
                                                  width: 48,
                                                  height: 24,
                                                  decoration: BoxDecoration(
                                                    color: isGranted
                                                        ? Theme.of(context).colorScheme.primary
                                                        : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: AnimatedAlign(
                                                    duration: const Duration(milliseconds: 300),
                                                    alignment: isGranted 
                                                        ? Alignment.centerRight 
                                                        : Alignment.centerLeft,
                                                    child: Container(
                                                      width: 20,
                                                      height: 20,
                                                      margin: const EdgeInsets.all(2),
                                                      decoration: BoxDecoration(
                                                        color: Theme.of(context).colorScheme.surface,
                                                        borderRadius: BorderRadius.circular(10),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.black.withOpacity(0.1),
                                                            blurRadius: 2,
                                                            offset: const Offset(0, 1),
                                                          ),
                                                        ],
                                                      ),
                                                      child: Icon(
                                                        isGranted ? Icons.check_rounded : Icons.close_rounded,
                                                        size: 12,
                                                        color: isGranted
                                                            ? Theme.of(context).colorScheme.primary
                                                            : Theme.of(context).colorScheme.outline,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                          
                          // Continue button
                          CustomAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 500),
                            delay: Duration(milliseconds: 400 + (_permissionItems.length * 150)),
                            tween: Tween(begin: 0.0, end: 1.0),
                            curve: Curves.easeOutBack,
                            builder: (context, animValue, child) {
                              return Transform.scale(
                                scale: animValue.clamp(0.0, 1.0),
                                child: Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(top: 20),
                                  child: ElevatedButton(
                                    onPressed: _allRequiredPermissionsGranted ? _completeSetup : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _allRequiredPermissionsGranted 
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(context).colorScheme.surfaceVariant,
                                      foregroundColor: _allRequiredPermissionsGranted 
                                          ? Theme.of(context).colorScheme.onPrimary
                                          : Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(50),
                                      ),
                                      elevation: _allRequiredPermissionsGranted ? 4 : 0,
                                    ),
                                    child: Text(
                                      _allRequiredPermissionsGranted 
                                          ? 'Continue to ScrollOff' 
                                          : 'Grant required permissions first',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PermissionItem {
  final String key;
  final IconData icon;
  final String title;
  final String description;
  final bool isRequired;

  PermissionItem({
    required this.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.isRequired,
  });
}

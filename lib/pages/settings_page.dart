import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:simple_animations/simple_animations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/storage_service.dart';
import 'developer_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with TickerProviderStateMixin {
  bool _backgroundMonitoring = true;
  bool _notificationsEnabled = true;
  bool _autoStart = true;
  bool _alwaysOn = true;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  static const platform = MethodChannel('com.example.scrolloff/monitoring');

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    // Get stored values, defaulting to true for new users
    final backgroundMonitoring = await StorageService.getBackgroundMonitoring() ?? true;
    final notificationsEnabled = await StorageService.getNotificationsEnabled() ?? true;
    final autoStart = await StorageService.getAutoStart() ?? true;
    final alwaysOn = await StorageService.getAlwaysOn() ?? true;
    
    // Set defaults for new users if values don't exist
    if (await StorageService.getBackgroundMonitoring() == null) {
      await StorageService.setBackgroundMonitoring(true);
    }
    if (await StorageService.getNotificationsEnabled() == null) {
      await StorageService.setNotificationsEnabled(true);
    }
    if (await StorageService.getAutoStart() == null) {
      await StorageService.setAutoStart(true);
    }
    if (await StorageService.getAlwaysOn() == null) {
      await StorageService.setAlwaysOn(true);
    }
    
    setState(() {
      _backgroundMonitoring = backgroundMonitoring;
      _notificationsEnabled = notificationsEnabled;
      _autoStart = autoStart;
      _alwaysOn = alwaysOn;
    });
    
    // If this is a new user with always on enabled, activate focus mode
    if (alwaysOn && await StorageService.getFocusMode() == null) {
      await StorageService.setFocusMode(true);
      try {
        await platform.invokeMethod('startMonitoring');
      } catch (e) {
        print('Failed to start monitoring for new user: $e');
      }
    }
  }

  void _saveBoolSetting(String key, bool value) async {
    switch (key) {
      case 'background_monitoring':
        await StorageService.setBackgroundMonitoring(value);
        _handleBackgroundMonitoringToggle(value);
        break;
      case 'notifications_enabled':
        await StorageService.setNotificationsEnabled(value);
        break;
      case 'auto_start':
        await StorageService.setAutoStart(value);
        break;
      case 'always_on':
        await StorageService.setAlwaysOn(value);
        _handleAlwaysOnToggle(value);
        break;
    }
  }

  Future<void> _handleBackgroundMonitoringToggle(bool enabled) async {
    final focusModeEnabled = await StorageService.getFocusMode();
    
    if (enabled && focusModeEnabled) {
      // Start monitoring service if focus mode is active
      try {
        await platform.invokeMethod('startMonitoring');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Background monitoring started'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to start monitoring: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else if (!enabled) {
      // Stop monitoring service
      try {
        await platform.invokeMethod('stopMonitoring');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Background monitoring stopped'),
            ),
          );
        }
      } catch (e) {
        // Silently handle stop errors
      }
    }
  }

  void _handleAlwaysOnToggle(bool enabled) async {
    setState(() {
      _alwaysOn = enabled;
    });
    await StorageService.setAlwaysOn(enabled);
    
    // If enabled, turn on focus mode and background monitoring
    if (enabled) {
      await StorageService.setFocusMode(true);
      await StorageService.setBackgroundMonitoring(true);
      try {
        await platform.invokeMethod('startMonitoring');
      } catch (e) {
        print('Failed to start monitoring: $e');
      }
    }
  }

  void _saveTimeSetting(String hourKey, String minuteKey, TimeOfDay time) async {
    final currentTime = await StorageService.getScheduleTime();
    
    if (hourKey == 'start_hour') {
      await StorageService.setScheduleTime(
        startHour: time.hour,
        startMinute: time.minute,
        endHour: currentTime['endHour']!,
        endMinute: currentTime['endMinute']!,
      );
    } else {
      await StorageService.setScheduleTime(
        startHour: currentTime['startHour']!,
        startMinute: currentTime['startMinute']!,
        endHour: time.hour,
        endMinute: time.minute,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Theme.of(context).brightness == Brightness.dark 
            ? Brightness.light 
            : Brightness.dark,
        systemNavigationBarColor: Theme.of(context).scaffoldBackgroundColor,
        systemNavigationBarIconBrightness: Theme.of(context).brightness == Brightness.dark 
            ? Brightness.light 
            : Brightness.dark,
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          elevation: 0,
          backgroundColor: Colors.transparent,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Theme.of(context).brightness == Brightness.dark 
                ? Brightness.light 
                : Brightness.dark,
          ),
        ),
        body: CustomAnimationBuilder<double>(
          duration: const Duration(milliseconds: 800),
          tween: Tween(begin: 0.0, end: 1.0),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value.clamp(0.0, 1.0),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Always On Section
                  CustomAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 600),
                    delay: const Duration(milliseconds: 100),
                    tween: Tween(begin: 0.0, end: 1.0),
                    curve: Curves.easeOutBack,
                    builder: (context, animValue, child) {
                      return Transform.translate(
                        offset: Offset(0, 30 * (1 - animValue)),
                        child: Opacity(
                          opacity: animValue.clamp(0.0, 1.0),
                          child: _buildSettingCard(
                            icon: Icons.shield_rounded,
                            title: 'Always On',
                            subtitle: 'Keep focus mode permanently enabled',
                            value: _alwaysOn,
                            onChanged: _handleAlwaysOnToggle,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  // Notifications Section
                  CustomAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 600),
                    delay: const Duration(milliseconds: 150),
                    tween: Tween(begin: 0.0, end: 1.0),
                    curve: Curves.easeOutBack,
                    builder: (context, animValue, child) {
                      return Transform.translate(
                        offset: Offset(0, 30 * (1 - animValue)),
                        child: Opacity(
                          opacity: animValue.clamp(0.0, 1.0),
                          child: _buildSettingCard(
                            icon: Icons.notifications,
                            title: 'Show Notifications',
                            subtitle: 'Get alerts when apps are blocked',
                            value: _notificationsEnabled,
                            onChanged: (value) {
                              setState(() {
                                _notificationsEnabled = value;
                              });
                              _saveBoolSetting('notifications_enabled', value);
                            },
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  // Background Monitoring
                  CustomAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 600),
                    delay: const Duration(milliseconds: 200),
                    tween: Tween(begin: 0.0, end: 1.0),
                    curve: Curves.easeOutBack,
                    builder: (context, animValue, child) {
                      return Transform.translate(
                        offset: Offset(0, 30 * (1 - animValue)),
                        child: Opacity(
                          opacity: animValue.clamp(0.0, 1.0),
                          child: _buildSettingCard(
                            icon: Icons.monitor,
                            title: 'Background Monitoring',
                            subtitle: 'Track usage when app is closed',
                            value: _backgroundMonitoring,
                            onChanged: (value) {
                              setState(() {
                                _backgroundMonitoring = value;
                              });
                              _saveBoolSetting('background_monitoring', value);
                            },
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  // Auto Start
                  CustomAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 600),
                    delay: const Duration(milliseconds: 250),
                    tween: Tween(begin: 0.0, end: 1.0),
                    curve: Curves.easeOutBack,
                    builder: (context, animValue, child) {
                      return Transform.translate(
                        offset: Offset(0, 30 * (1 - animValue)),
                        child: Opacity(
                          opacity: animValue.clamp(0.0, 1.0),
                          child: _buildSettingCard(
                            icon: Icons.play_arrow,
                            title: 'Auto Start',
                            subtitle: 'Start blocking on device boot',
                            value: _autoStart,
                            onChanged: (value) {
                              setState(() {
                                _autoStart = value;
                              });
                              _saveBoolSetting('auto_start', value);
                            },
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  // Quick Actions Section
                  CustomAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 600),
                    delay: const Duration(milliseconds: 300),
                    tween: Tween(begin: 0.0, end: 1.0),
                    curve: Curves.easeOutBack,
                    builder: (context, animValue, child) {
                      return Transform.translate(
                        offset: Offset(0, 30 * (1 - animValue)),
                        child: Opacity(
                          opacity: animValue.clamp(0.0, 1.0),
                          child: _buildQuickActionsCard(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  // Developer Section
                  CustomAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 600),
                    delay: const Duration(milliseconds: 350),
                    tween: Tween(begin: 0.0, end: 1.0),
                    curve: Curves.easeOutBack,
                    builder: (context, animValue, child) {
                      return Transform.translate(
                        offset: Offset(0, 30 * (1 - animValue)),
                        child: Opacity(
                          opacity: animValue.clamp(0.0, 1.0),
                          child: _buildDeveloperCard(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    bool showTimeSettings = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(
          color: value 
              ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
              : Theme.of(context).colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Icon in circular container - moved right
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value 
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline.withOpacity(0.5),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          // Setting info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AutoSizeText(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                AutoSizeText(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                  maxLines: 1,
                  minFontSize: 9,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Custom toggle switch
          _buildCustomToggle(value, (newValue) {
            HapticFeedback.lightImpact();
            onChanged(newValue);
          }),
        ],
      ),
    );
  }

  Widget _buildCustomToggle(bool value, Function(bool) onChanged) {
    return StatefulBuilder(
      builder: (context, setState) {
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            onChanged(!value);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250), // Slightly longer for smoother animation
            curve: Curves.easeInOutCubic, // Fluid curve
            width: 56,
            height: 30,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30), // Perfect pill switch
              color: value 
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline.withOpacity(0.3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 250), // Smooth slide animation
                  curve: Curves.easeInOutCubic, // Fluid curve
                  left: value ? 28 : 2,
                  top: 2,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200), // Smooth size/color animation
                    curve: Curves.easeInOut,
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150), // Quick icon transition
                      transitionBuilder: (Widget child, Animation<double> animation) {
                        return RotationTransition(
                          turns: animation,
                          child: child,
                        );
                      },
                      child: Icon(
                        value ? Icons.check_rounded : Icons.close_rounded,
                        key: ValueKey(value), // Key for AnimatedSwitcher
                        size: 16,
                        color: value 
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimeSelector(String label, TimeOfDay time, Function(TimeOfDay) onChanged) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.selectionClick();
        final selectedTime = await showTimePicker(
          context: context,
          initialTime: time,
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                timePickerTheme: TimePickerThemeData(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30), // Perfect pill shape
                  ),
                ),
              ),
              child: child!,
            );
          },
        );
        if (selectedTime != null) {
          HapticFeedback.lightImpact(); // Haptic when time is selected
          onChanged(selectedTime);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200), // Smooth hover/press animation
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // Increased padding
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3), // Lighter background, no white card
          borderRadius: BorderRadius.circular(8), // Square shape when scheduled focus is active
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.2), // Lighter border
          ),
        ),
        child: Column(
          children: [
            AutoSizeText(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              minFontSize: 8,
            ),
            const SizedBox(height: 4), // Increased spacing
            AutoSizeText(
              time.format(context),
              style: TextStyle(
                fontSize: 14, // Increased font size
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              minFontSize: 12,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Icon(
              Icons.tune,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AutoSizeText(
              'Quick Actions',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            'Permissions',
            Icons.security,
            () {
              HapticFeedback.selectionClick();
              Navigator.pushNamed(context, '/permissions');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 6),
            AutoSizeText(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
              maxLines: 1,
              minFontSize: 9,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeveloperCard() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const DeveloperPage()),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Icon(
                Icons.code,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AutoSizeText(
                    'Developer',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 1,
                  ),
                  const SizedBox(height: 2),
                  AutoSizeText(
                    'About the developer',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                    maxLines: 1,
                    minFontSize: 9,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }
}

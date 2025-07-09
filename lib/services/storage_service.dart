import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class StorageService {
  static const String _blockedAppsKey = 'scrolloff_blocked_apps';
  static const String _focusModeKey = 'scrolloff_focus_mode_enabled';
  static const String _backgroundMonitoringKey = 'scrolloff_background_monitoring';
  static const String _scheduledFocusKey = 'scrolloff_scheduled_focus';
  static const String _notificationsKey = 'scrolloff_notifications_enabled';
  static const String _showWarningsKey = 'scrolloff_show_warnings';
  static const String _autoStartKey = 'scrolloff_auto_start';
  static const String _strictModeKey = 'scrolloff_strict_mode';
  static const String _startTimeKey = 'scrolloff_start_time';
  static const String _endTimeKey = 'scrolloff_end_time';
  static const String _customAppsKey = 'scrolloff_custom_apps';
  static const String _onboardingKey = 'scrolloff_completed_onboarding';
  static const String _permissionsKey = 'scrolloff_granted_permissions';
  static const String _loginKey = 'scrolloff_is_logged_in';
  static const String _alwaysOnKey = 'scrolloff_always_on';
  
  static const platform = MethodChannel('com.example.scrolloff/storage');
  
  // Blocked Apps Management
  static Future<Set<String>> getBlockedApps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Try to get the string list with proper error handling
      List<String>? blockedList;
      try {
        blockedList = prefs.getStringList(_blockedAppsKey);
      } catch (e) {
        print('StorageService: Error getting string list, trying fallback: $e');
        // Fallback: try to get as string and parse
        final blockedString = prefs.getString(_blockedAppsKey);
        if (blockedString != null && blockedString.isNotEmpty) {
          blockedList = blockedString.split(',').where((s) => s.isNotEmpty).toList();
        }
      }
      
      final blockedSet = (blockedList ?? []).toSet();
      
      print('StorageService: getBlockedApps returning: $blockedSet');
      
      return blockedSet;
    } catch (e) {
      print('StorageService: Critical error in getBlockedApps: $e');
      return <String>{}; // Return empty set as fallback
    }
  }
  
  static Future<void> setBlockedApps(Set<String> blockedApps) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final blockedList = blockedApps.toList();
      
      // Clear any existing data first
      await prefs.remove(_blockedAppsKey);
      
      // Set the new data
      final success = await prefs.setStringList(_blockedAppsKey, blockedList);
      
      if (!success) {
        print('StorageService: Failed to save blocked apps, trying string fallback');
        // Fallback: save as comma-separated string
        await prefs.setString(_blockedAppsKey, blockedList.join(','));
      }
      
      print('StorageService: setBlockedApps saved: $blockedList');
      
      // Sync with native Android immediately
      try {
        await platform.invokeMethod('syncBlockedApps', {'blockedApps': blockedList});
        print('StorageService: Successfully synced blocked apps to native');
      } catch (e) {
        print('StorageService: Failed to sync blocked apps to native: $e');
      }
    } catch (e) {
      print('StorageService: Critical error in setBlockedApps: $e');
    }
  }
  
  static Future<void> addBlockedApp(String packageName) async {
    final currentBlocked = await getBlockedApps();
    currentBlocked.add(packageName);
    await setBlockedApps(currentBlocked);
    print('StorageService: Added $packageName to blocked apps. Total: ${currentBlocked.length}');
  }
  
  static Future<void> removeBlockedApp(String packageName) async {
    final currentBlocked = await getBlockedApps();
    currentBlocked.remove(packageName);
    await setBlockedApps(currentBlocked);
    print('StorageService: Removed $packageName from blocked apps. Total: ${currentBlocked.length}');
  }
  
  static Future<bool> isAppBlocked(String packageName) async {
    final blockedApps = await getBlockedApps();
    return blockedApps.contains(packageName);
  }
  
  // Focus Mode Settings
  static Future<bool> getFocusMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_focusModeKey) ?? false;
  }
  
  static Future<void> setFocusMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_focusModeKey, enabled);
    
    // Sync with native
    try {
      await platform.invokeMethod('syncFocusMode', {'enabled': enabled});
    } catch (e) {
      print('Failed to sync focus mode to native: $e');
    }
  }
  
  // Background Monitoring
  static Future<bool> getBackgroundMonitoring() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_backgroundMonitoringKey) ?? false;
  }
  
  static Future<void> setBackgroundMonitoring(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_backgroundMonitoringKey, enabled);
  }
  
  // Scheduled Focus
  static Future<bool> getScheduledFocus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_scheduledFocusKey) ?? false;
  }
  
  static Future<void> setScheduledFocus(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scheduledFocusKey, enabled);
  }
  
  // Notifications
  static Future<bool> getNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationsKey) ?? true;
  }
  
  static Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsKey, enabled);
  }
  
  // Show Warnings
  static Future<bool> getShowWarnings() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showWarningsKey) ?? true;
  }
  
  static Future<void> setShowWarnings(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showWarningsKey, enabled);
  }
  
  // Auto Start
  static Future<bool> getAutoStart() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoStartKey) ?? false;
  }
  
  static Future<void> setAutoStart(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoStartKey, enabled);
  }
  
  // Strict Mode
  static Future<bool> getStrictMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_strictModeKey) ?? false;
  }
  
  static Future<void> setStrictMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_strictModeKey, enabled);
  }
  
  // Time Settings
  static Future<Map<String, int>> getScheduleTime() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'startHour': prefs.getInt('${_startTimeKey}_hour') ?? 9,
      'startMinute': prefs.getInt('${_startTimeKey}_minute') ?? 0,
      'endHour': prefs.getInt('${_endTimeKey}_hour') ?? 17,
      'endMinute': prefs.getInt('${_endTimeKey}_minute') ?? 0,
    };
  }
  
  static Future<void> setScheduleTime({
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('${_startTimeKey}_hour', startHour);
    await prefs.setInt('${_startTimeKey}_minute', startMinute);
    await prefs.setInt('${_endTimeKey}_hour', endHour);
    await prefs.setInt('${_endTimeKey}_minute', endMinute);
  }
  
  // Custom Apps
  static Future<List<Map<String, String>>> getCustomApps() async {
    final prefs = await SharedPreferences.getInstance();
    final customAppsJson = prefs.getStringList(_customAppsKey) ?? [];
    return customAppsJson.map((jsonString) {
      final Map<String, dynamic> data = Map<String, dynamic>.from(
        Uri.splitQueryString(jsonString)
      );
      return Map<String, String>.from(data);
    }).toList();
  }
  
  static Future<void> setCustomApps(List<Map<String, String>> customApps) async {
    final prefs = await SharedPreferences.getInstance();
    final customAppsJson = customApps.map((app) {
      return Uri(queryParameters: app).query;
    }).toList();
    await prefs.setStringList(_customAppsKey, customAppsJson);
  }
  
  // Onboarding & Setup
  static Future<bool> getCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingKey) ?? false;
  }
  
  static Future<void> setCompletedOnboarding(bool completed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, completed);
  }
  
  static Future<bool> getGrantedPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_permissionsKey) ?? false;
  }
  
  static Future<void> setGrantedPermissions(bool granted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_permissionsKey, granted);
  }
  
  static Future<bool> getIsLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_loginKey) ?? false;
  }
  
  static Future<void> setIsLoggedIn(bool loggedIn) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loginKey, loggedIn);
  }
  
  // Always On Setting
  static Future<bool> getAlwaysOn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_alwaysOnKey) ?? false;
  }

  static Future<void> setAlwaysOn(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_alwaysOnKey, enabled);
    
    // If always on is enabled, also enable focus mode
    if (enabled) {
      await setFocusMode(true);
      await setBackgroundMonitoring(true);
    }
  }
  
  // Clear all data (for logout/reset)
  static Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    // Sync clear with native
    try {
      await platform.invokeMethod('clearAllData');
    } catch (e) {
      print('Failed to clear native data: $e');
    }
  }
  
  // Initialize storage with safe defaults
  static Future<void> initializeStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check if blocked apps key exists, if not initialize it
      if (!prefs.containsKey(_blockedAppsKey)) {
        await prefs.setStringList(_blockedAppsKey, []);
        print('StorageService: Initialized blocked apps with empty list');
      }
      
      // Sync with native to ensure consistency
      final blockedApps = await getBlockedApps();
      try {
        await platform.invokeMethod('syncBlockedApps', {'blockedApps': blockedApps.toList()});
        print('StorageService: Initial sync with native completed');
      } catch (e) {
        print('StorageService: Failed initial sync with native: $e');
      }
      
    } catch (e) {
      print('StorageService: Error initializing storage: $e');
    }
  }
}

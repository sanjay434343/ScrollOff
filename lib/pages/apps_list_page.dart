import 'dart:convert';
import 'dart:typed_data';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'package:simple_animations/simple_animations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/storage_service.dart';

class AppsListPage extends StatefulWidget {
  const AppsListPage({super.key});

  @override
  State<AppsListPage> createState() => _AppsListPageState();
}

class _AppsListPageState extends State<AppsListPage> with TickerProviderStateMixin {
  static const platform = MethodChannel('com.example.scrolloff/apps');

  // Predefined social media apps to check for
  final Map<String, SocialMediaAppTemplate> _socialMediaTemplates = {
    'com.instagram.android': SocialMediaAppTemplate('Instagram', Icons.camera_alt),
    'com.google.android.youtube': SocialMediaAppTemplate('YouTube', Icons.play_arrow),
    'app.revanced.android.youtube': SocialMediaAppTemplate('YouTube ReVanced', Icons.play_arrow),
    'com.google.android.apps.youtube.music': SocialMediaAppTemplate('YouTube Music', Icons.music_note),
    'com.facebook.katana': SocialMediaAppTemplate('Facebook', Icons.facebook),
    'com.twitter.android': SocialMediaAppTemplate('X (Twitter)', Icons.alternate_email),
    'com.snapchat.android': SocialMediaAppTemplate('Snapchat', Icons.camera),
    'com.zhiliaoapp.musically': SocialMediaAppTemplate('TikTok', Icons.music_note),
    'com.reddit.frontpage': SocialMediaAppTemplate('Reddit', Icons.forum),
  };

  // Default apps that should always appear even if not detected
  final Map<String, SocialMediaAppTemplate> _defaultApps = {
    'com.google.android.youtube': SocialMediaAppTemplate('YouTube', Icons.play_arrow, blocked: true),
    'app.revanced.android.youtube': SocialMediaAppTemplate('YouTube ReVanced', Icons.play_arrow, blocked: true),
    'com.instagram.android': SocialMediaAppTemplate('Instagram', Icons.camera_alt, blocked: true),
    'com.facebook.katana': SocialMediaAppTemplate('Facebook', Icons.facebook, blocked: true),
    'com.zhiliaoapp.musically': SocialMediaAppTemplate('TikTok', Icons.music_note, blocked: true),
    'com.twitter.android': SocialMediaAppTemplate('X (Twitter)', Icons.alternate_email, blocked: true),
    'com.snapchat.android': SocialMediaAppTemplate('Snapchat', Icons.camera, blocked: true),
    'com.reddit.frontpage': SocialMediaAppTemplate('Reddit', Icons.forum, blocked: true),
    'com.google.android.apps.youtube.music': SocialMediaAppTemplate('YouTube Music', Icons.music_note, blocked: true),
  };

  List<DetectedSocialApp> _installedSocialApps = [];
  List<Map<String, String>> _allInstalledApps = [];
  List<DetectedSocialApp> _customAddedApps = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _hasLoadedOnce = false;

  late AnimationController _headerAnimationController;

  // Add caching for decoded icons
  final Map<String, Widget> _iconCache = {};

  final TextEditingController _customAppController = TextEditingController();

  @override
  void initState() {
    super.initState();
    
    _headerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Remove the post-frame callback animation to reduce initial load time
    _loadInstalledApps();
  }

  @override
  void dispose() {
    _headerAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadInstalledApps() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      print('AppsListPage: Starting to load installed apps...');

      // Load saved custom apps and blocking states first
      await _loadSavedData();

      // Get installed apps from native Android code
      print('AppsListPage: Calling platform.invokeMethod(getInstalledApps)...');
      
      final dynamic result = await platform.invokeMethod('getInstalledApps');
      print('AppsListPage: Received result type: ${result.runtimeType}');
      
      // Ensure result is a List
      List<dynamic> installedApps;
      if (result is List) {
        installedApps = result;
      } else {
        throw Exception('Expected List but got ${result.runtimeType}: $result');
      }
      
      print('AppsListPage: Processing ${installedApps.length} apps...');
      
      _allInstalledApps = installedApps
          .map((app) {
            try {
              return Map<String, String>.from(app as Map);
            } catch (e) {
              print('AppsListPage: Error converting app: $app, Error: $e');
              return <String, String>{};
            }
          })
          .where((app) => app.isNotEmpty && !_isSystemApp(app['packageName'] ?? ''))
          .toList();
      
      print('AppsListPage: Filtered to ${_allInstalledApps.length} user apps');
      
      List<DetectedSocialApp> socialApps = [];
      Set<String> addedPackages = <String>{};
      
      // Build list of only default apps that are actually installed
      for (var entry in _defaultApps.entries) {
        final packageName = entry.key;
        final template = entry.value;
        final appMap = installedApps.firstWhere(
          (app) => (app as Map)['packageName'] == packageName,
          orElse: () => <String, String>{},
        );
        if (appMap.isNotEmpty) {
          // For new users, use the template's default blocked state (true)
          // For existing users, preserve their saved preference
          final savedBlockStatus = await _getSavedBlockStatus(packageName);
          final isBlocked = savedBlockStatus ?? template.blocked;
          
          // If this is a new user (no saved status), set the default
          if (savedBlockStatus == null) {
            await _saveBlockStatus(packageName, template.blocked);
          }
          
          socialApps.add(DetectedSocialApp(
            name: template.displayName,
            packageName: packageName,
            icon: template.icon,
            appName: appMap['appName']?.toString() ?? template.displayName,
            iconBase64: appMap['iconBase64']?.toString() ?? '',
            isBlocked: isBlocked,
            isInstalled: true,
          ));
          addedPackages.add(packageName);
        }
      }
      
      // Then, add other detected social media apps that aren't already added
      for (var appData in installedApps) {
        final Map<String, dynamic> app = Map<String, dynamic>.from(appData as Map);
        final String packageName = app['packageName']?.toString() ?? '';
        final String appName = app['appName']?.toString() ?? '';
        final String iconBase64 = app['iconBase64']?.toString() ?? '';
        
        if (_socialMediaTemplates.containsKey(packageName) && !addedPackages.contains(packageName)) {
          final template = _socialMediaTemplates[packageName]!;
          
          // For other social media apps, default to blocked for new users
          final savedBlockStatus = await _getSavedBlockStatus(packageName);
          final isBlocked = savedBlockStatus ?? true; // Default to true for all social media apps
          
          // If this is a new user (no saved status), set the default
          if (savedBlockStatus == null) {
            await _saveBlockStatus(packageName, true);
          }
          
          socialApps.add(DetectedSocialApp(
            name: template.displayName,
            packageName: packageName,
            icon: template.icon,
            appName: appName,
            iconBase64: iconBase64,
            isBlocked: isBlocked,
            isInstalled: true,
          ));
          addedPackages.add(packageName);
        }
      }

      // Add custom apps that are still installed
      for (var customApp in _customAddedApps) {
        final isStillInstalled = _allInstalledApps.any((app) => app['packageName'] == customApp.packageName);
        if (isStillInstalled && !addedPackages.contains(customApp.packageName)) {
          // Update with current installed app data
          final installedAppData = _allInstalledApps.firstWhere(
            (app) => app['packageName'] == customApp.packageName,
          );
          
          bool isBlocked = false;
          try {
            final savedBlockStatus = await _getSavedBlockStatus(customApp.packageName);
            isBlocked = savedBlockStatus ?? customApp.isBlocked; // Use saved value or custom app's blocked state as fallback
          } catch (e) {
            print('AppsListPage: Error getting block status for ${customApp.packageName}: $e');
            isBlocked = customApp.isBlocked; // Use the saved value as fallback
          }
          
          // Create new instance instead of modifying final fields
          final updatedCustomApp = DetectedSocialApp(
            name: customApp.name,
            packageName: customApp.packageName,
            icon: customApp.icon,
            appName: installedAppData['appName'] ?? customApp.name,
            iconBase64: installedAppData['iconBase64'] ?? '',
            isBlocked: isBlocked,
            isInstalled: true,
          );
          
          socialApps.add(updatedCustomApp);
          addedPackages.add(customApp.packageName);
        }
      }

      socialApps.sort((a, b) => a.name.compareTo(b.name));
      
      print('AppsListPage: Final social apps count: ${socialApps.length}');

      if (mounted) {
        setState(() {
          _installedSocialApps = socialApps;
          _isLoading = false;
          _hasLoadedOnce = true;
        });
      }
    } catch (e, stackTrace) {
      print('AppsListPage: Error loading apps: $e');
      print('AppsListPage: Stack trace: $stackTrace');
      
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load apps: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<bool?> _getSavedBlockStatus(String packageName) async {
    try {
      // Check if the app has a saved block status
      final blockedApps = await StorageService.getBlockedApps();
      if (blockedApps.contains(packageName)) {
        return true;
      }
      
      // Check if we have any saved preferences at all to determine if this is a new user
      final hasAnyBlockedApps = blockedApps.isNotEmpty;
      final hasCustomApps = (await StorageService.getCustomApps()).isNotEmpty;
      
      // If no saved data exists, this is a new user - return null to use defaults
      if (!hasAnyBlockedApps && !hasCustomApps) {
        return null;
      }
      
      // Existing user with saved data but this app is not blocked
      return false;
    } catch (e) {
      print('AppsListPage: Error getting block status for $packageName: $e');
      return null; // Return null to use defaults on error
    }
  }

  Future<void> _loadSavedData() async {
    try {
      // Load custom added apps using centralized storage
      final customAppsData = await StorageService.getCustomApps();
      _customAddedApps = customAppsData.map((data) {
        return DetectedSocialApp(
          name: data['name'] ?? '',
          packageName: data['packageName'] ?? '',
          icon: Icons.apps,
          appName: data['appName'] ?? '',
          iconBase64: data['iconBase64'] ?? '',
          isBlocked: data['isBlocked'] == 'true',
          isInstalled: true,
        );
      }).toList();
    } catch (e) {
      print('AppsListPage: Error loading saved data: $e');
      _customAddedApps = []; // Initialize empty list on error
    }
  }

  Future<void> _saveCustomApps() async {
    final customAppsData = _customAddedApps.map((app) => {
      'name': app.name,
      'packageName': app.packageName,
      'appName': app.appName,
      'iconBase64': app.iconBase64,
      'isBlocked': app.isBlocked.toString(),
    }).toList();
    
    await StorageService.setCustomApps(customAppsData);
  }

  Future<void> _saveBlockStatus(String packageName, bool isBlocked) async {
    if (isBlocked) {
      await StorageService.addBlockedApp(packageName);
    } else {
      await StorageService.removeBlockedApp(packageName);
    }
    
    // Also sync directly with native Android for immediate effect
    try {
      await platform.invokeMethod('setAppBlocked', {
        'packageName': packageName,
        'isBlocked': isBlocked,
      });
    } catch (e) {
      print('Failed to sync with native Android: $e');
    }
    
    print('Synced $packageName blocked status: $isBlocked');
  }

  bool _isSystemApp(String packageName) {
    final systemApps = [
      'android', 'com.android', 'com.google.android.gms', 
      'com.sec.android', 'com.samsung', 'com.miui',
      'com.oneplus', 'com.huawei', 'com.oppo', 'com.vivo'
    ];
    return systemApps.any((system) => packageName.startsWith(system));
  }

  Widget _buildAppIcon(DetectedSocialApp app, {double size = 32}) {
    // Use cached icon if available
    final cacheKey = '${app.packageName}_$size';
    if (_iconCache.containsKey(cacheKey)) {
      return _iconCache[cacheKey]!;
    }

    Widget iconWidget;
    if (app.iconBase64.isNotEmpty) {
      try {
        final Uint8List bytes = base64Decode(app.iconBase64);
        iconWidget = ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.15),
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: true, // Improve performance
            errorBuilder: (context, error, stackTrace) => _buildFallbackIcon(app, size),
          ),
        );
      } catch (e) {
        iconWidget = _buildFallbackIcon(app, size);
      }
    } else {
      iconWidget = _buildFallbackIcon(app, size);
    }

    // Cache the widget
    _iconCache[cacheKey] = iconWidget;
    return iconWidget;
  }

  Widget _buildFallbackIcon(DetectedSocialApp app, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(size * 0.15),
      ),
      child: Icon(
        app.icon,
        size: size * 0.6,
        color: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final blockedCount = _installedSocialApps.where((app) => app.isBlocked).length;
    final allAppsBlocked = _installedSocialApps.isNotEmpty && blockedCount == _installedSocialApps.length;
    
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
          title: const Text(
            'Blocked Apps',
            style: TextStyle(
              fontFamily: 'CustomBold',
              fontWeight: FontWeight.w700,
              fontSize: 30,
              letterSpacing: 2.0,
            ),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Theme.of(context).brightness == Brightness.dark 
                ? Brightness.light 
                : Brightness.dark,
          ),
          actions: [
            if (_installedSocialApps.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(right: 8),
                width: 56, // Increased width
                height: 36, // Reduced height
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18), // Increased from 12 to 18 for more circular look
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: IconButton(
                  onPressed: () {
                    setState(() {
                      final shouldBlock = !allAppsBlocked;
                      for (var app in _installedSocialApps) {
                        app.isBlocked = shouldBlock;
                      }
                    });
                  },
                  icon: Icon(allAppsBlocked ? Icons.check_circle : Icons.block),
                  tooltip: allAppsBlocked ? 'Unblock All' : 'Block All',
                  iconSize: 20, // Adjust icon size for the smaller container
                ),
              ),
            Container(
              margin: const EdgeInsets.only(right: 8),
              width: 56, // Increased width
              height: 36, // Reduced height
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18), // Increased from 12 to 18 for more circular look
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: IconButton(
                onPressed: _showCustomAppSelector,
                icon: const Icon(Icons.add),
                tooltip: 'Add App',
                iconSize: 20, // Adjust icon size for the smaller container
              ),
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildShimmerList();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_installedSocialApps.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16), // Add both top and bottom padding
      itemCount: _installedSocialApps.length,
      // Add performance optimizations
      cacheExtent: 500, // Cache more items
      itemExtent: 76, // Fixed height for better performance
      itemBuilder: (context, index) {
        final app = _installedSocialApps[index];
        return _buildAppCard(app, index);
      },
    );
  }

  Widget _buildAppCard(DetectedSocialApp app, int index) {
    return GestureDetector(
      onLongPress: () {
        // Add haptic feedback and bouncy animation
        HapticFeedback.mediumImpact();
        
        // Create a temporary animation controller for this card
        final animationController = AnimationController(
          duration: const Duration(milliseconds: 200),
          vsync: this,
        );
        
        final scaleAnimation = Tween<double>(
          begin: 1.0,
          end: 0.95,
        ).animate(CurvedAnimation(
          parent: animationController,
          curve: Curves.elasticOut,
        ));
        
        // Start the animation
        animationController.forward().then((_) {
          animationController.reverse().then((_) {
            animationController.dispose();
          });
        });
        
        // Show dialog after animation starts
        Future.delayed(const Duration(milliseconds: 100), () {
          _showRemoveDialog(app, index);
        });
        
        // Apply the animation to this specific card
        setState(() {
          // This will trigger a rebuild with the animation
        });
      },
      child: Container(
        key: ValueKey(app.packageName),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        height: 68, // Fixed height
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: app.isBlocked 
                ? Colors.red.withOpacity(0.3)
                : Theme.of(context).colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // App icon in circular container
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _buildAppIcon(app, size: 36),
            ),
            const SizedBox(width: 12),
            // App info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text( // Replace AutoSizeText for better performance
                          app.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: app.isInstalled 
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!app.isInstalled)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Text( // Replace AutoSizeText
                            'Not installed',
                            style: TextStyle(
                              fontSize: 9,
                              color: Theme.of(context).colorScheme.outline,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text( // Replace AutoSizeText
                    app.isInstalled ? app.appName : 'Install to block',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Custom switch - simplified
            _buildCustomSwitch(app),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomSwitch(DetectedSocialApp app) {
    final isOn = app.isBlocked && app.isInstalled;
    final isEnabled = app.isInstalled;
    
    return GestureDetector(
      onTap: isEnabled ? () async {
        // Update immediately for better UX
        setState(() {
          app.isBlocked = !app.isBlocked;
        });
        HapticFeedback.lightImpact();
        
        // Save asynchronously
        _saveBlockStatus(app.packageName, app.isBlocked);
      } : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150), // Reduced duration
        width: 56,
        height: 30,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: isEnabled 
              ? (isOn 
                  ? Colors.red.shade400 
                  : Theme.of(context).colorScheme.outline.withOpacity(0.3))
              : Theme.of(context).colorScheme.outline.withOpacity(0.1),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 150), // Simplified animation
          alignment: isOn ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.all(2),
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
            child: Icon(
              isOn ? Icons.check_rounded : Icons.close_rounded,
              size: 16,
              color: isEnabled
                  ? (isOn 
                      ? Colors.red.shade400 
                      : Theme.of(context).colorScheme.outline)
                  : Theme.of(context).colorScheme.outline.withOpacity(0.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16), // Add both top and bottom padding to shimmer too
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(50), // Perfect pill shimmer
          ),
          child: Shimmer.fromColors(
            baseColor: Theme.of(context).colorScheme.surfaceVariant,
            highlightColor: Theme.of(context).colorScheme.surface,
            period: const Duration(milliseconds: 1000),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 14,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 10,
                        width: 120,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 56,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(30), // Perfect pill shimmer switch
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(50), // Perfect pill shape
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Error Loading Apps',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(30), // Perfect pill shape
              ),
              child: Text(
                _errorMessage!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadInstalledApps,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30), // Perfect pill button
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(50), // Perfect pill shape
              ),
              child: Icon(
                Icons.apps_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Social Media Apps Found',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(30), // Perfect pill shape
              ),
              child: Text(
                'ScrollOff couldn\'t find any common social media apps on your device.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadInstalledApps,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30), // Perfect pill button
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showCustomAppSelector,
          borderRadius: BorderRadius.circular(25), // More pill-shaped
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), // Increased padding for pill shape
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25), // Perfect pill shape
              color: Theme.of(context).colorScheme.primaryContainer, // Fill with system color
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add,
                  color: Theme.of(context).colorScheme.onPrimaryContainer, // System color for icon
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Add',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer, // System color for text
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCustomAppSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.3),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => Container(
        height: 650, // Fixed height of 300px
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header with drag handle and title
            Container(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                children: [
                  // Drag handle
                  Container(
                    width: 48,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Title section
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.add_circle_outline,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add Apps to Block',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              'Select from installed apps',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.close,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Divider
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
              ),
            ),
            const SizedBox(height: 6),
            // Apps list - now with fixed height
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _allInstalledApps.length,
                itemBuilder: (context, index) {
                  final app = _allInstalledApps[index];
                  final packageName = app['packageName'] ?? '';
                  final appName = app['appName'] ?? '';
                  final iconBase64 = app['iconBase64'] ?? '';
                  
                  final isAlreadyAdded = _installedSocialApps.any(
                    (socialApp) => socialApp.packageName == packageName,
                  );
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    height: 68, // Fixed height like main list
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isAlreadyAdded 
                          ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
                          : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(50), // Pill shape
                      border: Border.all(
                        color: isAlreadyAdded 
                            ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
                            : Theme.of(context).colorScheme.outline.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // App icon in circular container
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: _buildCustomAppIcon(iconBase64),
                        ),
                        const SizedBox(width: 12),
                        // App info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                appName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isAlreadyAdded 
                                      ? Theme.of(context).colorScheme.onSurfaceVariant
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                packageName,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Toggle switch instead of add button
                        GestureDetector(
                          onTap: () async {
                            if (isAlreadyAdded) {
                              // Remove app logic here if needed
                            } else {
                              // Add haptic feedback
                              HapticFeedback.lightImpact();
                              
                              // Add the app - removed await since _addCustomApp returns void
                              _addCustomApp(app);
                              
                              // Close the bottom sheet after a short delay to show the animation
                              Future.delayed(const Duration(milliseconds: 300), () {
                                if (mounted) {
                                  Navigator.pop(context);
                                }
                              });
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200), // Slightly longer for better visibility
                            width: 56,
                            height: 30,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              color: isAlreadyAdded 
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                            ),
                            child: AnimatedAlign(
                              duration: const Duration(milliseconds: 200), // Match container duration
                              alignment: isAlreadyAdded ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.all(2),
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
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(
                                    isAlreadyAdded ? Icons.check_rounded : Icons.close_rounded,
                                    key: ValueKey(isAlreadyAdded), // Add key for smooth transition
                                    size: 16,
                                    color: isAlreadyAdded 
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.outline,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomAppIcon(String iconBase64) {
    if (iconBase64.isNotEmpty) {
      try {
        final Uint8List bytes = base64Decode(iconBase64);
        return ClipRRect(
          borderRadius: BorderRadius.circular(12), // More rounded icon
          child: Image.memory(
            bytes,
            width: 32,
            height: 32,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildDefaultIcon(),
          ),
        );
      } catch (e) {
        return _buildDefaultIcon();
      }
    }
    return _buildDefaultIcon();
  }

  Widget _buildDefaultIcon() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12), // More rounded icon
      ),
      child: Icon(
        Icons.apps_rounded,
        size: 20,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  void _addCustomApp(Map<String, String> app) async {
    final packageName = app['packageName'] ?? '';
    final appName = app['appName'] ?? '';
    final iconBase64 = app['iconBase64'] ?? '';
    
    if (packageName.isNotEmpty && appName.isNotEmpty) {
      final newCustomApp = DetectedSocialApp(
        name: appName,
        packageName: packageName,
        icon: Icons.apps,
        appName: appName,
        iconBase64: iconBase64,
        isBlocked: true,
      );
      
      setState(() {
        _installedSocialApps.add(newCustomApp);
        _customAddedApps.add(newCustomApp);
        _installedSocialApps.sort((a, b) => a.name.compareTo(b.name));
      });
      
      // Save to centralized storage
      await _saveCustomApps();
      await _saveBlockStatus(packageName, true);
      
      print('Added custom app: $appName ($packageName) and set as blocked');
      
      // Don't close navigator here anymore - it's handled in the onTap
    
      // Show snackbar after bottom sheet closes
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$appName added to blocked apps'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () => _removeCustomApp(packageName),
              ),
            ),
          );
        }
      });
    }
  }

  void _showRemoveDialog(DetectedSocialApp app, int index) {
    // Only allow removal of custom added apps (not default social media apps)
    final isCustomApp = _customAddedApps.any((customApp) => customApp.packageName == app.packageName);
    
    if (!isCustomApp) {
      // Show info dialog for default apps
      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
          child: Container(
            width: 500, // Match the remove dialog width
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Cannot remove ${app.name}',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Center(
                  child: SizedBox(
                    width: 56, // Same width as the toggle switch
                    height: 30, // Same height as the toggle switch
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        padding: EdgeInsets.zero,
                        elevation: 0,
                      ),
                      child: const Text('OK', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    // Show remove confirmation for custom apps - always start with "on" state since app is in the blocked list
    bool dialogAppState = true; // Always start with "on" since app is in the blocked list
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
          child: Container(
            width: 500, // Increased from 400 to 420
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Do you want to remove ${app.name}?',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Center(
                  child: GestureDetector(
                    onTap: () async {
                      // Toggle the dialog state
                      setDialogState(() {
                        dialogAppState = !dialogAppState;
                      });
                      
                      // If toggled to off, remove the app from the list
                      if (!dialogAppState) {
                        setState(() {
                          _installedSocialApps.removeAt(index);
                          _customAddedApps.removeWhere((customApp) => 
                              customApp.packageName == app.packageName);
                        });
                        
                        // Save changes
                        await _saveCustomApps();
                        await _saveBlockStatus(app.packageName, false);
                        
                        // Sync with native Android
                        try {
                          await platform.invokeMethod('setAppBlocked', {
                            'packageName': app.packageName,
                            'isBlocked': false,
                          });
                        } catch (e) {
                          print('Failed to sync removed app: $e');
                        }
                        
                        // Close dialog
                        Navigator.pop(context);
                        
                        // Show undo snackbar
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${app.name} removed'),
                            action: SnackBarAction(
                              label: 'Undo',
                              onPressed: () async {
                                setState(() {
                                  app.isBlocked = true;
                                  _installedSocialApps.insert(index, app);
                                  _customAddedApps.add(app);
                                  _installedSocialApps.sort((a, b) => a.name.compareTo(b.name));
                                });
                                
                                // Save restored state
                                await _saveCustomApps();
                                await _saveBlockStatus(app.packageName, true);
                                
                                // Sync with native Android
                                try {
                                  await platform.invokeMethod('setAppBlocked', {
                                    'packageName': app.packageName,
                                    'isBlocked': true,
                                  });
                                } catch (e) {
                                  print('Failed to sync restored app: $e');
                                }
                              },
                            ),
                          ),
                        );
                      } else {
                        // If toggled back to on, just close the dialog (keep app in list)
                        Navigator.pop(context);
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 56,
                      height: 30,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        color: dialogAppState 
                            ? Colors.red.shade400 
                            : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                      ),
                      child: AnimatedAlign(
                        duration: const Duration(milliseconds: 150),
                        alignment: dialogAppState ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.all(2),
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
                          child: Icon(
                            dialogAppState ? Icons.check_rounded : Icons.close_rounded,
                            size: 16,
                            color: dialogAppState 
                                ? Colors.red.shade400 
                                : Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      );
  }

  void _removeCustomApp(String packageName) async {
    setState(() {
      _installedSocialApps.removeWhere((app) => app.packageName == packageName);
      _customAddedApps.removeWhere((app) => app.packageName == packageName);
    });
    
    // Save changes
    await _saveCustomApps();
    await _saveBlockStatus(packageName, false);
    
    // Sync with native Android
    try {
      await platform.invokeMethod('setAppBlocked', {
        'packageName': packageName,
        'isBlocked': false,
      });
    } catch (e) {
      print('Failed to sync removed app: $e');
    }
  }

  void _showAddCustomAppDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String appName = '';
        String packageName = '';
        
        return AlertDialog(
          title: const Text('Add Custom App'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'App Name',
                  hintText: 'Enter app name',
                ),
                onChanged: (value) => appName = value,
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Package Name',
                  hintText: 'com.example.app',
                ),
                onChanged: (value) => packageName = value,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (appName.isNotEmpty && packageName.isNotEmpty) {
                  // Add the custom app logic here
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}

class SocialMediaAppTemplate {
  final String displayName;
  final IconData icon;
  final bool blocked;

  SocialMediaAppTemplate(this.displayName, this.icon, {this.blocked = false});
}

class DetectedSocialApp {
  final String name;
  final String packageName;
  final IconData icon;
  final String appName;
  final String iconBase64;
  final bool isInstalled;
  bool isBlocked; // Keep this mutable for state changes

  DetectedSocialApp({
    required this.name,
    required this.packageName,
    required this.icon,
    required this.appName,
    required this.iconBase64,
    required this.isBlocked,
    this.isInstalled = true,
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simple_animations/simple_animations.dart';
import 'dart:convert';
import 'dart:typed_data';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> with TickerProviderStateMixin {
  late AnimationController _pageController;
  late AnimationController _numberController;
  static const platform = MethodChannel('com.example.scrolloff/apps');
  static const usageChannel = MethodChannel('com.example.scrolloff/usage');

  // Real-time data from native
  List<Map<String, dynamic>> _installedApps = [];
  List<Map<String, dynamic>> _usageData = [];
  bool _isLoading = true;
  String? _errorMessage;
  
  // Calculated statistics
  int _totalUsageTime = 0; // Total usage time in minutes for the year
  Map<String, int> _appUsageTimes = {}; // Usage time per app (yearly total)
  Map<String, Map<String, int>> _dailyUsageData = {}; // Daily usage data by date

  // Default apps package names to track
  final Set<String> _defaultAppPackages = {
    'com.instagram.android',
    'com.google.android.youtube',
    'app.revanced.android.youtube',
    'com.facebook.katana',
    'com.zhiliaoapp.musically',
  };

  @override
  void initState() {
    super.initState();
    _pageController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _numberController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pageController.forward();
    });

    _loadRealTimeData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _numberController.dispose();
    super.dispose();
  }

  Future<void> _loadRealTimeData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      print('Loading real-time data...');

      // Get installed apps data
      final dynamic appsResult = await platform.invokeMethod('getInstalledApps');
      
      List<dynamic> installedApps;
      if (appsResult is List) {
        installedApps = appsResult;
      } else {
        throw Exception('Expected List but got ${appsResult.runtimeType}');
      }

      _installedApps = installedApps
          .map((app) => Map<String, dynamic>.from(app as Map))
          .where((app) => app.isNotEmpty)
          .toList();

      print('Loaded ${_installedApps.length} installed apps');

      // Get usage statistics if available
      try {
        print('Fetching usage statistics...');
        final dynamic usageResult = await usageChannel.invokeMethod('getUsageStats');
        if (usageResult is List) {
          _usageData = usageResult
              .map((usage) => Map<String, dynamic>.from(usage as Map))
              .toList();
          print('Loaded ${_usageData.length} usage entries');
          
          // Debug: Print first few usage entries
          for (int i = 0; i < _usageData.length && i < 5; i++) {
            final usage = _usageData[i];
            final name = usage['appName'] ?? 'Unknown';
            final timeMs = usage['usageTime'] ?? 0;
            final timeMin = (timeMs / (1000 * 60)).round();
            print('Usage[$i]: $name - ${timeMin}min');
          }
        }
      } catch (e) {
        print('Failed to get usage stats: $e');
        _usageData = [];
      }

      _calculateStatistics();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading real-time data: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load app data: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _calculateStatistics() {
    _totalUsageTime = 0;
    _appUsageTimes.clear();
    _dailyUsageData.clear();

    print('Calculating statistics for ${_usageData.length} apps');

    // Group usage data by package name to handle duplicates and sum correctly
    Map<String, int> packageUsageTotals = {};
    
    for (var usage in _usageData) {
      final packageName = usage['packageName'] as String? ?? '';
      final usageTimeMs = usage['usageTime'] as int? ?? 0;
      final usageTimeMinutes = (usageTimeMs / (1000 * 60)).round();
      
      print('Processing $packageName: ${usageTimeMinutes}min (${usageTimeMs}ms)');
      
      if (packageName.isNotEmpty && usageTimeMinutes > 0) {
        // Aggregate usage time for the same package (handle duplicates)
        packageUsageTotals[packageName] = (packageUsageTotals[packageName] ?? 0) + usageTimeMinutes;
        print('Aggregated total for $packageName: ${packageUsageTotals[packageName]}min');
      }
    }

    // Calculate final totals from aggregated data - ONLY for default apps
    for (var entry in packageUsageTotals.entries) {
      final packageName = entry.key;
      final totalMinutes = entry.value;
      
      // Store individual app usage for ALL apps (for potential future use)
      _appUsageTimes[packageName] = totalMinutes;
      
      // Add to total usage time ONLY if it's a default tracked app
      if (_defaultAppPackages.contains(packageName)) {
        _totalUsageTime += totalMinutes;
        print('Added ${totalMinutes}min for DEFAULT app $packageName to total (Running total: ${_totalUsageTime}min)');
      } else {
        print('Skipped ${totalMinutes}min for non-default app $packageName from total');
      }
      
      // Process daily data (use the first occurrence for date info)
      final usageEntry = _usageData.firstWhere(
        (usage) => usage['packageName'] == packageName,
        orElse: () => <String, dynamic>{},
      );
      
      final lastTimeUsed = usageEntry['lastTimeUsed'] as int? ?? 0;
      if (lastTimeUsed > 0) {
        try {
          final usageDate = DateTime.fromMillisecondsSinceEpoch(lastTimeUsed);
          final dateKey = '${usageDate.year}-${usageDate.month.toString().padLeft(2, '0')}-${usageDate.day.toString().padLeft(2, '0')}';
          
          if (!_dailyUsageData.containsKey(dateKey)) {
            _dailyUsageData[dateKey] = {};
          }
          _dailyUsageData[dateKey]![packageName] = totalMinutes;
        } catch (e) {
          print('Error processing date for $packageName: $e');
        }
      }
    }

    print('=== Final Calculation Results ===');
    print('Total Usage Time (DEFAULT APPS ONLY): ${_formatUsageTime(_totalUsageTime)} (${_totalUsageTime} minutes)');
    print('Total apps with data: ${_appUsageTimes.length}');
    print('Default apps with usage: ${_getAvailableDefaultApps().length}');
    print('Daily usage entries: ${_dailyUsageData.length}');
    
    // Debug: Print all default apps usage
    print('Default apps usage breakdown:');
    for (var packageName in _defaultAppPackages) {
      final usage = _appUsageTimes[packageName] ?? 0;
      if (usage > 0) {
        print('  $packageName: ${_formatUsageTime(usage)} (${usage} min)');
      }
    }
    
    // Verify total calculation for default apps only
    final defaultAppsTotal = _defaultAppPackages
        .map((pkg) => _appUsageTimes[pkg] ?? 0)
        .fold(0, (sum, minutes) => sum + minutes);
    print('Manual verification total (default apps): ${defaultAppsTotal} minutes');
    if (defaultAppsTotal != _totalUsageTime) {
      print('WARNING: Total mismatch! Stored: $_totalUsageTime, Calculated: $defaultAppsTotal');
      _totalUsageTime = defaultAppsTotal; // Use the correct calculation
    }
    
    // After calculations are done, start number animations
    if (mounted) {
      _numberController.reset();
      _numberController.forward();
    }
  }

  Widget _buildAnimatedNumber({
    required int targetValue,
    required TextStyle style,
    String suffix = '',
    double delay = 0.0,
  }) {
    return CustomAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1500),
      delay: Duration(milliseconds: (delay * 1000).round()),
      tween: Tween(begin: 0.0, end: targetValue.toDouble()),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Text(
          '${value.round()}$suffix',
          style: style,
        );
      },
    );
  }

  Widget _buildAnimatedDecimalNumber({
    required double targetValue,
    required TextStyle style,
    int decimals = 1,
    String suffix = '',
    double delay = 0.0,
  }) {
    return CustomAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1500),
      delay: Duration(milliseconds: (delay * 1000).round()),
      tween: Tween(begin: 0.0, end: targetValue),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Text(
          '${value.toStringAsFixed(decimals)}$suffix',
          style: style,
        );
      },
    );
  }

  Widget _buildAnimatedUsageTime({
    required int targetMinutes,
    required TextStyle style,
    double delay = 0.0,
  }) {
    return CustomAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1500),
      delay: Duration(milliseconds: (delay * 1000).round()),
      tween: Tween(begin: 0.0, end: targetMinutes.toDouble()),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Text(
          _formatUsageTime(value.round()),
          style: style,
        );
      },
    );
  }

  List<Map<String, dynamic>> _getAvailableDefaultApps() {
    final List<Map<String, dynamic>> availableApps = [];
    
    print('Getting available default apps from ${_installedApps.length} installed apps');
    
    // Show ALL default apps that have usage data (regardless of installation status)
    for (var packageName in _defaultAppPackages) {
      final usageTime = _appUsageTimes[packageName] ?? 0;
      
      if (usageTime > 0) { // Only show if there's actual usage data
        // Try to find installed app data
        final installedApp = _installedApps.firstWhere(
          (app) => app['packageName'] == packageName,
          orElse: () => <String, dynamic>{},
        );
        
        print('Found usage for default app: $packageName with ${usageTime}min usage');
        
        availableApps.add({
          'name': installedApp['appName'] ?? _getAppDisplayName(packageName),
          'packageName': packageName,
          'iconBase64': installedApp['iconBase64'] ?? '',
          'usageTime': usageTime,
        });
      }
    }

    // Sort by usage time (highest first)
    availableApps.sort((a, b) => (b['usageTime'] as int).compareTo(a['usageTime'] as int));
    
    print('Returning ${availableApps.length} available default apps with usage data');
    
    return availableApps;
  }

  String _getAppDisplayName(String packageName) {
    switch (packageName) {
      case 'com.instagram.android': return 'Instagram';
      case 'com.google.android.youtube': return 'YouTube';
      case 'app.revanced.android.youtube': return 'YouTube ReVanced';
      case 'com.facebook.katana': return 'Facebook';
      case 'com.twitter.android': return 'X (Twitter)';
      case 'com.zhiliaoapp.musically': return 'TikTok';
      default: return packageName;
    }
  }

  IconData _getAppIcon(String packageName) {
    switch (packageName) {
      case 'com.instagram.android': return Icons.camera_alt;
      case 'com.google.android.youtube': return Icons.play_circle_filled;
      case 'app.revanced.android.youtube': return Icons.play_circle_outline;
      case 'com.facebook.katana': return Icons.facebook;
      case 'com.twitter.android': return Icons.alternate_email;
      case 'com.zhiliaoapp.musically': return Icons.music_video;
      default: return Icons.smartphone;
    }
  }

  Widget _buildAppIcon(Map<String, dynamic> app, {double size = 32}) {
    final iconBase64 = app['iconBase64'] as String? ?? '';
    final packageName = app['packageName'] as String? ?? '';

    // First try to use the base64 icon if available
    if (iconBase64.isNotEmpty) {
      try {
        final Uint8List bytes = base64Decode(iconBase64);
        return ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.15),
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              print('Error loading icon for $packageName: $error');
              return _buildFallbackIcon(packageName, size);
            },
          ),
        );
      } catch (e) {
        print('Error decoding base64 icon for $packageName: $e');
        return _buildFallbackIcon(packageName, size);
      }
    }
    
    // If no base64 icon, use fallback
    return _buildFallbackIcon(packageName, size);
  }

  Widget _buildFallbackIcon(String packageName, double size) {
    // Special handling for YouTube apps with better visual design
    if (packageName == 'com.google.android.youtube' || packageName == 'app.revanced.android.youtube') {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.red.shade600,
              Colors.red.shade500,
            ],
          ),
          borderRadius: BorderRadius.circular(size * 0.15),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          packageName == 'app.revanced.android.youtube' 
              ? Icons.play_circle_outline 
              : Icons.play_circle_filled,
          size: size * 0.6,
          color: Colors.white,
        ),
      );
    }

    // Special handling for Instagram
    if (packageName == 'com.instagram.android') {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Colors.purple.shade400,
              Colors.pink.shade400,
              Colors.orange.shade400,
            ],
          ),
          borderRadius: BorderRadius.circular(size * 0.15),
        ),
        child: Icon(
          Icons.camera_alt,
          size: size * 0.6,
          color: Colors.white,
        ),
      );
    }

    // Special handling for TikTok
    if (packageName == 'com.zhiliaoapp.musically') {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(size * 0.15),
        ),
        child: Icon(
          Icons.music_video,
          size: size * 0.6,
          color: Colors.white,
        ),
      );
    }

    // Special handling for Facebook
    if (packageName == 'com.facebook.katana') {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.blue.shade700,
          borderRadius: BorderRadius.circular(size * 0.15),
        ),
        child: Icon(
          Icons.facebook,
          size: size * 0.6,
          color: Colors.white,
        ),
      );
    }

    // Default fallback for other apps
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(size * 0.15),
      ),
      child: Icon(
        _getAppIcon(packageName),
        size: size * 0.6,
        color: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
    );
  }

  String _formatUsageTime(int totalMinutes) {
    if (totalMinutes == 0) return '0m';
    
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    
    // If more than 24 hours, show as days and hours
    if (hours >= 24) {
      final days = hours ~/ 24;
      final remainingHours = hours % 24;
      if (remainingHours == 0) {
        return '${days}d';
      } else {
        return '${days}d ${remainingHours}h';
      }
    }
    
    // If more than 1 hour, show hours and minutes
    if (hours > 0) {
      if (minutes == 0) {
        return '${hours}h';
      } else {
        return '${hours}h ${minutes}m';
      }
    }
    
    // Less than 1 hour, show only minutes
    return '${minutes}m';
  }

  String _getUsageLevel(int totalMinutes) {
    final hours = totalMinutes / 60;
    print('Usage level calculation: ${hours.toStringAsFixed(1)} hours');
    
    // Adjusted thresholds for more realistic categorization
    if (hours < 50) return 'light';      // Less than 50 hours per year
    if (hours < 200) return 'moderate';  // 50-200 hours per year
    return 'heavy';                      // More than 200 hours per year
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Theme.of(context).brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: Theme.of(context).brightness == Brightness.dark
            ? Brightness.dark
            : Brightness.light,
        systemNavigationBarColor: Theme.of(context).scaffoldBackgroundColor,
        systemNavigationBarIconBrightness: Theme.of(context).brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.blue.withOpacity(0.05),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Theme.of(context).brightness == Brightness.dark
                ? Brightness.light
                : Brightness.dark,
            statusBarBrightness: Theme.of(context).brightness == Brightness.dark
                ? Brightness.dark
                : Brightness.light,
          ),
          title: CustomAnimationBuilder<double>(
            duration: const Duration(milliseconds: 800),
            delay: const Duration(milliseconds: 200),
            tween: Tween(begin: 0.0, end: 1.0),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(-30 * (1 - value), 0),
                child: Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: const Text(
                    'Usage',
                    style: TextStyle(
                      fontFamily: 'CustomBold',
                      fontWeight: FontWeight.w700,
                      fontSize: 30,
                      letterSpacing: 2.0,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        body: CustomAnimationBuilder<double>(
          duration: const Duration(milliseconds: 1200),
          tween: Tween(begin: 0.0, end: 1.0),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value.clamp(0.0, 1.0),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Total Usage Ticket Card
                    CustomAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 800),
                      delay: const Duration(milliseconds: 300),
                      tween: Tween(begin: 0.0, end: 1.0),
                      curve: Curves.easeOutCubic,
                      builder: (context, ticketValue, child) {
                        return Transform.translate(
                          offset: Offset(-100 * (1 - ticketValue), 0),
                          child: Opacity(
                            opacity: ticketValue.clamp(0.0, 1.0),
                            child: _buildUsageTicketCard(),
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Emotional Message Card
                    CustomAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 800),
                      delay: const Duration(milliseconds: 500),
                      tween: Tween(begin: 0.0, end: 1.0),
                      curve: Curves.easeOutCubic,
                      builder: (context, messageValue, child) {
                        return Transform.translate(
                          offset: Offset(-100 * (1 - messageValue), 0),
                          child: Opacity(
                            opacity: messageValue.clamp(0.0, 1.0),
                            child: _buildEmotionalMessageCard(),
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Harry Potter Comparison Card
                    CustomAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 800),
                      delay: const Duration(milliseconds: 700),
                      tween: Tween(begin: 0.0, end: 1.0),
                      curve: Curves.easeOutCubic,
                      builder: (context, comparisonValue, child) {
                        return Transform.translate(
                          offset: Offset(-100 * (1 - comparisonValue), 0),
                          child: Opacity(
                            opacity: comparisonValue.clamp(0.0, 1.0),
                            child: _buildHarryPotterComparisonCard(),
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
    );
  }

  Map<String, dynamic> _getEmotionalMessage(String usageLevel) {
    switch (usageLevel) {
      case 'light':
        return {
          'title': 'Great Balance!',
          'description': 'You\'re using social media mindfully. Keep up this healthy balance!',
          'effects': 'Good habits = Better sleep, focus, and real connections.',
          'icon': Icons.eco,
          'color': Colors.green.shade50,
          'borderColor': Colors.green.shade200,
          'textColor': Colors.green.shade800,
        };
      case 'moderate':
        return {
          'title': 'Finding Balance',
          'description': 'Your usage is moderate. Consider setting some daily limits.',
          'effects': 'Try taking breaks to avoid digital fatigue.',
          'icon': Icons.balance,
          'color': Colors.orange.shade50,
          'borderColor': Colors.orange.shade200,
          'textColor': Colors.orange.shade800,
        };
      case 'heavy':
        return {
          'title': 'Time to Take Control',
          'description': 'Your screen time is quite high. Time for a digital detox!',
          'effects': 'Reduce usage for better sleep and focus.',
          'icon': Icons.warning_amber,
          'color': Colors.red.shade50,
          'borderColor': Colors.red.shade200,
          'textColor': Colors.red.shade800,
        };
      default:
        return {
          'title': 'Track Your Habits',
          'description': 'Monitor your usage and make conscious choices.',
          'effects': 'Understanding patterns helps build better habits.',
          'icon': Icons.smartphone,
          'color': Colors.blue.shade50,
          'borderColor': Colors.blue.shade200,
          'textColor': Colors.blue.shade800,
        };
    }
  }

  Widget _buildEmotionalMessageCard() {
    if (_isLoading || _totalUsageTime == 0) {
      return const SizedBox.shrink();
    }

    final usageLevel = _getUsageLevel(_totalUsageTime);
    final message = _getEmotionalMessage(usageLevel);
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: CustomPaint(
        painter: TicketPainter(
          backgroundColor: message['color'],
          borderColor: message['borderColor'],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: message['textColor'].withOpacity(0.1),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Icon(
                  message['icon'],
                  size: 40,
                  color: message['textColor'],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message['title'],
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: message['textColor'],
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message['description'],
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: message['textColor'].withOpacity(0.8),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: message['textColor'].withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  message['effects'],
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: message['textColor'].withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUsageTicketCard() {
    if (_isLoading) {
      return _buildLoadingTicketWithShimmer();
    }

    if (_errorMessage != null) {
      return _buildErrorTicket();
    }

    final availableApps = _getAvailableDefaultApps();
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: CustomPaint(
        painter: TicketPainter(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          borderColor: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    size: 24,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Usage Stats ${DateTime.now().year}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _loadRealTimeData();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.refresh,
                        size: 18,
                        color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Large total usage display
              Center(
                child: Column(
                  children: [
                    _buildAnimatedUsageTime(
                      targetMinutes: _totalUsageTime,
                      style: TextStyle(
                        fontSize: 80,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        height: 0.9,
                      ),
                      delay: 0.3,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total Usage Time',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.7),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // App pill cards section
              if (availableApps.isNotEmpty) ...[
                Text(
                  'App Breakdown',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...availableApps.map((app) => _buildAppPillCard(app)).toList(),
              ] else
                _buildNoDataSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingTicketWithShimmer() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: CustomPaint(
        painter: TicketPainter(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
          borderColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header shimmer
              Row(
                children: [
                  _buildShimmerBox(24, 24, borderRadius: 6),
                  const SizedBox(width: 8),
                  Expanded(child: _buildShimmerBox(120, 20, borderRadius: 4)),
                  _buildShimmerBox(32, 32, borderRadius: 16),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // App cards shimmer
              ...List.generate(3, (index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildShimmerAppCard(),
              )),
              
              const SizedBox(height: 16),
              
              // Total shimmer
              _buildShimmerBox(double.infinity, 48, borderRadius: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerAppCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(50),
      ),
      child: Row(
        children: [
          _buildShimmerBox(28, 28, borderRadius: 6),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildShimmerBox(100, 16, borderRadius: 4),
                const SizedBox(height: 4),
                _buildShimmerBox(80, 12, borderRadius: 4),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildShimmerBox(50, 16, borderRadius: 4),
              const SizedBox(height: 4),
              _buildShimmerBox(32, 3, borderRadius: 2),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerBox(double width, double height, {double borderRadius = 8}) {
    return CustomAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1500),
      tween: Tween(begin: 0.3, end: 1.0),
      curve: Curves.easeInOut,
      builder: (context, opacity, child) {
        return AnimatedOpacity(
          opacity: opacity,
          duration: const Duration(milliseconds: 500),
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoDataSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.smartphone_outlined,
            size: 36,
            color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.5),
          ),
          const SizedBox(height: 8),
          Text(
            'No usage data',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Use tracked apps to see data here',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  String _getAppCategory(String packageName) {
    switch (packageName) {
      case 'com.instagram.android': return 'Social Media';
      case 'com.google.android.youtube':
      case 'app.revanced.android.youtube': return 'Entertainment';
      case 'com.facebook.katana': return 'Social Media';
      case 'com.twitter.android': return 'Social Media';
      case 'com.zhiliaoapp.musically': return 'Entertainment';
      default: return 'App';
    }
  }

  Color _getUsageColor(int usageMinutes) {
    // Color based on usage intensity
    if (usageMinutes > 1440) { // More than 24 hours
      return Colors.red.shade600;
    } else if (usageMinutes > 480) { // More than 8 hours
      return Colors.orange.shade600;
    } else if (usageMinutes > 120) { // More than 2 hours
      return Colors.amber.shade600;
    } else if (usageMinutes > 30) { // More than 30 minutes
      return Colors.green.shade600;
    } else {
      return Colors.blue.shade600;
    }
  }

  Widget _buildLoadingTicket() {
    return Container(
      width: double.infinity,
      height: 160,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: CustomPaint(
        painter: TicketPainter(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
          borderColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                strokeWidth: 2,
              ),
              const SizedBox(height: 12),
              Text(
                'Loading...',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorTicket() {
    return Container(
      width: double.infinity,
      height: 160,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: CustomPaint(
        painter: TicketPainter(
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          borderColor: Theme.of(context).colorScheme.error.withOpacity(0.3),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 36,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
              const SizedBox(height: 12),
              Text(
                'Failed to load data',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadRealTimeData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.onErrorContainer,
                  foregroundColor: Theme.of(context).colorScheme.errorContainer,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHarryPotterComparisonCard() {
    if (_isLoading || _totalUsageTime == 0) {
      return const SizedBox.shrink();
    }

    // Harry Potter all 8 movies total runtime: approximately 1,178 minutes (19.6 hours)
    const int harryPotterTotalMinutes = 1178;
    final double harryPotterWatches = _totalUsageTime / harryPotterTotalMinutes;
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: CustomPaint(
        painter: TicketPainter(
          backgroundColor: Colors.purple.shade50,
          borderColor: Colors.purple.shade200,
        ),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              // Title
              CustomAnimationBuilder<double>(
                duration: const Duration(milliseconds: 600),
                delay: const Duration(milliseconds: 900),
                tween: Tween(begin: 0.0, end: 1.0),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(-30 * (1 - value), 0),
                    child: Opacity(
                      opacity: value,
                      child: Text(
                        'Time Perspective',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.purple.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              
              // Large Harry Potter count display
              Column(
                children: [
                  _buildAnimatedDecimalNumber(
                    targetValue: harryPotterWatches,
                    style: TextStyle(
                      fontSize: 120,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade800,
                      height: 0.8,
                    ),
                    decimals: 1,
                    delay: 0.8,
                  ),
                  const SizedBox(height: 8),
                  CustomAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 600),
                    delay: const Duration(milliseconds: 1400),
                    tween: Tween(begin: 0.0, end: 1.0),
                    curve: Curves.easeOut,
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset(-20 * (1 - value), 0),
                        child: Opacity(
                          opacity: value,
                          child: Text(
                            'times',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Colors.purple.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  CustomAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 600),
                    delay: const Duration(milliseconds: 1600),
                    tween: Tween(begin: 0.0, end: 1.0),
                    curve: Curves.easeOut,
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset(-40 * (1 - value), 0),
                        child: Opacity(
                          opacity: value,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade100,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text(
                              'You could watch Harry Potter complete series',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Colors.purple.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Additional info
              CustomAnimationBuilder<double>(
                duration: const Duration(milliseconds: 400),
                delay: const Duration(milliseconds: 1800),
                tween: Tween(begin: 0.0, end: 1.0),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(-20 * (1 - value), 0),
                    child: Opacity(
                      opacity: value,
                      child: Text(
                        'All 8 movies (19.6 hours)',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.purple.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppPillCard(Map<String, dynamic> app) {
    final usageTime = app['usageTime'] as int? ?? 0;
    final packageName = app['packageName'] as String? ?? '';
    final index = _getAvailableDefaultApps().indexOf(app);
    
    return CustomAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      delay: Duration(milliseconds: 800 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(-50 * (1 - value), 0),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.05),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(
                  color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  // App icon
                  _buildAppIcon(app, size: 28),
                  
                  const SizedBox(width: 12),
                  
                  // App name and category
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app['name'] ?? 'Unknown',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _getAppCategory(packageName),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Usage time with indicator
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildAnimatedUsageTime(
                        targetMinutes: usageTime,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ) ?? const TextStyle(),
                        delay: 0.3 + (index * 0.1),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 32,
                        height: 3,
                        decoration: BoxDecoration(
                          color: _getUsageColor(usageTime),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          );
        },
      
    );
  }
}

class TicketPainter extends CustomPainter {
  final Color backgroundColor;
  final Color borderColor;

  TicketPainter({
    required this.backgroundColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path();
    
    // Create ticket shape with triangular edges
    final triangleSize = 10.0;
    final numTriangles = (size.height / (triangleSize * 2)).floor();
    
    // Start from top-left
    path.moveTo(0, 0);
    
    // Top edge
    path.lineTo(size.width, 0);
    
    // Right edge with triangular cuts
    for (int i = 0; i < numTriangles; i++) {
      final y = (i * 2 + 1) * triangleSize;
      if (y < size.height - triangleSize) {
        path.lineTo(size.width, y);
        path.lineTo(size.width - triangleSize / 2, y + triangleSize / 2);
        path.lineTo(size.width, y + triangleSize);
      }
    }
    
    // Complete right edge
    path.lineTo(size.width, size.height);
    
    // Bottom edge
    path.lineTo(0, size.height);
    
    // Left edge with triangular cuts
    for (int i = numTriangles - 1; i >= 0; i--) {
      final y = (i * 2 + 1) * triangleSize + triangleSize;
      if (y > triangleSize) {
        path.lineTo(0, y);
        path.lineTo(triangleSize / 2, y - triangleSize / 2);
        path.lineTo(0, y - triangleSize);
      }
    }
    
    // Complete left edge
    path.lineTo(0, 0);
    
    path.close();

    // Draw shadow
    final shadowPath = Path.from(path);
    shadowPath.shift(const Offset(2, 4));
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.1)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    
    canvas.drawPath(shadowPath, shadowPaint);
    
    // Draw ticket
    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

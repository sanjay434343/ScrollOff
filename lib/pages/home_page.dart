import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simple_animations/simple_animations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animations/animations.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/storage_service.dart';
import 'apps_list_page.dart';
import 'statistics_page.dart'; // Add this import

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  bool _focusModeEnabled = false;
  late AnimationController _pulseController;
  late AnimationController _buttonController;
  late AnimationController _pageController;
  late AnimationController _toggleController;
  late AudioPlayer _audioPlayer;
  static const platform = MethodChannel('com.example.scrolloff/monitoring');

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _pageController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _toggleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _audioPlayer = AudioPlayer();

    // Start page animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pageController.forward();
    });

    _loadFocusMode();
  }

  void _loadFocusMode() async {
    final focusMode = await StorageService.getFocusMode();
    setState(() {
      _focusModeEnabled = focusMode;
    });
    
    if (_focusModeEnabled) {
      _pulseController.repeat(reverse: true);
      _toggleController.forward();
      _startMonitoringIfEnabled();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _buttonController.dispose();
    _pageController.dispose();
    _toggleController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _toggleFocusMode() async {
    // Play sound effect
    await _playSound(!_focusModeEnabled);
    
    // Add button press animation
    _buttonController.forward().then((_) {
      _buttonController.reverse();
    });

    final newValue = !_focusModeEnabled;
    setState(() {
      _focusModeEnabled = newValue;
    });

    // Animate toggle
    if (newValue) {
      _toggleController.forward();
    } else {
      _toggleController.reverse();
    }

    // Save using centralized storage
    await StorageService.setFocusMode(newValue);

    if (_focusModeEnabled) {
      _pulseController.repeat(reverse: true);
      _startMonitoringIfEnabled();
    } else {
      _pulseController.stop();
      _pulseController.reset();
      _stopMonitoring();
    }
  }

  void _startMonitoringIfEnabled() async {
    final backgroundMonitoring = await StorageService.getBackgroundMonitoring();
    
    print('Focus mode enabled - background monitoring: $backgroundMonitoring');
    
    if (backgroundMonitoring) {
      try {
        await platform.invokeMethod('startMonitoring');
        print('Successfully started monitoring service');
      } catch (e) {
        print('Failed to start monitoring: $e');
      }
    } else {
      print('Background monitoring is disabled');
    }
  }

  void _stopMonitoring() async {
    try {
      await platform.invokeMethod('stopMonitoring');
    } catch (e) {
      // Handle error silently
      print('Failed to stop monitoring: $e');
    }
  }

  Future<void> _playSound(bool isOn) async {
    try {
      final soundPath = isOn ? 'audio/on.mp3' : 'audio/off.mp3';
      await _audioPlayer.play(AssetSource(soundPath));
    } catch (e) {
      print('Error playing sound: $e');
    }
  }

  // Enhanced page transition with shared element-like animation
  Route _createRoute(String routeName) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) {
        late Widget page;
        switch (routeName) {
          case '/apps':
            page = Container(); // Your apps page widget
            break;
          case '/statistics':
            page = Container(); // Your statistics page widget
            break;
          default:
            page = Container();
        }
        return page;
      },
      transitionDuration: const Duration(milliseconds: 400),
      reverseTransitionDuration: const Duration(milliseconds: 350),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Enhanced transition with scale and slide
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;

        var slideAnimation = Tween(begin: begin, end: end).animate(
          CurvedAnimation(parent: animation, curve: curve),
        );

        var scaleAnimation = Tween(begin: 0.95, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        );

        var fadeAnimation = Tween(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeIn),
        );

        return SlideTransition(
          position: slideAnimation,
          child: ScaleTransition(
            scale: scaleAnimation,
            child: FadeTransition(
              opacity: fadeAnimation,
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive design
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    final isTablet = screenWidth > 600;
    
    // Calculate responsive sizes
    final buttonWidth = (screenWidth * 0.85).clamp(280.0, 400.0);
    final buttonHeight = (buttonWidth * 0.4375).clamp(120.0, 175.0); // Maintain aspect ratio
    final circleSize = (buttonHeight * 0.83).clamp(100.0, 145.0);
    final iconSize = (circleSize * 0.48).clamp(48.0, 70.0);
    final textSize = (screenWidth * 0.1).clamp(28.0, 48.0);
    final letterSpacing = isTablet ? 3.0 : 2.0;
    final horizontalPadding = screenWidth * 0.06;
    
    return Scaffold(
      backgroundColor: _focusModeEnabled 
          ? Colors.red.withOpacity(0.05) // Red tint when active
          : Theme.of(context).colorScheme.surface, // System surface color
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Theme.of(context).brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
        ),
        title: Text(
          'ScrollOff',
          style: TextStyle(
            fontFamily: 'CustomBold',
            fontWeight: FontWeight.w700,
            fontSize: 30,
            letterSpacing: 2.0,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.8),
            ),
            child: IconButton(
              icon: const Icon(Icons.settings),
              iconSize: isTablet ? 28 : 24,
              onPressed: () => Navigator.pushNamed(context, '/settings'),
            ),
          ),
        ],
      ),
      body: CustomAnimationBuilder<double>(
        duration: const Duration(milliseconds: 1200),
        tween: Tween(begin: 0.0, end: 1.0),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Column(
                  children: [
                    SizedBox(height: screenHeight * 0.025),
                    
                    // Status Card - enhanced toggle switch
                    Expanded(
                      flex: 3,
                      child: Center(
                        child: AnimatedBuilder(
                          animation: _buttonController,
                          builder: (context, child) {
                            final buttonScale = 1.0 - (_buttonController.value * 0.05);
                            return Transform.scale(
                              scale: buttonScale,
                              child: GestureDetector(
                                onTap: _toggleFocusMode,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 400),
                                  curve: Curves.easeOutBack,
                                  width: buttonWidth,
                                  height: buttonHeight,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(buttonHeight),
                                    color: _focusModeEnabled 
                                        ? Colors.red.shade400
                                        : Theme.of(context).colorScheme.primary.withOpacity(0.4),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _focusModeEnabled
                                            ? Colors.red.withOpacity(0.4)
                                            : Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                        blurRadius: _focusModeEnabled ? (isTablet ? 35 : 30) : (isTablet ? 25 : 20),
                                        spreadRadius: _focusModeEnabled ? (isTablet ? 7 : 5) : (isTablet ? 3 : 2),
                                        offset: Offset(0, isTablet ? 12 : 10),
                                      ),
                                    ],
                                  ),
                                  child: AnimatedAlign(
                                    duration: const Duration(milliseconds: 400),
                                    curve: Curves.easeOutBack,
                                    alignment: _focusModeEnabled ? Alignment.centerRight : Alignment.centerLeft,
                                    child: Row(
                                      mainAxisAlignment: _focusModeEnabled ? MainAxisAlignment.end : MainAxisAlignment.start,
                                      children: [
                                        // Show text on the left when focus mode is ON
                                        if (_focusModeEnabled)
                                          Flexible(
                                            child: AnimatedSlide(
                                              duration: const Duration(milliseconds: 500),
                                              curve: Curves.elasticOut,
                                              offset: _focusModeEnabled ? Offset.zero : const Offset(-1.0, 0.0),
                                              child: AnimatedOpacity(
                                                duration: const Duration(milliseconds: 400),
                                                opacity: _focusModeEnabled ? 1.0 : 0.0,
                                                child: Padding(
                                                  padding: EdgeInsets.only(left: buttonWidth * 0.047), // Responsive padding
                                                  child: AnimatedDefaultTextStyle(
                                                    duration: const Duration(milliseconds: 300),
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: _focusModeEnabled ? textSize : 0,
                                                      fontWeight: FontWeight.bold,
                                                      letterSpacing: letterSpacing,
                                                    ),
                                                    child: const Text('SCROLL'),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        // Toggle circle with tick/wrong icons
                                        AnimatedBuilder(
                                          animation: _pulseController,
                                          builder: (context, child) {
                                            final pulseScale = _focusModeEnabled
                                                ? 1.0 + (_pulseController.value * 0.08)
                                                : 1.0;
                                            return AnimatedScale(
                                              duration: const Duration(milliseconds: 400),
                                              curve: Curves.elasticOut,
                                              scale: pulseScale,
                                              child: AnimatedContainer(
                                                duration: const Duration(milliseconds: 400),
                                                curve: Curves.easeOutBack,
                                                margin: EdgeInsets.all(buttonHeight * 0.086), // Responsive margin
                                                width: circleSize,
                                                height: circleSize,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Colors.white,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: _focusModeEnabled 
                                                          ? Colors.red.withOpacity(0.3)
                                                          : Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                                      blurRadius: _focusModeEnabled ? (isTablet ? 25 : 20) : (isTablet ? 20 : 15),
                                                      offset: Offset(0, isTablet ? 10 : 8),
                                                    ),
                                                  ],
                                                ),
                                                child: AnimatedSwitcher(
                                                  duration: const Duration(milliseconds: 400),
                                                  switchInCurve: Curves.elasticOut,
                                                  switchOutCurve: Curves.easeInBack,
                                                  transitionBuilder: (child, animation) {
                                                    return AnimatedBuilder(
                                                      animation: animation,
                                                      builder: (context, child) {
                                                        return Transform.rotate(
                                                          angle: animation.value * 3.14159 * 2,
                                                          child: Transform.scale(
                                                            scale: animation.value,
                                                            child: child,
                                                          ),
                                                        );
                                                      },
                                                      child: child,
                                                    );
                                                  },
                                                  child: Icon(
                                                    _focusModeEnabled ? Icons.close_rounded : Icons.check_rounded,
                                                    key: ValueKey(_focusModeEnabled ? 'close' : 'check'),
                                                    size: iconSize,
                                                    color: _focusModeEnabled 
                                                        ? Colors.red.shade400
                                                        : Theme.of(context).colorScheme.primary,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        // Show text on the right when focus mode is OFF
                                        if (!_focusModeEnabled)
                                          Flexible(
                                            child: AnimatedSlide(
                                              duration: const Duration(milliseconds: 500),
                                              curve: Curves.elasticOut,
                                              offset: !_focusModeEnabled ? Offset.zero : const Offset(1.0, 0.0),
                                              child: AnimatedOpacity(
                                                duration: const Duration(milliseconds: 400),
                                                opacity: !_focusModeEnabled ? 1.0 : 0.0,
                                                child: Padding(
                                                  padding: EdgeInsets.only(right: buttonWidth * 0.063), // Responsive padding
                                                  child: AnimatedDefaultTextStyle(
                                                    duration: const Duration(milliseconds: 300),
                                                    style: TextStyle(
                                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                                                      fontSize: !_focusModeEnabled ? textSize : 0,
                                                      fontWeight: FontWeight.bold,
                                                      letterSpacing: letterSpacing,
                                                    ),
                                                    child: const Text('SCROLL'),
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
                            
                          },
                        ),
                      ),
                    ),

                    SizedBox(height: screenHeight * 0.04),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

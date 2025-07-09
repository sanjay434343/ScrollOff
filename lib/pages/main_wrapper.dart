import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'home_page.dart';
import 'apps_list_page.dart';
import 'statistics_page.dart';

class MainWrapper extends StatefulWidget {
  final int initialIndex;
  
  const MainWrapper({super.key, this.initialIndex = 0});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onNavTap(int index) {
    setState(() {
      _currentIndex = index;
    });
    // Add haptic feedback for navigation
    HapticFeedback.lightImpact();
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
        body: IndexedStack(
          index: _currentIndex,
          children: const [
            HomePage(),
            AppsListPage(),
            StatisticsPage(),
          ],
        ),
        bottomNavigationBar: Container(
          height: 60, // Reduced height since no text labels
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(
                  icon: HugeIcons.strokeRoundedHome01,
                  selectedIcon: HugeIcons.strokeRoundedHome01,
                  index: 0,
                ),
                _buildNavItem(
                  icon: HugeIcons.strokeRoundedGridTable,
                  selectedIcon: HugeIcons.strokeRoundedGridTable,
                  index: 1,
                ),
                _buildNavItem(
                  icon: HugeIcons.strokeRoundedAnalytics01,
                  selectedIcon: HugeIcons.strokeRoundedAnalytics01,
                  index: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData selectedIcon,
    required int index,
  }) {
    final isSelected = _currentIndex == index;
    
    return Expanded( // Make each item take equal space
      child: InkWell( // Better touch feedback than GestureDetector
        onTap: () => _onNavTap(index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 60, // Full height of navigation bar
          padding: const EdgeInsets.all(8), // Reduced padding for larger touch area
          child: Center(
            child: Icon(
              isSelected ? selectedIcon : icon,
              color: isSelected 
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}

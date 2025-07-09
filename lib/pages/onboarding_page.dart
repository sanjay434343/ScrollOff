import 'package:flutter/material.dart';
import 'package:simple_animations/simple_animations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:auto_size_text/auto_size_text.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  late final PageController _pageController;
  int _currentPage = 0;
  String _selectedLanguage = 'en'; // Default to English code

  final List<OnboardingItem> _onboardingItems = [
    OnboardingItem(
      icon: Icons.smartphone,
      title: 'Block Apps',
      description: 'Block social media and other distracting apps.',
    ),
    OnboardingItem(
      icon: Icons.timer,
      title: 'Focus Mode',
      description: 'Activate focus mode to boost your productivity.',
    ),
    OnboardingItem(
      icon: Icons.analytics,
      title: 'Track Progress',
      description: 'Monitor your usage patterns and saved time.',
    ),
    OnboardingItem(
      icon: Icons.language,
      title: 'Choose Language',
      description: 'Select your preferred language',
      isLanguageSelector: true,
    ),
  ];

  // Updated language options: English, Tamil, Hindi, French only
  final List<Map<String, String>> _languages = [
    {'code': 'en', 'name': 'English', 'native': 'English'},
    {'code': 'ta', 'name': 'Tamil',   'native': 'தமிழ்'},
    {'code': 'hi', 'name': 'Hindi',   'native': 'हिंदी'},
    {'code': 'fr', 'name': 'French',  'native': 'Français'},
  ];

  // Save preferences when completing onboarding
  void _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    await prefs.setString('language', _selectedLanguage);
    
    if (mounted) {
      // Navigate to music player page
      Navigator.pushReplacementNamed(context, '/music-player');
    }
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  Widget _buildLanguageSelector() {
    return Column(
      children: [
        ..._languages.map((lang) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {
              setState(() => _selectedLanguage = lang['code']!);
            },
            style: OutlinedButton.styleFrom(
              backgroundColor: _selectedLanguage == lang['code']
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  lang['native']!,
                  style: TextStyle(
                    color: _selectedLanguage == lang['code']
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : null,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${lang['name']})',
                  style: TextStyle(
                    color: _selectedLanguage == lang['code']
                        ? Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.7)
                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        )).toList(),
        if (_selectedLanguage.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.music_note,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Continue to hear sample audio in your language',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _nextPage() {
    if (_currentPage < _onboardingItems.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override 
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isCompact = screenSize.width < 400 || screenSize.height < 700;
    
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemCount: _onboardingItems.length,
              itemBuilder: (context, index) {
                final item = _onboardingItems[index];
                return CustomAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 600),
                  tween: Tween(begin: 0.0, end: 1.0),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, 30 * (1 - value)),
                        child: Padding(
                          padding: EdgeInsets.all(isCompact ? 16 : 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: EdgeInsets.all(isCompact ? 16 : 20),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(isCompact ? 30 : 50),
                                  color: Theme.of(context).colorScheme.primaryContainer,
                                ),
                                child: Icon(
                                  item.icon,
                                  size: isCompact ? 48 : 60,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              SizedBox(height: isCompact ? 20 : 24),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isCompact ? 16 : 20,
                                  vertical: isCompact ? 8 : 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: AutoSizeText(
                                  item.title,
                                  style: TextStyle(
                                    fontSize: isCompact ? 18 : 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  minFontSize: 14,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              SizedBox(height: isCompact ? 12 : 16),
                              
                              // Content for each page type
                              if (item.isLanguageSelector)
                                _buildLanguageSelector()
                              else
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isCompact ? 12 : 16,
                                    vertical: isCompact ? 6 : 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surface,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                                    ),
                                  ),
                                  child: AutoSizeText(
                                    item.description,
                                    style: TextStyle(
                                      fontSize: isCompact ? 12 : 14,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 3,
                                    minFontSize: 10,
                                    textAlign: TextAlign.center,
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
          
          // Minimal page indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _onboardingItems.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: EdgeInsets.symmetric(horizontal: isCompact ? 2 : 3),
                width: _currentPage == index ? (isCompact ? 16 : 20) : (isCompact ? 4 : 6),
                height: isCompact ? 4 : 6,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(isCompact ? 5 : 6),
                ),
              ),
            ),
          ),
          // Compact navigation buttons
          Padding(
            padding: EdgeInsets.all(isCompact ? 16 : 20),
            child: Row(
              children: [
                if (_currentPage > 0) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _previousPage,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: isCompact ? 10 : 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text('Back'),
                    ),
                  ),
                  SizedBox(width: isCompact ? 12 : 16),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: isCompact ? 10 : 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      _currentPage == _onboardingItems.length - 1 
                          ? 'Continue' 
                          : 'Next',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingItem {
  final IconData icon;
  final String title;
  final String description;
  final bool isLanguageSelector;

  OnboardingItem({
    required this.icon,
    required this.title,
    required this.description,
    this.isLanguageSelector = false,
  });
}

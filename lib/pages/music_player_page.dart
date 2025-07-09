import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/lrc_parser.dart';

class MusicPlayerPage extends StatefulWidget {
  const MusicPlayerPage({super.key});

  @override
  State<MusicPlayerPage> createState() => _MusicPlayerPageState();
}

class _MusicPlayerPageState extends State<MusicPlayerPage> with TickerProviderStateMixin {
  late final AudioPlayer _audioPlayer;
  late ScrollController _lyricsScrollController;
  late AnimationController _waveController;
  String _selectedLanguage = 'en';
  bool _soundEnabled = true;
  double _volume = 0.8;
  
  // Audio state
  bool _isAudioComplete = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isPlaying = false;

  // Lyrics
  List<LrcLine> _currentLyrics = [];
  int _currentLyricIndex = -1;

  // Languages
  final List<Map<String, String>> _languages = [
    {'code': 'en', 'name': 'English', 'native': 'English'},
    {'code': 'ta', 'name': 'Tamil',   'native': 'தமிழ்'},
    {'code': 'hi', 'name': 'Hindi',   'native': 'हिंदी'},
    {'code': 'fr', 'name': 'French',  'native': 'Français'},
  ];

  // Audio and LRC file mappings
  final Map<String, String> _languageAudio = {
    'en': 'audio/eng.mp3',
    'ta': 'audio/tam.mp3',
    'hi': 'audio/hindi.mp3',
    'fr': 'audio/french.mp3',
  };

  final Map<String, String> _languageLrcFiles = {
    'en': 'assets/audio/eng.lrc',
    'ta': 'assets/audio/tam.lrc',
    'hi': 'assets/audio/hindi.lrc',
    'fr': 'assets/audio/french.lrc',
  };

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _lyricsScrollController = ScrollController();
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _loadSettings();
    _setupAudioListeners();
  }

  void _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedLanguage = prefs.getString('language') ?? 'en';
      _soundEnabled = prefs.getBool('sound_enabled') ?? true;
      _volume = prefs.getDouble('sound_volume') ?? 0.8;
    });
    
    // Auto-play the selected language
    if (_soundEnabled) {
      _playLanguageAudio(_selectedLanguage);
    }
  }

  void _setupAudioListeners() {
    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
        _updateLyricSync(position);
      }
    });

    _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() {
          _totalDuration = duration;
        });
      }
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isAudioComplete = true;
          _isPlaying = false;
          _currentPosition = Duration.zero;
        });
        _waveController.stop();
      }
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
        
        if (_isPlaying) {
          _waveController.repeat();
        } else {
          _waveController.stop();
        }
      }
    });
  }

  Future<void> _loadLyricsForLanguage(String langCode) async {
    final lrcFile = _languageLrcFiles[langCode];
    if (lrcFile != null) {
      final lyrics = await LrcParser.parseLrcFile(lrcFile);
      setState(() {
        _currentLyrics = lyrics;
        _currentLyricIndex = -1;
      });
    }
  }

  void _updateLyricSync(Duration position) {
    if (_currentLyrics.isEmpty) return;

    final newIndex = LrcParser.getCurrentLineIndex(_currentLyrics, position);
    if (newIndex != _currentLyricIndex) {
      setState(() {
        _currentLyricIndex = newIndex;
        _currentLyrics = LrcParser.updateActiveLine(_currentLyrics, newIndex);
      });
      _scrollToCurrentLyric();
    }
  }

  void _scrollToCurrentLyric() {
    if (!_lyricsScrollController.hasClients || _currentLyricIndex < 0) return;
    
    const itemHeight = 80.0; // Approximate height per lyric line
    final targetOffset = (_currentLyricIndex * itemHeight) - (MediaQuery.of(context).size.height * 0.3);
    
    _lyricsScrollController.animateTo(
      targetOffset.clamp(0.0, _lyricsScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _playLanguageAudio(String langCode) async {
    final audioFile = _languageAudio[langCode];
    if (audioFile != null) {
      try {
        setState(() {
          _isAudioComplete = false;
          _currentPosition = Duration.zero;
        });
        
        await _audioPlayer.stop();
        await _audioPlayer.setVolume(_volume);
        await _audioPlayer.play(AssetSource(audioFile));
        await _loadLyricsForLanguage(langCode);
        
        print('Started playing audio: $audioFile');
      } catch (e) {
        print('Error playing audio: $e');
      }
    }
  }

  void _togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      if (_isAudioComplete) {
        await _playLanguageAudio(_selectedLanguage);
      } else {
        await _audioPlayer.resume();
      }
    }
  }

  void _seekTo(double value) async {
    final position = Duration(milliseconds: (value * _totalDuration.inMilliseconds).round());
    await _audioPlayer.seek(position);
  }

  void _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', _selectedLanguage);
    await prefs.setBool('sound_enabled', _soundEnabled);
    await prefs.setDouble('sound_volume', _volume);
  }

  void _continueToPreviousPage() async {
    _saveSettings();
    
    // Mark music player as completed
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('music_player_completed', true);
    
    // Navigate to permissions page
    Navigator.pushReplacementNamed(context, '/permissions');
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _lyricsScrollController.dispose();
    _waveController.dispose();
    super.dispose();
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
        extendBodyBehindAppBar: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Stack(
          children: [
            // Device color gradient background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                    Theme.of(context).colorScheme.surface,
                    Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                  ],
                ),
              ),
            ),
            // Blur overlay
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                color: Theme.of(context).colorScheme.surface.withOpacity(0.1),
              ),
            ),
            // Content
            SafeArea(
              child: Column(
                children: [
                  // Lyrics Display (now takes full space)
                  Expanded(
                    child: _buildLyricsDisplay(),
                  ),
                  
                  // Progress Bar
                  _buildProgressBar(),
                  
                  // Continue Button (always visible)
                  _buildNextButton(),
                  
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLyricsDisplay() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: _currentLyrics.isEmpty 
        ? _buildEmptyLyrics()
        : _buildLyricsList(),
    );
  }

  Widget _buildLyricsList() {
    return ListView.builder(
      controller: _lyricsScrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 50),
      itemCount: _currentLyrics.length,
      itemBuilder: (context, index) {
        final line = _currentLyrics[index];
        final isActive = index == _currentLyricIndex;
        final isPast = index < _currentLyricIndex;
        final isNext = index == _currentLyricIndex + 1;
        
        return GestureDetector(
          onTap: _togglePlayPause,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOutCubic,
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: EdgeInsets.symmetric(
              horizontal: 24,
              vertical: isActive ? 12 : 6,
            ),
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: isActive ? 0.0 : 2.0,
                  sigmaY: isActive ? 0.0 : 2.0,
                ),
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeInOutCubic,
                  style: TextStyle(
                    fontSize: isActive ? 28 : (isNext ? 22 : 18),
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                    color: isActive 
                      ? Theme.of(context).colorScheme.primary
                      : isPast
                        ? Theme.of(context).colorScheme.onSurface.withOpacity(0.3)
                        : isNext
                          ? Theme.of(context).colorScheme.onSurface.withOpacity(0.5)
                          : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                    height: isActive ? 1.2 : 1.3,
                    letterSpacing: isActive ? 0.5 : 0.2,
                  ),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 600),
                    opacity: isActive ? 1.0 : (isPast ? 0.3 : (isNext ? 0.6 : 0.4)),
                    child: Text(
                      line.text,
                      textAlign: TextAlign.left,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyLyrics() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100, // Increased icon container size
            height: 100,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lyrics_outlined,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
              size: 48, // Increased icon size
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Select a language to hear\nsample audio',
            style: TextStyle(
              fontSize: 20, // Increased font size
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.9),
              height: 1.5,
              fontWeight: FontWeight.w500, // Added font weight
            ),
            textAlign: TextAlign.center, // Changed to center for empty state
          ),
          const SizedBox(height: 40), // Increased spacing
          _buildLanguageSelector(),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: _languages.map((lang) => 
        GestureDetector(
          onTap: () {
            setState(() => _selectedLanguage = lang['code']!);
            if (_soundEnabled) {
              _playLanguageAudio(lang['code']!);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _selectedLanguage == lang['code']
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _selectedLanguage == lang['code']
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
                  : Theme.of(context).colorScheme.outline.withOpacity(0.2),
              ),
            ),
            child: Text(
              lang['native']!,
              style: TextStyle(
                color: _selectedLanguage == lang['code']
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                fontWeight: _selectedLanguage == lang['code']
                  ? FontWeight.w600
                  : FontWeight.w400,
              ),
            ),
          ),
        ),
      ).toList(),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          // Animated waveform visualization
          Container(
            height: 60,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(30),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: AnimatedBuilder(
                animation: _waveController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: WaveformPainter(
                      progress: _totalDuration.inMilliseconds > 0
                          ? _currentPosition.inMilliseconds / _totalDuration.inMilliseconds
                          : 0.0,
                      isPlaying: _isPlaying,
                      animationValue: _waveController.value,
                      primaryColor: Theme.of(context).colorScheme.primary,
                      backgroundColor: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                    ),
                    size: Size.infinite,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: ElevatedButton.icon(
        onPressed: _isAudioComplete ? _continueToPreviousPage : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isAudioComplete 
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.surfaceVariant,
          foregroundColor: _isAudioComplete 
            ? Theme.of(context).colorScheme.onPrimary
            : Theme.of(context).colorScheme.onSurfaceVariant,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
          elevation: _isAudioComplete ? 8 : 2,
          shadowColor: _isAudioComplete 
            ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
            : Colors.transparent,
        ),
        icon: Icon(
          Icons.arrow_forward_rounded, 
          size: 24,
          color: _isAudioComplete 
            ? Theme.of(context).colorScheme.onPrimary
            : Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
        ),
        label: Text(
          'Continue',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _isAudioComplete 
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
        ),
      ),
    );
  }

  String _getLanguageName(String code) {
    final lang = _languages.firstWhere(
      (l) => l['code'] == code,
      orElse: () => {'name': 'Unknown'},
    );
    return lang['name'] ?? 'Unknown';
  }
}

class WaveformPainter extends CustomPainter {
  final double progress;
  final bool isPlaying;
  final double animationValue;
  final Color primaryColor;
  final Color backgroundColor;

  WaveformPainter({
    required this.progress,
    required this.isPlaying,
    required this.animationValue,
    required this.primaryColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = backgroundColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final activePaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // Generate waveform bars
    const barCount = 40;
    final barWidth = size.width / barCount;
    final centerY = size.height / 2;
    
    for (int i = 0; i < barCount; i++) {
      final x = i * barWidth + barWidth / 2;
      final progressPoint = i / barCount;
      final isActive = progressPoint <= progress;
      
      // Create animated wave heights
      final baseHeight = size.height * 0.2;
      final waveOffset = (i * 0.3 + animationValue * 2 * math.pi) % (2 * math.pi);
      final animatedHeight = isPlaying 
          ? baseHeight + (math.sin(waveOffset) * size.height * 0.15)
          : baseHeight * (0.5 + math.sin(i * 0.5) * 0.3);
      
      // Draw the bar
      final currentPaint = isActive ? activePaint : paint;
      canvas.drawLine(
        Offset(x, centerY - animatedHeight / 2),
        Offset(x, centerY + animatedHeight / 2),
        currentPaint,
      );
    }
    
    // Draw a subtle progress indicator line
    if (progress > 0) {
      final progressX = size.width * progress;
      final progressPaint = Paint()
        ..color = primaryColor.withOpacity(0.6)
        ..strokeWidth = 1;
      
      canvas.drawLine(
        Offset(progressX, 0),
        Offset(progressX, size.height),
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.isPlaying != isPlaying ||
           oldDelegate.animationValue != animationValue;
  }
}
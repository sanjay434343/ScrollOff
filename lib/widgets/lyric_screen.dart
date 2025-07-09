import 'package:flutter/material.dart';
import 'dart:ui';
import '../services/lrc_parser.dart';

class LyricScreen extends StatefulWidget {
  final List<LrcLine> lyrics;
  final int currentLyricIndex;
  final VoidCallback? onTap;

  const LyricScreen({
    super.key,
    required this.lyrics,
    required this.currentLyricIndex,
    this.onTap,
  });

  @override
  State<LyricScreen> createState() => _LyricScreenState();
}

class _LyricScreenState extends State<LyricScreen> with TickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _fadeController.forward();
  }

  @override
  void didUpdateWidget(LyricScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentLyricIndex != oldWidget.currentLyricIndex) {
      _scrollToCurrentLyric();
    }
  }

  void _scrollToCurrentLyric() {
    if (_scrollController.hasClients && widget.currentLyricIndex >= 0) {
      const itemHeight = 70.0;
      final targetOffset = (widget.currentLyricIndex * itemHeight) - 140;
      
      _scrollController.animateTo(
        targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              color: isDark 
                  ? Colors.black.withOpacity(0.95)
                  : Colors.white.withOpacity(0.98),
            ),
            child: widget.lyrics.isEmpty ? _buildEmptyState() : _buildLyricsList(),
          ),
        );
      },
    );
  }

  Widget _buildLyricsList() {
    return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 100),
          physics: const BouncingScrollPhysics(),
          itemCount: widget.lyrics.length,
          itemBuilder: (context, index) {
            final line = widget.lyrics[index];
            final isActive = index == widget.currentLyricIndex;
            final isPast = widget.currentLyricIndex > index;
            final isFuture = widget.currentLyricIndex < index;
            
            return _buildLyricLine(line.text, isActive, isPast, isFuture, index);
          },
        ),
        // Top gradient overlay
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 80,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).colorScheme.surface,
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Bottom gradient overlay
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 80,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Theme.of(context).colorScheme.surface,
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLyricLine(String text, bool isActive, bool isPast, bool isFuture, int index) {
    final theme = Theme.of(context);
    final distance = (widget.currentLyricIndex - index).abs();
    final opacity = isActive ? 1.0 : isPast ? 0.4 : (distance == 1 ? 0.7 : 0.5);
    
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: BoxDecoration(
          color: isActive
              ? theme.colorScheme.primary.withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 400),
          style: TextStyle(
            fontSize: isActive ? 32 : 26,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withOpacity(opacity),
            height: 1.5,
            letterSpacing: isActive ? 0.3 : 0.1,
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lyrics_outlined,
              color: theme.colorScheme.primary.withOpacity(0.6),
              size: 36,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Lyrics Available',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withOpacity(0.8),
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Lyrics will appear here when available',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }
}

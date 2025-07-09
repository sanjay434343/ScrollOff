import 'dart:convert';
import 'package:flutter/services.dart';

class LrcLine {
  final Duration timestamp;
  final String text;
  final bool isActive;

  LrcLine({
    required this.timestamp,
    required this.text,
    this.isActive = false,
  });

  LrcLine copyWith({bool? isActive}) {
    return LrcLine(
      timestamp: timestamp,
      text: text,
      isActive: isActive ?? this.isActive,
    );
  }
}

class LrcParser {
  static Future<List<LrcLine>> parseLrcFile(String assetPath) async {
    try {
      final String content = await rootBundle.loadString(assetPath);
      return parseLrcContent(content);
    } catch (e) {
      print('Error loading LRC file: $e');
      return [];
    }
  }

  static List<LrcLine> parseLrcContent(String content) {
    final List<LrcLine> lines = [];
    final List<String> contentLines = content.split('\n');

    for (String line in contentLines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;

      // Parse timestamp format [mm:ss.xx] or [mm:ss]
      final RegExp timeRegex = RegExp(r'\[(\d{2}):(\d{2})(?:\.(\d{2}))?\](.*)');
      final Match? match = timeRegex.firstMatch(trimmedLine);

      if (match != null) {
        final int minutes = int.parse(match.group(1)!);
        final int seconds = int.parse(match.group(2)!);
        final int centiseconds = match.group(3) != null ? int.parse(match.group(3)!) : 0;
        final String text = match.group(4)!.trim();

        if (text.isNotEmpty) {
          final Duration timestamp = Duration(
            minutes: minutes,
            seconds: seconds,
            milliseconds: centiseconds * 10,
          );

          lines.add(LrcLine(
            timestamp: timestamp,
            text: text,
          ));
        }
      }
    }

    // Sort by timestamp
    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return lines;
  }

  static int getCurrentLineIndex(List<LrcLine> lines, Duration currentPosition) {
    if (lines.isEmpty) return -1;

    for (int i = lines.length - 1; i >= 0; i--) {
      if (currentPosition >= lines[i].timestamp) {
        return i;
      }
    }
    return -1;
  }

  static List<LrcLine> updateActiveLine(List<LrcLine> lines, int activeIndex) {
    return lines.asMap().entries.map((entry) {
      final int index = entry.key;
      final LrcLine line = entry.value;
      return line.copyWith(isActive: index == activeIndex);
    }).toList();
  }
}

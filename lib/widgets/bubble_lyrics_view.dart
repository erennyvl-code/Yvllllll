import 'dart:async';
import 'package:flutter/material.dart';

/// Parses LRC-format synced lyrics into (time, text) pairs
List<_LrcLine> _parseLrc(String lrc) {
  final lines = <_LrcLine>[];
  final regex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');
  for (final raw in lrc.split('\n')) {
    final match = regex.firstMatch(raw.trim());
    if (match == null) continue;
    final min = int.parse(match.group(1)!);
    final sec = int.parse(match.group(2)!);
    final cs = int.parse(match.group(3)!.padRight(3, '0').substring(0, 3));
    final text = match.group(4)!.trim();
    if (text.isEmpty) continue;
    lines.add(_LrcLine(
      time: Duration(minutes: min, seconds: sec, milliseconds: cs),
      text: text,
    ));
  }
  lines.sort((a, b) => a.time.compareTo(b.time));
  return lines;
}

class _LrcLine {
  final Duration time;
  final String text;
  const _LrcLine({required this.time, required this.text});
}

/// Beautiful bubble-style lyrics where each line floats in as a chat bubble.
/// Current line is large + bright; surrounding lines are smaller + dimmer.
class BubbleLyricsView extends StatefulWidget {
  final String syncedLyrics;
  final String plainLyrics;
  final Stream<Duration> positionStream;
  final Color? accentColor;

  const BubbleLyricsView({
    super.key,
    required this.syncedLyrics,
    required this.plainLyrics,
    required this.positionStream,
    this.accentColor,
  });

  @override
  State<BubbleLyricsView> createState() => _BubbleLyricsViewState();
}

class _BubbleLyricsViewState extends State<BubbleLyricsView> {
  List<_LrcLine> _lines = [];
  int _currentIndex = -1;
  StreamSubscription<Duration>? _sub;
  final ScrollController _scroll = ScrollController();
  final Map<int, GlobalKey> _keys = {};

  @override
  void initState() {
    super.initState();
    _parse();
    _sub = widget.positionStream.listen(_onPosition);
  }

  void _parse() {
    if (widget.syncedLyrics.isNotEmpty) {
      _lines = _parseLrc(widget.syncedLyrics);
    }
    for (int i = 0; i < _lines.length; i++) {
      _keys[i] = GlobalKey();
    }
  }

  void _onPosition(Duration pos) {
    if (_lines.isEmpty) return;
    int idx = -1;
    for (int i = 0; i < _lines.length; i++) {
      if (_lines[i].time <= pos) idx = i;
    }
    if (idx != _currentIndex) {
      setState(() => _currentIndex = idx);
      _scrollTo(idx);
    }
  }

  void _scrollTo(int idx) {
    if (idx < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _keys[idx];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          alignment: 0.35,
        );
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_lines.isEmpty) {
      // Fallback: plain lyrics
      final lines = widget.plainLyrics
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();
      return ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        itemCount: lines.length,
        itemBuilder: (context, i) => _BubbleItem(
          text: lines[i],
          isCurrent: false,
          isPast: false,
          accentColor: widget.accentColor,
        ),
      );
    }

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      itemCount: _lines.length,
      itemBuilder: (context, i) {
        final isCurrent = i == _currentIndex;
        final isPast = i < _currentIndex;
        return _BubbleItem(
          key: _keys[i],
          text: _lines[i].text,
          isCurrent: isCurrent,
          isPast: isPast,
          accentColor: widget.accentColor,
        );
      },
    );
  }
}

class _BubbleItem extends StatelessWidget {
  final String text;
  final bool isCurrent;
  final bool isPast;
  final Color? accentColor;

  const _BubbleItem({
    super.key,
    required this.text,
    required this.isCurrent,
    required this.isPast,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    // Visual states
    final double opacity = isCurrent ? 1.0 : isPast ? 0.38 : 0.55;
    final double fontSize = isCurrent ? 20 : 15;
    final FontWeight weight = isCurrent ? FontWeight.w800 : FontWeight.w600;

    // Bubble style
    final Color bgColor = isCurrent
        ? accent.withValues(alpha: 0.18)
        : Colors.white.withValues(alpha: isCurrent ? 0.12 : 0.04);

    final Color borderColor = isCurrent
        ? accent.withValues(alpha: 0.5)
        : Colors.white.withValues(alpha: 0.08);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      margin: EdgeInsets.only(
        bottom: isCurrent ? 14 : 8,
        left: isCurrent ? 0 : 8,
        right: isCurrent ? 0 : 8,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isCurrent ? 18 : 14,
        vertical: isCurrent ? 14 : 10,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(isCurrent ? 22 : 16),
        border: Border.all(color: borderColor, width: isCurrent ? 1.5 : 1),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.25),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ]
            : [],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (isCurrent) ...[
            Container(
              width: 4,
              height: fontSize * 1.5,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: TextStyle(
                color: isCurrent ? onSurface : onSurface.withValues(alpha: opacity),
                fontSize: fontSize,
                fontWeight: weight,
                height: 1.35,
                letterSpacing: isCurrent ? 0.2 : 0,
              ),
              child: Text(text),
            ),
          ),
        ],
      ),
    );
  }
}

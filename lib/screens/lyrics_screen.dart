import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:yvl/services/lyrics_service.dart';
import 'package:yvl/widgets/lyrics_view.dart';
import 'package:yvl/widgets/bubble_lyrics_view.dart';
import 'package:yvl/providers/player_provider.dart';
import 'package:yvl/providers/theme_provider.dart';
import 'dart:ui';

class LyricsScreen extends ConsumerStatefulWidget {
  final String title;
  final String artist;
  final String? thumbnailUrl;
  final int durationSeconds;

  const LyricsScreen({
    super.key,
    required this.title,
    required this.artist,
    this.thumbnailUrl,
    required this.durationSeconds,
  });

  @override
  ConsumerState<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends ConsumerState<LyricsScreen> {
  Lyrics? _lyrics;
  bool _isLoading = true;
  bool _isBubbleMode = false; // Toggle: regular vs bubble lyrics

  @override
  void initState() {
    super.initState();
    _fetchLyrics();
  }

  Future<void> _fetchLyrics() async {
    try {
      final lyrics = await ref
          .read(lyricsServiceProvider)
          .fetchLyrics(widget.title, widget.artist, widget.durationSeconds);
      if (mounted) {
        setState(() {
          _lyrics = lyrics;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioHandler = ref.watch(audioHandlerProvider);
    final accentColor = ref.watch(currentPaletteProvider).asData?.value
        ?.darkVibrantColor?.color;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(FluentIcons.chevron_down_24_regular,
              color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          children: [
            Text('Lyrics',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
            Text('${widget.title} • ${widget.artist}',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.normal),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
        centerTitle: true,
        actions: [
          // Bubble mode toggle button
          if (_lyrics != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Tooltip(
                message: _isBubbleMode ? 'Classic view' : 'Bubble view',
                child: GestureDetector(
                  onTap: () => setState(() => _isBubbleMode = !_isBubbleMode),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _isBubbleMode
                          ? (accentColor ?? Theme.of(context).colorScheme.primary)
                              .withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isBubbleMode
                            ? (accentColor ?? Theme.of(context).colorScheme.primary)
                                .withValues(alpha: 0.6)
                            : Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isBubbleMode
                              ? Icons.chat_bubble_rounded
                              : Icons.chat_bubble_outline_rounded,
                          size: 14,
                          color: _isBubbleMode
                              ? (accentColor ?? Colors.white)
                              : Colors.white.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Bubbles',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _isBubbleMode
                                ? (accentColor ?? Colors.white)
                                : Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: RepaintBoundary(
              child: widget.thumbnailUrl != null
                  ? Image.network(widget.thumbnailUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: Colors.black))
                  : Container(color: Colors.black),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: Container(color: Colors.black.withValues(alpha: 0.62)),
            ),
          ),

          // Content
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : _lyrics == null
                    ? _buildNotFound()
                    : AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        child: _isBubbleMode
                            ? BubbleLyricsView(
                                key: const ValueKey('bubble'),
                                syncedLyrics: _lyrics!.syncedLyrics,
                                plainLyrics: _lyrics!.plainLyrics,
                                positionStream: audioHandler.player.positionStream,
                                accentColor: accentColor,
                              )
                            : LyricsView(
                                key: const ValueKey('classic'),
                                lyrics: _lyrics!,
                                onClose: () {},
                                positionStream: audioHandler.player.positionStream,
                                totalDuration: audioHandler.player.duration ?? Duration.zero,
                                isEmbedded: false,
                                accentColor: accentColor,
                              ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(FluentIcons.text_quote_24_regular, size: 64,
              color: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(height: 24),
          Text('Lyrics not found',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 8),
          Text("We couldn't find lyrics for this song.",
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14)),
        ],
      ),
    );
  }
}

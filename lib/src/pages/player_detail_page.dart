import 'package:flutter/material.dart';

import '../controllers/music_player_controller.dart';
import '../models/music_models.dart';
import '../theme/app_theme.dart';
import '../widgets/album_art.dart';

class PlayerDetailPage extends StatefulWidget {
  const PlayerDetailPage({super.key, required this.player});

  final MusicPlayerController player;

  @override
  State<PlayerDetailPage> createState() => _PlayerDetailPageState();
}

class _PlayerDetailPageState extends State<PlayerDetailPage> {
  final _lyricsController = ScrollController();
  bool _userSeeking = false;
  double _seekValue = 0;
  int _activeLyricIndex = -1;
  String _lyricsSignature = '';

  @override
  void initState() {
    super.initState();
    widget.player.addListener(_syncLyrics);
    _syncLyrics();
  }

  @override
  void dispose() {
    widget.player.removeListener(_syncLyrics);
    _lyricsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: widget.player,
        builder: (context, _) {
          final player = widget.player;
          final track = player.currentTrack;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTopBar(player),
                      const SizedBox(height: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              _buildPlayerPanel(player, track),
                              const SizedBox(height: 14),
                              _buildLyricsPanel(player),
                            ],
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
    );
  }

  Widget _buildTopBar(MusicPlayerController player) {
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
          label: const Text('返回'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            player.status.isEmpty ? '播放详情' : player.status,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerPanel(MusicPlayerController player, Track? track) {
    final durationMs = player.duration.inMilliseconds <= 0
        ? 1000
        : player.duration.inMilliseconds;
    final positionMs = _userSeeking
        ? _seekValue.round()
        : player.position.inMilliseconds.clamp(0, durationMs);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AlbumArt(
                url: player.albumUrl,
                bytes: player.albumBytes,
                size: 96,
                iconSize: 42,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track?.name ?? '还没有播放歌曲',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      track?.artistText ?? '从首页选择歌曲播放',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      track?.album ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Slider(
            value: positionMs.toDouble(),
            max: durationMs.toDouble(),
            onChanged: player.playable
                ? (value) {
                    setState(() {
                      _userSeeking = true;
                      _seekValue = value;
                    });
                  }
                : null,
            onChangeEnd: player.playable
                ? (value) {
                    setState(() => _userSeeking = false);
                    widget.player.seekTo(Duration(milliseconds: value.round()));
                  }
                : null,
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  _formatTime(Duration(milliseconds: positionMs)),
                  style: const TextStyle(color: AppColors.muted),
                ),
              ),
              Text(
                _formatTime(player.duration),
                style: const TextStyle(color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: player.playable ? player.togglePlayback : null,
                  icon: Icon(
                    player.preparing
                        ? Icons.hourglass_top
                        : player.playing
                        ? Icons.pause
                        : Icons.play_arrow,
                  ),
                  label: Text(
                    player.preparing
                        ? '加载中'
                        : player.playing
                        ? '暂停'
                        : '播放',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: track == null || player.downloading
                      ? null
                      : _download,
                  icon: Icon(
                    player.downloading ? Icons.hourglass_top : Icons.download,
                  ),
                  label: Text(player.downloading ? '下载中' : '下载当前歌曲'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLyricsPanel(MusicPlayerController player) {
    final lyrics = player.lyrics;
    return Container(
      height: 430,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '歌词',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: lyrics.isEmpty
                ? const Center(
                    child: Text(
                      '暂无歌词',
                      style: TextStyle(color: AppColors.muted, fontSize: 15),
                    ),
                  )
                : ListView.builder(
                    controller: _lyricsController,
                    padding: const EdgeInsets.symmetric(vertical: 110),
                    itemCount: lyrics.length,
                    itemBuilder: (context, index) {
                      final line = lyrics[index];
                      final active = index == _activeLyricIndex;
                      return AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        style: TextStyle(
                          color: active
                              ? AppColors.accentDark
                              : AppColors.muted,
                          fontSize: active ? 19 : 16,
                          fontWeight: active
                              ? FontWeight.w800
                              : FontWeight.w400,
                          height: 1.35,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 7,
                          ),
                          child: Text(line.text, textAlign: TextAlign.center),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _syncLyrics() {
    final track = widget.player.currentTrack;
    final lyrics = widget.player.lyrics;
    final signature = '${track?.id ?? ''}:${lyrics.length}';
    if (signature != _lyricsSignature) {
      _lyricsSignature = signature;
      _activeLyricIndex = -1;
    }
    final nextIndex = _findActiveLyric(lyrics, widget.player.position);
    if (nextIndex == _activeLyricIndex) {
      return;
    }
    _activeLyricIndex = nextIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_lyricsController.hasClients || nextIndex < 0) {
        return;
      }
      const estimatedLineHeight = 54.0;
      final viewport = _lyricsController.position.viewportDimension;
      final target = (nextIndex * estimatedLineHeight) - viewport / 2;
      _lyricsController.animateTo(
        target.clamp(0.0, _lyricsController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  int _findActiveLyric(List<LyricLine> lyrics, Duration position) {
    if (lyrics.isEmpty) {
      return -1;
    }
    var index = 0;
    for (var i = 0; i < lyrics.length; i++) {
      if (lyrics[i].time <= position) {
        index = i;
      } else {
        break;
      }
    }
    return index;
  }

  Future<void> _download() async {
    await widget.player.downloadCurrent();
    if (!mounted || widget.player.status.isEmpty) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.player.status),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatTime(Duration duration) {
    final seconds = duration.inSeconds.clamp(0, 24 * 60 * 60);
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
  }
}

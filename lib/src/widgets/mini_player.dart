import 'package:flutter/material.dart';

import '../controllers/music_player_controller.dart';
import '../pages/player_detail_page.dart';
import '../theme/app_theme.dart';
import 'album_art.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key, required this.player});

  final MusicPlayerController player;

  @override
  Widget build(BuildContext context) {
    final track = player.currentTrack;
    if (track == null) {
      return const SizedBox.shrink();
    }

    final durationMs = player.duration.inMilliseconds;
    final progress = durationMs <= 0
        ? null
        : (player.position.inMilliseconds / durationMs).clamp(0.0, 1.0);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Material(
        color: AppColors.surface,
        elevation: 10,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PlayerDetailPage(player: player),
              ),
            );
          },
          child: SizedBox(
            height: 78,
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 3,
                    color: AppColors.accent,
                    backgroundColor: AppColors.surfaceSoft,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 7, 8, 8),
                    child: Row(
                      children: [
                        AlbumArt(
                          url: player.albumUrl,
                          bytes: player.albumBytes,
                          size: 48,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                track.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.ink,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                track.artistText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          tooltip: player.playing ? '暂停' : '播放',
                          onPressed: player.playable
                              ? () => player.togglePlayback()
                              : null,
                          icon: Icon(
                            player.preparing
                                ? Icons.hourglass_top
                                : player.playing
                                ? Icons.pause
                                : Icons.play_arrow,
                          ),
                        ),
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
  }
}

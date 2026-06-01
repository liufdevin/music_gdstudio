import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AlbumArt extends StatelessWidget {
  const AlbumArt({
    super.key,
    required this.url,
    this.bytes,
    this.size = 56,
    this.iconSize = 28,
  });

  final String? url;
  final Uint8List? bytes;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final imageUrl = url?.trim();
    final imageBytes = bytes;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: size,
        height: size,
        color: AppColors.surfaceSoft,
        child: imageBytes != null && imageBytes.isNotEmpty
            ? Image.memory(
                imageBytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => _fallbackIcon(),
              )
            : imageUrl == null || imageUrl.isEmpty
            ? _fallbackIcon()
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                headers: const {'User-Agent': 'Mozilla/5.0 Flutter GD Music'},
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => Icon(
                  Icons.music_note,
                  color: AppColors.accent,
                  size: iconSize,
                ),
              ),
      ),
    );
  }

  Widget _fallbackIcon() {
    return Icon(Icons.music_note, color: AppColors.accent, size: iconSize);
  }
}

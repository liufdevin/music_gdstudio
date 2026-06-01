import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import 'src/controllers/music_player_controller.dart';
import 'src/pages/home_page.dart';
import 'src/services/gd_audio_handler.dart';
import 'src/services/music_api_client.dart';
import 'src/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final audioHandler = await AudioService.init(
    builder: GdAudioHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.music_gdstudio.audio',
      androidNotificationChannelName: '音乐播放',
      androidStopForegroundOnPause: false,
    ),
  );
  runApp(MusicGdStudioApp(audioHandler: audioHandler));
}

class MusicGdStudioApp extends StatefulWidget {
  const MusicGdStudioApp({super.key, required this.audioHandler});

  final AudioHandler audioHandler;

  @override
  State<MusicGdStudioApp> createState() => _MusicGdStudioAppState();
}

class _MusicGdStudioAppState extends State<MusicGdStudioApp> {
  late final MusicApiClient _api;
  late final MusicPlayerController _player;

  @override
  void initState() {
    super.initState();
    _api = MusicApiClient();
    _player = MusicPlayerController(
      api: _api,
      audioHandler: widget.audioHandler,
    );
  }

  @override
  void dispose() {
    _player.dispose();
    _api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LF Music',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: HomePage(api: _api, player: _player),
    );
  }
}

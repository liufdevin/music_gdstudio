import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

import '../models/music_models.dart';
import '../services/download_saver.dart';
import '../services/music_api_client.dart';

class MusicPlayerController extends ChangeNotifier {
  MusicPlayerController({
    required AudioHandler audioHandler,
    MusicApiClient? api,
  }) : _audioHandler = audioHandler,
       _api = api ?? MusicApiClient() {
    _subscriptions = <StreamSubscription<dynamic>>[
      _audioHandler.playbackState.listen(_handlePlaybackState),
      _audioHandler.mediaItem.listen(_handleMediaItem),
    ];
  }

  static const _trackIdKey = 'trackId';
  static const _artistsKey = 'artists';
  static const _albumKey = 'album';
  static const _picIdKey = 'picId';
  static const _lyricIdKey = 'lyricId';
  static const _sourceKey = 'source';
  static const _requestedBitrateKey = 'requestedBitrate';
  static const _actualBitrateKey = 'actualBitrate';

  final AudioHandler _audioHandler;
  final MusicApiClient _api;
  final http.Client _downloadClient = http.Client();
  late final List<StreamSubscription<dynamic>> _subscriptions;

  Track? currentTrack;
  String? albumUrl;
  Uint8List? albumBytes;
  List<LyricLine> lyrics = const <LyricLine>[];
  String? currentSongUrl;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  bool playing = false;
  bool preparing = false;
  bool playable = false;
  bool downloading = false;
  int downloadTotal = 0;
  int downloadCompleted = 0;
  String status = '';
  int requestedBitrate = bitrateOptions.first.value;
  int actualBitrate = 0;

  int _playRequest = 0;
  PlaybackState _lastPlaybackState = PlaybackState();
  Timer? _positionTimer;

  Future<void> playTrack(Track track, int bitrate) async {
    final request = ++_playRequest;
    requestedBitrate = normalizeBitrate(bitrate);
    actualBitrate = 0;
    currentTrack = track;
    albumUrl = null;
    albumBytes = null;
    lyrics = const <LyricLine>[];
    currentSongUrl = null;
    position = Duration.zero;
    duration = Duration.zero;
    playing = false;
    preparing = true;
    playable = false;
    status = '正在获取播放地址：${labelForBitrate(requestedBitrate)}';
    notifyListeners();

    unawaited(_loadLyrics(track, request));
    final albumUrlFuture = _loadAlbumUrl(track, request);

    try {
      final songUrl = await _api.fetchSongUrl(track, requestedBitrate);
      if (!_isCurrentRequest(track, request)) {
        return;
      }
      if (songUrl.url.trim().isEmpty) {
        throw const MusicApiException('接口没有返回可播放链接');
      }

      final artUrl = await albumUrlFuture;
      currentSongUrl = songUrl.url;
      actualBitrate = songUrl.bitrate;
      status = '正在缓冲：${track.name}';
      notifyListeners();

      await _audioHandler.playMediaItem(
        _mediaItemForTrack(track, songUrl, artUrl),
      );
      if (!_isCurrentRequest(track, request)) {
        return;
      }
      preparing = false;
      playable = true;
      playing = true;
      status =
          '正在播放：${track.name}（${labelForBitrate(actualBitrate > 0 ? actualBitrate : requestedBitrate)}）';
      notifyListeners();
    } catch (error) {
      if (!_isCurrentRequest(track, request)) {
        return;
      }
      preparing = false;
      playable = false;
      playing = false;
      status = '播放失败：${describeError(error)}';
      notifyListeners();
    }
  }

  Future<void> togglePlayback() async {
    if (!playable) {
      return;
    }
    try {
      if (playing) {
        await _audioHandler.pause();
        playing = false;
        preparing = false;
        playable = currentSongUrl != null;
        status = '已暂停';
      } else {
        playing = true;
        preparing = false;
        playable = true;
        if (_lastPlaybackState.processingState ==
            AudioProcessingState.completed) {
          position = Duration.zero;
        }
        status = currentTrack == null ? '正在播放' : '正在播放：${currentTrack!.name}';
        _updatePositionTimer();
        notifyListeners();
        await _audioHandler.play();
      }
      _updatePositionTimer();
      notifyListeners();
    } catch (error) {
      playing = false;
      preparing = false;
      status = '播放器错误：${describeError(error)}';
      notifyListeners();
    }
  }

  Future<void> seekTo(Duration value) async {
    if (!playable) {
      return;
    }
    try {
      await _audioHandler.seek(value);
      position = value;
      notifyListeners();
    } catch (error) {
      status = '定位失败：${describeError(error)}';
      notifyListeners();
    }
  }

  Future<void> downloadCurrent() async {
    final track = currentTrack;
    if (track == null) {
      status = '请先选择歌曲';
      notifyListeners();
      return;
    }
    await downloadTrack(track, requestedBitrate);
  }

  Future<void> downloadTrack(Track track, int bitrate) async {
    if (downloading) {
      return;
    }
    final selectedBitrate = normalizeBitrate(bitrate);
    downloading = true;
    downloadTotal = 1;
    downloadCompleted = 0;
    status = '正在准备下载：${track.name}（${labelForBitrate(selectedBitrate)}）';
    notifyListeners();

    try {
      final url = await _resolveDownloadUrl(track, selectedBitrate);
      final fileName = _downloadFileName(track, url);
      status = '正在下载：$fileName';
      notifyListeners();
      final saved = await _saveDownload(url: url, fileName: fileName);
      if (saved == null) {
        status = '已取消下载';
        return;
      }
      downloadCompleted = 1;
      status = '已保存：${saved.displayPath}';
    } catch (error) {
      status = '下载失败：${describeError(error)}';
    } finally {
      downloading = false;
      notifyListeners();
    }
  }

  Future<void> downloadTracks(List<Track> tracks, int bitrate) async {
    if (tracks.isEmpty) {
      status = '请选择要下载的歌曲';
      notifyListeners();
      return;
    }
    if (downloading) {
      return;
    }

    final directory = await pickBatchDownloadDirectory();
    if (directory == null) {
      status = '已取消批量下载';
      notifyListeners();
      return;
    }

    final selectedBitrate = normalizeBitrate(bitrate);
    final usedNames = <String>{};
    final failures = <String>[];
    downloading = true;
    downloadTotal = tracks.length;
    downloadCompleted = 0;
    status = '准备批量下载 ${tracks.length} 首歌曲';
    notifyListeners();

    try {
      for (final track in tracks) {
        final index = downloadCompleted + 1;
        status = '正在下载 $index/${tracks.length}：${track.name}';
        notifyListeners();

        try {
          final url = await _resolveDownloadUrl(track, selectedBitrate);
          final fileName = _uniqueFileName(
            _downloadFileName(track, url),
            usedNames,
          );
          final saved = await _saveDownload(
            url: url,
            fileName: fileName,
            targetPath: path.join(directory, fileName),
          );
          if (saved == null) {
            failures.add('${track.name}：已取消保存');
          }
        } catch (error) {
          failures.add('${track.name}：${describeError(error)}');
        } finally {
          downloadCompleted += 1;
          notifyListeners();
        }
      }

      final success = tracks.length - failures.length;
      status = failures.isEmpty
          ? '批量下载完成：成功 $success 首'
          : '批量下载完成：成功 $success 首，失败 ${failures.length} 首（${failures.first}）';
    } finally {
      downloading = false;
      notifyListeners();
    }
  }

  Future<String?> _loadAlbumUrl(Track track, int request) async {
    try {
      final url = await _api.fetchAlbumUrl(track);
      if (_isCurrentRequest(track, request)) {
        albumUrl = url;
        albumBytes = null;
        notifyListeners();
      }
      if (url != null && url.isNotEmpty) {
        unawaited(_loadAlbumBytes(track, request, url));
      }
      return url;
    } catch (_) {
      if (_isCurrentRequest(track, request)) {
        albumBytes = null;
        notifyListeners();
      }
      return null;
    }
  }

  Future<void> _loadAlbumBytes(Track track, int request, String url) async {
    try {
      final bytes = await _api.fetchAlbumBytes(url);
      if (_isCurrentRequest(track, request)) {
        albumBytes = bytes;
        notifyListeners();
      }
    } catch (_) {
      if (_isCurrentRequest(track, request)) {
        albumBytes = null;
        notifyListeners();
      }
    }
  }

  Future<void> _loadLyrics(Track track, int request) async {
    try {
      final lines = await _api.fetchLyrics(track);
      if (_isCurrentRequest(track, request)) {
        lyrics = lines;
        notifyListeners();
      }
    } catch (error) {
      if (_isCurrentRequest(track, request)) {
        lyrics = const <LyricLine>[];
        status = '歌词加载失败：${describeError(error)}';
        notifyListeners();
      }
    }
  }

  MediaItem _mediaItemForTrack(Track track, SongUrl songUrl, String? artUrl) {
    return MediaItem(
      id: songUrl.url,
      title: track.name,
      artist: track.artistText,
      album: track.album,
      artUri: artUrl == null || artUrl.isEmpty ? null : Uri.parse(artUrl),
      extras: <String, dynamic>{
        _trackIdKey: track.id,
        _artistsKey: track.artists,
        _albumKey: track.album,
        _picIdKey: track.picId,
        _lyricIdKey: track.lyricId,
        _sourceKey: track.source,
        _requestedBitrateKey: requestedBitrate,
        _actualBitrateKey: songUrl.bitrate,
      },
    );
  }

  Future<String> _resolveDownloadUrl(Track track, int bitrate) async {
    if (identical(track, currentTrack) &&
        currentSongUrl != null &&
        requestedBitrate == bitrate) {
      return currentSongUrl!;
    }
    final songUrl = await _api.fetchSongUrl(track, bitrate);
    if (songUrl.url.trim().isEmpty) {
      throw const MusicApiException('接口没有返回下载链接');
    }
    return songUrl.url;
  }

  Future<SavedDownload?> _saveDownload({
    required String url,
    required String fileName,
    String? targetPath,
  }) async {
    final response = await _downloadClient
        .get(
          Uri.parse(url),
          headers: const {'User-Agent': 'Mozilla/5.0 Flutter GD Music'},
        )
        .timeout(const Duration(seconds: 45));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MusicApiException('HTTP ${response.statusCode}');
    }
    return saveDownloadBytes(
      bytes: response.bodyBytes,
      fileName: fileName,
      mimeType: response.headers['content-type'] ?? 'audio/mpeg',
      targetPath: targetPath,
    );
  }

  void _handleMediaItem(MediaItem? item) {
    if (item == null) {
      currentTrack = null;
      albumUrl = null;
      albumBytes = null;
      lyrics = const <LyricLine>[];
      currentSongUrl = null;
      duration = Duration.zero;
      position = Duration.zero;
      playable = false;
      preparing = false;
      playing = false;
      _updatePositionTimer();
      notifyListeners();
      return;
    }

    duration = item.duration ?? duration;
    currentSongUrl = item.id;
    albumUrl = item.artUri?.toString();
    actualBitrate = _readIntExtra(item, _actualBitrateKey, actualBitrate);
    requestedBitrate = _readIntExtra(
      item,
      _requestedBitrateKey,
      requestedBitrate,
    );

    final restoredTrack = _trackFromMediaItem(item);
    if (currentTrack == null ||
        (restoredTrack != null && restoredTrack.id != currentTrack!.id)) {
      currentTrack = restoredTrack;
      albumBytes = null;
      lyrics = const <LyricLine>[];
      final request = ++_playRequest;
      if (restoredTrack != null) {
        unawaited(_loadLyrics(restoredTrack, request));
        if (albumUrl != null) {
          unawaited(_loadAlbumBytes(restoredTrack, request, albumUrl!));
        }
      }
    }
    notifyListeners();
  }

  void _handlePlaybackState(PlaybackState state) {
    _lastPlaybackState = state;
    position = state.position;
    playing = state.playing;
    preparing =
        state.processingState == AudioProcessingState.loading ||
        state.processingState == AudioProcessingState.buffering;
    playable =
        currentSongUrl != null &&
        state.processingState != AudioProcessingState.error;

    if (state.processingState == AudioProcessingState.completed) {
      playing = false;
      preparing = false;
      position = duration;
      status = currentTrack == null ? '播放完成' : '播放完成：${currentTrack!.name}';
    } else if (state.processingState == AudioProcessingState.error) {
      playing = false;
      preparing = false;
      playable = false;
      status = '播放器错误：${state.errorMessage ?? '未知错误'}';
    }

    _updatePositionTimer();
    notifyListeners();
  }

  void _updatePositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = null;
    if (!playing) {
      return;
    }
    _positionTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final nextPosition = _lastPlaybackState.position;
      if (nextPosition != position) {
        position = nextPosition;
        notifyListeners();
      }
    });
  }

  Track? _trackFromMediaItem(MediaItem item) {
    final extras = item.extras;
    if (extras == null) {
      return null;
    }
    final id = extras[_trackIdKey]?.toString() ?? '';
    if (id.isEmpty) {
      return null;
    }
    return Track(
      id: id,
      name: item.title,
      artists: _readArtists(extras[_artistsKey], item.artist),
      album: extras[_albumKey]?.toString() ?? item.album ?? '未知专辑',
      picId: extras[_picIdKey]?.toString() ?? '',
      lyricId: extras[_lyricIdKey]?.toString() ?? id,
      source: extras[_sourceKey]?.toString() ?? '',
    );
  }

  List<String> _readArtists(Object? value, String? fallback) {
    if (value is Iterable) {
      final artists = value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
      if (artists.isNotEmpty) {
        return artists;
      }
    }
    final text = fallback?.trim() ?? '';
    return text.isEmpty ? const <String>['未知歌手'] : text.split(' / ');
  }

  int _readIntExtra(MediaItem item, String key, int fallback) {
    final value = item.extras?[key];
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  bool _isCurrentRequest(Track track, int request) {
    return _playRequest == request && currentTrack?.id == track.id;
  }

  String _downloadFileName(Track track, String url) {
    return '${_safeFileName('${track.artistText} - ${track.name}')}${_extensionFromUrl(url)}';
  }

  String _safeFileName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return cleaned.isEmpty ? 'music_gdstudio_song' : cleaned;
  }

  String _extensionFromUrl(String url) {
    final pathText = Uri.tryParse(url)?.path ?? '';
    final dot = pathText.lastIndexOf('.');
    if (dot >= 0 && dot < pathText.length - 1) {
      final extension = pathText.substring(dot);
      if (extension.length <= 6) {
        return extension;
      }
    }
    return '.mp3';
  }

  String _uniqueFileName(String fileName, Set<String> usedNames) {
    if (usedNames.add(fileName)) {
      return fileName;
    }
    final extension = path.extension(fileName);
    final baseName = path.basenameWithoutExtension(fileName);
    var index = 2;
    while (true) {
      final next = '$baseName ($index)$extension';
      if (usedNames.add(next)) {
        return next;
      }
      index += 1;
    }
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _downloadClient.close();
    super.dispose();
  }
}

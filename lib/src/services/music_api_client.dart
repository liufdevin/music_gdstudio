import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/music_models.dart';

class MusicApiException implements Exception {
  const MusicApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MusicApiClient {
  MusicApiClient({http.Client? client}) : _client = client ?? http.Client();

  static const _api = 'https://music-api.gdstudio.xyz/api.php';
  static const _jsonHeaders = <String, String>{
    'Accept': 'application/json,text/plain,*/*',
    'User-Agent': 'Mozilla/5.0 Flutter GD Music',
  };
  static const _imageHeaders = <String, String>{
    'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*',
    'User-Agent': 'Mozilla/5.0 Flutter GD Music',
  };
  static final _lrcTime = RegExp(r'\[(\d{1,2}):(\d{1,2})(?:\.(\d{1,3}))?]');

  final http.Client _client;

  Future<List<Track>> search({
    required String source,
    required String keyword,
    required int count,
    required int page,
  }) async {
    final uri = _buildUri({
      'types': 'search',
      'source': source,
      'name': keyword,
      'count': count.toString(),
      'pages': page.toString(),
    });

    try {
      final value = await _getJson(uri);
      return _parseSearchResult(value, source);
    } on MusicApiException catch (error) {
      throw MusicApiException(_buildSearchError(source, error.message));
    } catch (error) {
      throw MusicApiException(_buildSearchError(source, describeError(error)));
    }
  }

  Future<SongUrl> fetchSongUrl(Track track, int bitrate) async {
    final uri = _buildUri({
      'types': 'url',
      'source': track.source,
      'id': track.id,
      'br': normalizeBitrate(bitrate).toString(),
    });
    final object = _objectFromResponse(await _getJson(uri));
    return SongUrl.fromJson(object);
  }

  Future<String?> fetchAlbumUrl(Track track) async {
    if (track.picId.isEmpty) {
      return null;
    }
    final uri = _buildUri({
      'types': 'pic',
      'source': track.source,
      'id': track.picId,
      'size': '500',
    });
    final object = _objectFromResponse(await _getJson(uri));
    final url = object['url']?.toString().trim() ?? '';
    return url.isEmpty ? null : url;
  }

  Future<Uint8List?> fetchAlbumBytes(String url) async {
    if (url.trim().isEmpty) {
      return null;
    }
    final response = await _client
        .get(Uri.parse(url), headers: _imageHeaders)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MusicApiException(
        '封面下载失败 HTTP ${response.statusCode}: ${_trimForStatus(utf8.decode(response.bodyBytes, allowMalformed: true))}',
      );
    }
    return response.bodyBytes.isEmpty ? null : response.bodyBytes;
  }

  Future<List<LyricLine>> fetchLyrics(Track track) async {
    if (track.lyricId.isEmpty) {
      return const <LyricLine>[];
    }
    final uri = _buildUri({
      'types': 'lyric',
      'source': track.source,
      'id': track.lyricId,
    });
    final object = _objectFromResponse(await _getJson(uri));
    return _parseLyrics(
      object['lyric']?.toString() ?? '',
      object['tlyric']?.toString() ?? '',
    );
  }

  void close() {
    _client.close();
  }

  Uri _buildUri(Map<String, String> queryParameters) {
    return Uri.parse(_api).replace(queryParameters: queryParameters);
  }

  Future<dynamic> _getJson(Uri uri) async {
    final response = await _client
        .get(uri, headers: _jsonHeaders)
        .timeout(const Duration(seconds: 20));
    final body = utf8.decode(response.bodyBytes).trim();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MusicApiException(
        'HTTP ${response.statusCode}: ${_trimForStatus(body)}',
      );
    }
    if (body.isEmpty) {
      throw const MusicApiException('接口返回为空');
    }

    try {
      return jsonDecode(body);
    } on FormatException catch (error) {
      throw MusicApiException('接口返回不是有效 JSON：${error.message}');
    }
  }

  List<Track> _parseSearchResult(dynamic value, String fallbackSource) {
    final List<dynamic> rows;
    if (value is List) {
      rows = value;
    } else if (value is Map<String, dynamic>) {
      final data = value['data'];
      final result = value['result'];
      if (data is List) {
        rows = data;
      } else if (result is List) {
        rows = result;
      } else {
        rows = <dynamic>[value];
      }
    } else {
      rows = const <dynamic>[];
    }

    final tracks = <Track>[];
    for (final row in rows) {
      if (row is! Map) {
        continue;
      }
      final track = Track.fromJson(
        Map<String, dynamic>.from(row),
        fallbackSource,
      );
      if (track.id.isNotEmpty) {
        tracks.add(track);
      }
    }
    return tracks;
  }

  Map<String, dynamic> _objectFromResponse(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    throw const MusicApiException('接口返回格式异常');
  }

  List<LyricLine> _parseLyrics(String lyric, String translated) {
    final originals = _parseLrcMap(lyric);
    final translations = _parseLrcMap(translated);
    final lines = <LyricLine>[];

    for (final entry in originals.entries) {
      var text = entry.value;
      final translation = translations[entry.key];
      if (translation != null &&
          translation.trim().isNotEmpty &&
          translation.trim() != text.trim()) {
        text = '$text\n${translation.trim()}';
      }
      if (text.trim().isNotEmpty) {
        lines.add(LyricLine(time: entry.key, text: text.trim()));
      }
    }
    lines.sort((left, right) => left.time.compareTo(right.time));
    return lines;
  }

  Map<Duration, String> _parseLrcMap(String lrc) {
    final result = <Duration, String>{};
    if (lrc.trim().isEmpty) {
      return result;
    }
    for (final row in lrc.split(RegExp(r'\r?\n'))) {
      final matches = _lrcTime.allMatches(row).toList();
      if (matches.isEmpty) {
        continue;
      }
      final text = row.substring(matches.last.end).trim();
      for (final match in matches) {
        result[_parseTime(match)] = text;
      }
    }
    return result;
  }

  Duration _parseTime(RegExpMatch match) {
    final minutes = int.parse(match.group(1)!);
    final seconds = int.parse(match.group(2)!);
    final fraction = match.group(3) ?? '';
    var milliseconds = (minutes * 60 + seconds) * 1000;
    if (fraction.length == 1) {
      milliseconds += int.parse(fraction) * 100;
    } else if (fraction.length == 2) {
      milliseconds += int.parse(fraction) * 10;
    } else if (fraction.length >= 3) {
      milliseconds += int.parse(fraction.substring(0, 3));
    }
    return Duration(milliseconds: milliseconds);
  }

  String _buildSearchError(String source, String cause) {
    final sourceName = labelForSource(source);
    if (!stableSearchSources.contains(source)) {
      return '搜索接口请求失败（$sourceName）：该音乐源当前可能未开放，请切换到网易云或酷我。原始错误：$cause';
    }
    return '搜索接口请求失败（$sourceName）：请检查网络后重试。原始错误：$cause';
  }

  String _trimForStatus(String text) {
    final singleLine = text.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
    if (singleLine.length <= 120) {
      return singleLine;
    }
    return '${singleLine.substring(0, 120)}...';
  }
}

String describeError(Object error) {
  if (error is MusicApiException) {
    return error.message;
  }
  final text = error.toString();
  const exceptionPrefix = 'Exception: ';
  return text.startsWith(exceptionPrefix)
      ? text.substring(exceptionPrefix.length)
      : text;
}

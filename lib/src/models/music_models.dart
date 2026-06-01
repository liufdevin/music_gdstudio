class MusicSource {
  const MusicSource({required this.value, required this.label});

  final String value;
  final String label;
}

class BitrateOption {
  const BitrateOption({required this.value, required this.label});

  final int value;
  final String label;
}

const musicSources = <MusicSource>[
  MusicSource(value: 'netease', label: '网易云'),
  MusicSource(value: 'tencent', label: 'QQ'),
  MusicSource(value: 'kuwo', label: '酷我'),
  MusicSource(value: 'tidal', label: 'Tidal'),
  MusicSource(value: 'qobuz', label: 'Qobuz'),
  MusicSource(value: 'joox', label: 'JOOX'),
  MusicSource(value: 'bilibili', label: 'B站'),
  MusicSource(value: 'apple', label: 'Apple'),
  MusicSource(value: 'ytmusic', label: 'YouTube Music'),
  MusicSource(value: 'spotify', label: 'Spotify'),
];

const stableSearchSources = <String>{'netease', 'kuwo'};

const bitrateOptions = <BitrateOption>[
  BitrateOption(value: 999, label: '24bit无损'),
  BitrateOption(value: 740, label: '16bit无损'),
  BitrateOption(value: 320, label: '320K'),
  BitrateOption(value: 192, label: '192K'),
  BitrateOption(value: 128, label: '128K'),
];

class Track {
  const Track({
    required this.id,
    required this.name,
    required this.artists,
    required this.album,
    required this.picId,
    required this.lyricId,
    required this.source,
  });

  factory Track.fromJson(Map<String, dynamic> json, String fallbackSource) {
    final id = _readText(json['id']);
    return Track(
      id: id,
      name: _readText(json['name'], fallback: '未知歌曲'),
      artists: _parseArtists(json['artist']),
      album: _readText(json['album'], fallback: '未知专辑'),
      picId: _readText(json['pic_id']),
      lyricId: _readText(json['lyric_id'], fallback: id),
      source: _readText(json['source'], fallback: fallbackSource),
    );
  }

  final String id;
  final String name;
  final List<String> artists;
  final String album;
  final String picId;
  final String lyricId;
  final String source;

  String get artistText => artists.isEmpty ? '未知歌手' : artists.join(' / ');

  String get sourceLabel => labelForSource(source);
}

class SongUrl {
  const SongUrl({required this.url, required this.bitrate, required this.size});

  factory SongUrl.fromJson(Map<String, dynamic> json) {
    return SongUrl(
      url: _readText(json['url']),
      bitrate: _readInt(json['br']),
      size: _readInt(json['size']),
    );
  }

  final String url;
  final int bitrate;
  final int size;
}

class LyricLine {
  const LyricLine({required this.time, required this.text});

  final Duration time;
  final String text;
}

String labelForSource(String source) {
  for (final item in musicSources) {
    if (item.value == source) {
      return item.label;
    }
  }
  return source.isEmpty ? '未知音乐源' : source;
}

String labelForBitrate(int bitrate) {
  for (final item in bitrateOptions) {
    if (item.value == bitrate) {
      return item.label;
    }
  }
  return '${bitrate}K';
}

int normalizeBitrate(int bitrate) {
  for (final item in bitrateOptions) {
    if (item.value == bitrate) {
      return bitrate;
    }
  }
  return bitrateOptions.first.value;
}

String _readText(Object? value, {String fallback = ''}) {
  if (value == null) {
    return fallback;
  }
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

int _readInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

List<String> _parseArtists(Object? value) {
  final artists = <String>[];
  if (value is Iterable) {
    for (final item in value) {
      if (item is Map) {
        final name = _readText(item['name']);
        if (name.isNotEmpty) {
          artists.add(name);
        }
      } else {
        final name = _readText(item);
        if (name.isNotEmpty) {
          artists.add(name);
        }
      }
    }
  } else if (value is Map) {
    final name = _readText(value['name']);
    if (name.isNotEmpty) {
      artists.add(name);
    }
  } else {
    final name = _readText(value);
    if (name.isNotEmpty) {
      artists.add(name);
    }
  }

  return artists.isEmpty ? const <String>['未知歌手'] : artists;
}

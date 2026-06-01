import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/music_player_controller.dart';
import '../models/music_models.dart';
import '../services/music_api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/mini_player.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.api, required this.player});

  final MusicApiClient api;
  final MusicPlayerController player;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _keywordController = TextEditingController();
  final _pageController = TextEditingController(text: '1');
  final _countController = TextEditingController(text: '20');

  MusicSource _selectedSource = musicSources.first;
  BitrateOption _selectedBitrate = bitrateOptions.first;
  List<Track> _tracks = const <Track>[];
  String _status = '搜索歌曲、播放音乐';
  bool _loading = false;
  int _currentPage = 1;
  bool _hasSearched = false;
  bool _lastSearchHadResults = false;
  final Set<String> _selectedTrackIds = <String>{};

  @override
  void initState() {
    super.initState();
    widget.player.addListener(_syncPlayerStatus);
  }

  @override
  void dispose() {
    widget.player.removeListener(_syncPlayerStatus);
    _keywordController.dispose();
    _pageController.dispose();
    _countController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: widget.player,
        builder: (context, _) {
          return Stack(
            children: [
              Positioned.fill(
                child: SafeArea(
                  bottom: false,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      18,
                      16,
                      18,
                      widget.player.currentTrack == null ? 24 : 112,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1040),
                        child: _ResponsiveHomeLayout(
                          searchPanel: _buildSearchPanel(context),
                          results: _buildResults(context),
                          header: _buildHeader(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: MiniPlayer(player: widget.player),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'LF Music',
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _status,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.muted, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildSearchPanel(BuildContext context) {
    final canPage = !_loading && _hasSearched;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _keywordController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _searchSongs(),
              decoration: const InputDecoration(
                hintText: '输入歌曲名、歌手或专辑',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<MusicSource>(
              initialValue: _selectedSource,
              items: musicSources
                  .map(
                    (source) => DropdownMenuItem<MusicSource>(
                      value: source,
                      child: Text(source.label),
                    ),
                  )
                  .toList(),
              onChanged: _loading
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _selectedSource = value);
                      }
                    },
              decoration: const InputDecoration(
                labelText: '音乐源',
                prefixIcon: Icon(Icons.library_music_outlined),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<BitrateOption>(
              initialValue: _selectedBitrate,
              items: bitrateOptions
                  .map(
                    (bitrate) => DropdownMenuItem<BitrateOption>(
                      value: bitrate,
                      child: Text(bitrate.label),
                    ),
                  )
                  .toList(),
              onChanged: _loading
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _selectedBitrate = value);
                      }
                    },
              decoration: const InputDecoration(
                labelText: '音质',
                prefixIcon: Icon(Icons.graphic_eq),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pageController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(labelText: '页'),
                    onSubmitted: (_) => _searchSongs(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _countController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(labelText: '数量'),
                    onSubmitted: (_) => _searchSongs(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _loading ? null : _searchSongs,
              icon: Icon(_loading ? Icons.hourglass_top : Icons.search),
              label: Text(_loading ? '搜索中' : '搜索'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: canPage && _currentPage > 1
                        ? () => _searchAdjacentPage(-1)
                        : null,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('上一页'),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 78,
                  height: 44,
                  child: Center(
                    child: Text(
                      '第 $_currentPage 页',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: canPage && _lastSearchHadResults
                        ? () => _searchAdjacentPage(1)
                        : null,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('下一页'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    if (_loading) {
      return const _MessagePanel(icon: Icons.hourglass_top, message: '正在搜索');
    }
    if (!_hasSearched) {
      return const _MessagePanel(
        icon: Icons.album_outlined,
        message: '输入关键字后开始搜索',
      );
    }
    if (_tracks.isEmpty) {
      return const _MessagePanel(icon: Icons.search_off, message: '没有搜索结果');
    }

    return Column(
      children: [
        _BatchDownloadBar(
          selectedCount: _selectedTrackIds.length,
          totalCount: _tracks.length,
          downloading: widget.player.downloading,
          onSelectAll: _selectAllResults,
          onClear: _clearSelection,
          onDownload: _selectedTrackIds.isEmpty
              ? null
              : _downloadSelectedTracks,
        ),
        const SizedBox(height: 10),
        for (final track in _tracks)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _TrackTile(
              track: track,
              playing: identical(widget.player.currentTrack, track),
              selected: _selectedTrackIds.contains(_trackKey(track)),
              onSelectedChanged: (selected) =>
                  _setTrackSelection(track, selected),
              onPlay: () => _playTrack(track),
              onDownload: () => _downloadTrack(track),
            ),
          ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '数据来源：GD音乐台(music.gdstudio.xyz)',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Future<void> _searchSongs() async {
    final keyword = _keywordController.text.trim();
    if (keyword.isEmpty) {
      _showSnack('请输入搜索关键字');
      return;
    }

    final page = _readPositiveInt(_pageController, 1);
    final count = _readPositiveInt(_countController, 20);
    setState(() {
      _loading = true;
      _currentPage = page;
      _pageController.text = page.toString();
      _status = '正在搜索：$keyword（第 $page 页）';
      _tracks = const <Track>[];
      _selectedTrackIds.clear();
    });

    try {
      final tracks = await widget.api.search(
        source: _selectedSource.value,
        keyword: keyword,
        count: count,
        page: page,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _hasSearched = true;
        _lastSearchHadResults = tracks.isNotEmpty;
        _tracks = tracks;
        _status = '第 $page 页，找到 ${tracks.length} 首歌曲';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _hasSearched = true;
        _lastSearchHadResults = false;
        _tracks = const <Track>[];
        _status = '搜索失败：${describeError(error)}';
      });
    }
  }

  Future<void> _searchAdjacentPage(int offset) async {
    final nextPage = (_readPositiveInt(_pageController, _currentPage) + offset)
        .clamp(1, 999);
    _pageController.text = nextPage.toString();
    await _searchSongs();
  }

  Future<void> _playTrack(Track track) async {
    await widget.player.playTrack(track, _selectedBitrate.value);
  }

  Future<void> _downloadTrack(Track track) async {
    await widget.player.downloadTrack(track, _selectedBitrate.value);
    if (mounted && widget.player.status.isNotEmpty) {
      _showSnack(widget.player.status);
    }
  }

  Future<void> _downloadSelectedTracks() async {
    final selectedTracks = _tracks
        .where((track) => _selectedTrackIds.contains(_trackKey(track)))
        .toList();
    await widget.player.downloadTracks(selectedTracks, _selectedBitrate.value);
    if (mounted && widget.player.status.isNotEmpty) {
      _showSnack(widget.player.status);
    }
  }

  void _setTrackSelection(Track track, bool selected) {
    setState(() {
      final key = _trackKey(track);
      if (selected) {
        _selectedTrackIds.add(key);
      } else {
        _selectedTrackIds.remove(key);
      }
    });
  }

  void _selectAllResults() {
    setState(() {
      _selectedTrackIds
        ..clear()
        ..addAll(_tracks.map(_trackKey));
    });
  }

  void _clearSelection() {
    setState(_selectedTrackIds.clear);
  }

  String _trackKey(Track track) => '${track.source}:${track.id}';

  int _readPositiveInt(TextEditingController controller, int fallback) {
    final value = int.tryParse(controller.text.trim());
    return value == null || value <= 0 ? fallback : value;
  }

  void _syncPlayerStatus() {
    final status = widget.player.status;
    if (mounted && status.isNotEmpty && status != _status) {
      setState(() => _status = status);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

class _ResponsiveHomeLayout extends StatelessWidget {
  const _ResponsiveHomeLayout({
    required this.header,
    required this.searchPanel,
    required this.results,
  });

  final Widget header;
  final Widget searchPanel;
  final Widget results;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              const SizedBox(height: 16),
              searchPanel,
              const SizedBox(height: 14),
              results,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 360, child: searchPanel),
                const SizedBox(width: 16),
                Expanded(child: results),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _TrackTile extends StatelessWidget {
  const _TrackTile({
    required this.track,
    required this.playing,
    required this.selected,
    required this.onSelectedChanged,
    required this.onPlay,
    required this.onDownload,
  });

  final Track track;
  final bool playing;
  final bool selected;
  final ValueChanged<bool> onSelectedChanged;
  final VoidCallback onPlay;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: playing ? const Color(0xFFE9F7F3) : AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPlay,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: playing ? AppColors.accent : AppColors.line,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 34,
                    height: 34,
                    child: Checkbox(
                      value: selected,
                      onChanged: (value) => onSelectedChanged(value ?? false),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    playing ? Icons.equalizer : Icons.music_note,
                    color: playing ? AppColors.accent : AppColors.muted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${track.artistText}  ·  ${track.album}  ·  ${track.sourceLabel}',
                          maxLines: 2,
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
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onPlay,
                      icon: const Icon(Icons.play_arrow),
                      label: Text(playing ? '重播' : '播放'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onDownload,
                      icon: const Icon(Icons.download),
                      label: const Text('下载'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BatchDownloadBar extends StatelessWidget {
  const _BatchDownloadBar({
    required this.selectedCount,
    required this.totalCount,
    required this.downloading,
    required this.onSelectAll,
    required this.onClear,
    required this.onDownload,
  });

  final int selectedCount;
  final int totalCount;
  final bool downloading;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            selectedCount == 0
                ? '可多选下载，共 $totalCount 首'
                : '已选择 $selectedCount/$totalCount 首',
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          OutlinedButton.icon(
            onPressed: downloading ? null : onSelectAll,
            icon: const Icon(Icons.select_all),
            label: const Text('全选'),
          ),
          OutlinedButton.icon(
            onPressed: downloading || selectedCount == 0 ? null : onClear,
            icon: const Icon(Icons.clear),
            label: const Text('清空'),
          ),
          FilledButton.icon(
            onPressed: downloading ? null : onDownload,
            icon: Icon(downloading ? Icons.hourglass_top : Icons.download),
            label: Text(downloading ? '下载中' : '下载所选'),
          ),
        ],
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.accent, size: 34),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

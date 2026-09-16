import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MusicPlayerApp());
}

class MusicPlayerApp extends StatelessWidget {
  const MusicPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Play Musik',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
      ),
      home: const MusicHomePage(),
    );
  }
}

class MusicHomePage extends StatefulWidget {
  const MusicHomePage({super.key});

  @override
  State<MusicHomePage> createState() => _MusicHomePageState();
}

class _MusicHomePageState extends State<MusicHomePage> with SingleTickerProviderStateMixin {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  List<SongModel> _songs = [];
  List<String> _favorites = [];
  bool _hasPermission = false;
  int? _currentIndex;
  bool _isPlaying = false;
  String _sortBy = 'title';

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    checkAndRequestPermissions();
    _loadFavorites();

    _audioPlayer.playerStateStream.listen((state) {
      setState(() {
        _isPlaying = state.playing;
      });
    });
  }

  Future<void> checkAndRequestPermissions() async {
    PermissionStatus status;
    if (await Permission.storage.isGranted || await Permission.audio.isGranted) {
      _hasPermission = true;
    } else {
      status = await Permission.audio.request();
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }
      _hasPermission = status.isGranted;
    }

    if (_hasPermission) {
      loadSongs();
    }
    setState(() {});
  }

  Future<void> loadSongs() async {
    SongSortType sortType = SongSortType.TITLE;
    if (_sortBy == 'artist') sortType = SongSortType.ARTIST;
    if (_sortBy == 'duration') sortType = SongSortType.DURATION;

    List<SongModel> songs = await _audioQuery.querySongs(
      sortType: sortType,
      orderType: null,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    setState(() {
      _songs = songs;
    });
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favorites = prefs.getStringList('favorites') ?? [];
    });
  }

  Future<void> _toggleFavorite(String songId) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_favorites.contains(songId)) {
        _favorites.remove(songId);
      } else {
        _favorites.add(songId);
      }
    });
    await prefs.setStringList('favorites', _favorites);
  }

  void _playSong(String? uri, int index) async {
    if (uri == null) return;
    try {
      await _audioPlayer.setUrl(uri);
      await _audioPlayer.play();
      setState(() {
        _currentIndex = index;
      });
    } catch (e) {
      debugPrint("Error playing song: $e");
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Play Musik (Bebas Iklan)'),
        backgroundColor: const Color(0xFF1F1F1F),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _sortBy = value;
              });
              loadSongs();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'title', child: Text('Urutkan: Judul')),
              const PopupMenuItem(value: 'artist', child: Text('Urutkan: Artis')),
              const PopupMenuItem(value: 'duration', child: Text('Urutkan: Durasi')),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Semua Lagu', icon: Icon(Icons.music_note)),
            Tab(text: 'Favorit', icon: Icon(Icons.favorite)),
          ],
        ),
      ),
      body: !_hasPermission
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Izin akses penyimpanan diperlukan untuk memutar musik lokal.'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: checkAndRequestPermissions,
                      child: const Text('Beri Izin'),
                    ),
                  ],
                ),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSongList(_songs),
                _buildSongList(_songs.where((s) => _favorites.contains(s.id.toString())).toList()),
              ],
            ),
      bottomNavigationBar: _currentIndex != null && _songs.isNotEmpty
          ? Container(
              color: const Color(0xFF1F1F1F),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.music_note, size: 40, color: Colors.deepPurpleAccent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _songs[_currentIndex!].title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _songs[_currentIndex!].artist ?? "<unknown>",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                    onPressed: () {
                      if (_isPlaying) {
                        _audioPlayer.pause();
                      } else {
                        _audioPlayer.play();
                      }
                    },
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildSongList(List<SongModel> songs) {
    if (songs.isEmpty) {
      return const Center(child: Text('Tidak ada lagu ditemukan.'));
    }
    return ListView.builder(
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final song = songs[index];
        final isFav = _favorites.contains(song.id.toString());
        return ListTile(
          leading: QueryArtworkWidget(
            controller: _audioQuery,
            id: song.id,
            type: ArtworkType.AUDIO,
            nullArtworkWidget: const Icon(Icons.audiotrack, size: 40, color: Colors.grey),
          ),
          title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(song.artist ?? "<unknown>", maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: IconButton(
            icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.red : Colors.grey),
            onPressed: () => _toggleFavorite(song.id.toString()),
          ),
          onTap: () => _playSong(song.uri, index),
        );
      },
    );
  }
}

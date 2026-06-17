// lib/screens/search/search_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart'; // 🌟 THE FIX
import '../profile/profile_screen.dart';
import 'explore_feed_screen.dart';

// 🌟 గ్లోబల్ క్యాష్ మెమరీ సెటప్
class TrendingCache {
  static List<Map<String, dynamic>> cachedTrendingContent = [];
  static DateTime? lastFetchTime;
  static DocumentSnapshot? lastPostDoc;
  static DocumentSnapshot? lastReelDoc;
  static bool hasMoreData = true;
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _searchQuery = "";
  bool _isSearching = false;
  List<Map<String, dynamic>> _trendingContent = [];
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  final int _initialLimit = 200;
  final int _moreLimit = 20;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _checkAndFetchData();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoadingMore &&
          TrendingCache.hasMoreData) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _fetchMoreData();
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _checkAndFetchData({bool forceRefresh = false}) {
    if (!forceRefresh &&
        TrendingCache.cachedTrendingContent.isNotEmpty &&
        TrendingCache.lastFetchTime != null) {
      if (DateTime.now().difference(TrendingCache.lastFetchTime!).inHours < 1) {
        if (mounted) {
          setState(() {
            _trendingContent = List.from(TrendingCache.cachedTrendingContent);
            _isInitialLoading = false;
          });
        }
        return;
      }
    }
    _fetchInitialData();
  }

  int _getViewsCount(Map<String, dynamic> data) {
    int count = 0;
    if (data['seenBy'] is List)
      count = (data['seenBy'] as List).length;
    else if (data['viewedBy'] is List)
      count = (data['viewedBy'] as List).length;
    else if (data['viewers'] is List)
      count = (data['viewers'] as List).length;
    if (count == 0) {
      if (data['views'] != null)
        count = int.tryParse(data['views'].toString()) ?? 0;
      else if (data['viewCount'] != null)
        count = int.tryParse(data['viewCount'].toString()) ?? 0;
    }
    return count;
  }

  void _sortContent(List<Map<String, dynamic>> content) {
    content.sort((a, b) {
      int aLikes = (a['likes'] as List?)?.length ?? 0;
      int aScore = aLikes + _getViewsCount(a);
      int bLikes = (b['likes'] as List?)?.length ?? 0;
      int bScore = bLikes + _getViewsCount(b);
      if (aScore == bScore) {
        var aTime = a['timestamp'] ?? a['datePublished'];
        var bTime = b['timestamp'] ?? b['datePublished'];
        if (aTime == null || bTime == null) return 0;
        DateTime dtA = (aTime is Timestamp)
            ? aTime.toDate()
            : (DateTime.tryParse(aTime.toString()) ??
                  DateTime.fromMillisecondsSinceEpoch(0));
        DateTime dtB = (bTime is Timestamp)
            ? bTime.toDate()
            : (DateTime.tryParse(bTime.toString()) ??
                  DateTime.fromMillisecondsSinceEpoch(0));
        return dtB.compareTo(dtA);
      }
      return bScore.compareTo(aScore);
    });
  }

  Future<void> _fetchInitialData() async {
    if (!mounted) return;
    setState(() => _isInitialLoading = true);
    TrendingCache.cachedTrendingContent.clear();
    TrendingCache.lastPostDoc = null;
    TrendingCache.lastReelDoc = null;
    TrendingCache.hasMoreData = true;

    try {
      var postsSnap = await FirebaseFirestore.instance
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .limit(_initialLimit)
          .get();
      var reelsSnap = await FirebaseFirestore.instance
          .collection('reels')
          .orderBy('timestamp', descending: true)
          .limit(_initialLimit)
          .get();

      if (postsSnap.docs.isNotEmpty)
        TrendingCache.lastPostDoc = postsSnap.docs.last;
      if (reelsSnap.docs.isNotEmpty)
        TrendingCache.lastReelDoc = reelsSnap.docs.last;

      List<Map<String, dynamic>> allContent = [];
      for (var doc in postsSnap.docs) {
        var data = Map<String, dynamic>.from(doc.data() as dynamic);
        data['id'] = doc.id;
        data['collectionType'] = 'post';
        if (!data.containsKey('postUrls') &&
            !data.containsKey('postUrl') &&
            !data.containsKey('postData'))
          continue;
        allContent.add(data);
      }
      for (var doc in reelsSnap.docs) {
        var data = Map<String, dynamic>.from(doc.data() as dynamic);
        data['id'] = doc.id;
        data['collectionType'] = 'reel';
        allContent.add(data);
      }
      _sortContent(allContent);
      TrendingCache.cachedTrendingContent = allContent;
      TrendingCache.lastFetchTime = DateTime.now();

      if (mounted)
        setState(() {
          _trendingContent = List.from(TrendingCache.cachedTrendingContent);
          _isInitialLoading = false;
        });
    } catch (e) {
      if (mounted) setState(() => _isInitialLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchMoreData() async {
    if (_isLoadingMore || !TrendingCache.hasMoreData || !mounted) return [];
    setState(() => _isLoadingMore = true);
    try {
      var postsQuery = FirebaseFirestore.instance
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .limit(_moreLimit);
      if (TrendingCache.lastPostDoc != null)
        postsQuery = postsQuery.startAfterDocument(TrendingCache.lastPostDoc!);

      var reelsQuery = FirebaseFirestore.instance
          .collection('reels')
          .orderBy('timestamp', descending: true)
          .limit(_moreLimit);
      if (TrendingCache.lastReelDoc != null)
        reelsQuery = reelsQuery.startAfterDocument(TrendingCache.lastReelDoc!);

      var postsSnap = await postsQuery.get();
      var reelsSnap = await reelsQuery.get();

      if (postsSnap.docs.isEmpty && reelsSnap.docs.isEmpty) {
        TrendingCache.hasMoreData = false;
        if (mounted) setState(() => _isLoadingMore = false);
        return [];
      }
      if (postsSnap.docs.isNotEmpty)
        TrendingCache.lastPostDoc = postsSnap.docs.last;
      if (reelsSnap.docs.isNotEmpty)
        TrendingCache.lastReelDoc = reelsSnap.docs.last;

      List<Map<String, dynamic>> newContent = [];
      for (var doc in postsSnap.docs) {
        var data = Map<String, dynamic>.from(doc.data() as dynamic);
        data['id'] = doc.id;
        data['collectionType'] = 'post';
        if (!data.containsKey('postUrls') &&
            !data.containsKey('postUrl') &&
            !data.containsKey('postData'))
          continue;
        newContent.add(data);
      }
      for (var doc in reelsSnap.docs) {
        var data = Map<String, dynamic>.from(doc.data() as dynamic);
        data['id'] = doc.id;
        data['collectionType'] = 'reel';
        newContent.add(data);
      }
      _sortContent(newContent);
      for (var item in newContent) {
        if (!TrendingCache.cachedTrendingContent.any(
          (existing) => existing['id'] == item['id'],
        )) {
          TrendingCache.cachedTrendingContent.add(item);
        }
      }
      if (mounted) {
        setState(() {
          _trendingContent = List.from(TrendingCache.cachedTrendingContent);
          _isLoadingMore = false;
        });
      }
      return newContent;
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        titleSpacing: 0,
        title: Container(
          height: 45,
          margin: const EdgeInsets.only(right: 15),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.grey[200],
            borderRadius: BorderRadius.circular(30),
          ),
          child: TextField(
            style: TextStyle(color: textColor),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
                _isSearching = value.isNotEmpty;
              });
            },
            decoration: InputDecoration(
              hintText: "Search users...",
              hintStyle: const TextStyle(color: Colors.grey),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.only(left: 20, top: 12),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 5),
                child: IconButton(
                  icon: const Icon(Icons.search, color: Colors.blueAccent),
                  onPressed: () {},
                ),
              ),
            ),
          ),
        ),
      ),
      body: _isSearching
          ? _buildUserSearchResults(isDark)
          : _buildTrendingGrid(isDark),
    );
  }

  Widget _buildUserSearchResults(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        var filteredUsers = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          String name = (data['username'] ?? "").toLowerCase();
          return name.contains(_searchQuery);
        }).toList();
        if (filteredUsers.isEmpty)
          return const Center(
            child: Text("No users found", style: TextStyle(color: Colors.grey)),
          );
        return ListView.builder(
          itemCount: filteredUsers.length,
          itemBuilder: (context, index) {
            var user = filteredUsers[index].data() as Map<String, dynamic>;
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: CachedNetworkImageProvider(
                  user['profilePic'] ??
                      'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png',
                ), // 🌟 THE FIX
              ),
              title: Text(
                user['username'] ?? "User",
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                user['gothra'] ?? "",
                style: const TextStyle(color: Colors.grey),
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ProfileScreen(userId: filteredUsers[index].id),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTrendingGrid(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: 15,
            top: 10,
            bottom: 10,
            right: 15,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.local_fire_department,
                    color: Colors.orangeAccent,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "#Top Trending",
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => _checkAndFetchData(forceRefresh: true),
                child: const Icon(
                  Icons.refresh_rounded,
                  color: Colors.blueAccent,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isInitialLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.blueAccent),
                )
              : _trendingContent.isEmpty
              ? const Center(
                  child: Text(
                    "No trending content yet.",
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async => _checkAndFetchData(forceRefresh: true),
                  color: Colors.blueAccent,
                  child: GridView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(6),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 6,
                          mainAxisSpacing: 6,
                          childAspectRatio: 1,
                        ),
                    itemCount: _trendingContent.length,
                    itemBuilder: (context, index) {
                      var data = _trendingContent[index];
                      bool isVideo =
                          data['isReel'] == true ||
                          data['type'] == 'video' ||
                          data['type'] == 'reel' ||
                          data.containsKey('videoUrl');
                      String type = data['type'] ?? (isVideo ? 'reel' : 'post');
                      String postUrl = '';
                      List mediaList =
                          data['postUrls'] ?? data['postData'] ?? [];
                      if (mediaList.isNotEmpty) {
                        postUrl = mediaList[0];
                      } else {
                        postUrl = data['postUrl'] ?? data['videoUrl'] ?? '';
                      }
                      String profilePic =
                          data['profilePic'] ??
                          'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png';
                      bool isAudio =
                          type == 'audio' ||
                          postUrl.contains('.m4a') ||
                          postUrl.contains('.mp3');

                      int totalScore =
                          ((data['likes'] as List?)?.length ?? 0) +
                          _getViewsCount(data);
                      String thumbUrl =
                          data['thumbnailUrl'] ?? data['coverUrl'] ?? '';

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ExploreFeedScreen(
                                allDocs: _trendingContent,
                                initialIndex: index,
                                onLoadMore: () async {
                                  return await _fetchMoreData();
                                },
                              ),
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Container(
                                color: isDark
                                    ? Colors.grey[900]
                                    : Colors.grey[300],
                                child: isVideo
                                    ? GridVideoItem(
                                        videoUrl: postUrl,
                                        thumbnailUrl: thumbUrl,
                                      )
                                    : isAudio
                                    ? GridAudioItem(
                                        audioUrl: postUrl,
                                        profilePic: profilePic,
                                      )
                                    : (postUrl.isNotEmpty)
                                    ? CachedNetworkImage(
                                        // 🌟 THE FIX: CachedNetworkImage
                                        imageUrl: postUrl,
                                        fit: BoxFit.cover,
                                        errorWidget: (context, url, error) =>
                                            const Icon(
                                              Icons.broken_image,
                                              color: Colors.grey,
                                            ),
                                        placeholder: (context, url) =>
                                            const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                      )
                                    : const Icon(
                                        Icons.image,
                                        color: Colors.grey,
                                      ),
                              ),
                              if (!isVideo &&
                                  !isAudio &&
                                  data['postUrls'] != null &&
                                  (data['postUrls'] as List).length > 1)
                                const Positioned(
                                  top: 5,
                                  right: 5,
                                  child: Icon(
                                    Icons.file_copy,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              Positioned(
                                bottom: 5,
                                left: 5,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.local_fire_department_rounded,
                                        color: Colors.orangeAccent,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        "$totalScore",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
        if (_isLoadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: CircularProgressIndicator(
                color: Colors.blueAccent,
                strokeWidth: 3,
              ),
            ),
          ),
      ],
    );
  }
}

class GridVideoItem extends StatefulWidget {
  final String videoUrl;
  final String thumbnailUrl;
  const GridVideoItem({
    super.key,
    required this.videoUrl,
    required this.thumbnailUrl,
  });
  @override
  State<GridVideoItem> createState() => _GridVideoItemState();
}

class _GridVideoItemState extends State<GridVideoItem> {
  VideoPlayerController? _controller;
  @override
  void initState() {
    super.initState();
    if (widget.videoUrl.isNotEmpty) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
        ..initialize()
            .then((_) {
              _controller!.setVolume(0.0);
              _controller!.setLooping(true);
              if (mounted) {
                setState(() {});
                _controller!.play();
              }
            })
            .catchError((e) {});
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.thumbnailUrl.isNotEmpty)
          CachedNetworkImage(
            imageUrl: widget.thumbnailUrl,
            fit: BoxFit.cover,
          ), // 🌟 THE FIX
        if (_controller != null && _controller!.value.isInitialized)
          ClipRect(
            child: FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: _controller!.value.size.width,
                height: _controller!.value.size.height,
                child: VideoPlayer(_controller!),
              ),
            ),
          )
        else
          Container(color: Colors.black.withValues(alpha: 0.3)),
        const Positioned(
          top: 5,
          right: 5,
          child: Icon(Icons.play_circle_fill, color: Colors.white, size: 24),
        ),
      ],
    );
  }
}

class GridAudioItem extends StatefulWidget {
  final String audioUrl;
  final String profilePic;
  const GridAudioItem({
    super.key,
    required this.audioUrl,
    required this.profilePic,
  });
  @override
  State<GridAudioItem> createState() => _GridAudioItemState();
}

class _GridAudioItemState extends State<GridAudioItem> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted)
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        CircleAvatar(
          radius: 35,
          backgroundImage: CachedNetworkImageProvider(widget.profilePic),
        ), // 🌟 THE FIX
        GestureDetector(
          onTap: () async {
            if (_isPlaying)
              await _audioPlayer.pause();
            else
              await _audioPlayer.play(UrlSource(widget.audioUrl));
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
        const Positioned(
          top: 5,
          right: 5,
          child: Icon(Icons.music_note, color: Colors.white, size: 20),
        ),
      ],
    );
  }
}

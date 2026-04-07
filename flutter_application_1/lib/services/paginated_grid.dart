import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/cached_media_widget.dart'; // 🌟 ఫోల్డర్ పాత్ ఫిక్స్ చేసాం
import '../screens/posts/scrolling_posts_screen.dart';
import '../screens/reels/scrolling_reels_screen.dart';

class PaginatedGrid extends StatefulWidget {
  final Query query;
  final bool isReel;
  final bool isScrollable; // 🌟 సేవ్డ్ ట్యాబ్ లో వాడటానికి

  const PaginatedGrid({
    super.key,
    required this.query,
    this.isReel = false,
    this.isScrollable = true,
  });

  @override
  State<PaginatedGrid> createState() => _PaginatedGridState();
}

class _PaginatedGridState extends State<PaginatedGrid> {
  final List<DocumentSnapshot> _docs = [];
  bool _isLoading = false;
  bool _hasMore = true;
  final int _limit = 12;
  DocumentSnapshot? _lastDoc;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchData();
    if (widget.isScrollable) {
      _scrollController.addListener(() {
        if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
          _fetchData();
        }
      });
    }
  }

  Future<void> _fetchData() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    try {
      Query q = widget.query.limit(_limit);
      if (_lastDoc != null) {
        q = q.startAfterDocument(_lastDoc!);
      }

      var snapshot = await q.get();
      if (snapshot.docs.length < _limit) {
        _hasMore = false;
      }

      if (snapshot.docs.isNotEmpty) {
        _lastDoc = snapshot.docs.last;
        _docs.addAll(snapshot.docs);
      }
    } catch (e) {
      debugPrint("Pagination Error: $e");
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_docs.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_docs.isEmpty && !_isLoading) {
      return const Center(
        child: Text("No posts yet. 📸", style: TextStyle(color: Colors.grey)),
      );
    }

    return GridView.builder(
      controller: widget.isScrollable ? _scrollController : null,
      shrinkWrap: !widget.isScrollable,
      physics: widget.isScrollable
          ? const AlwaysScrollableScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(2),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: widget.isReel
            ? 0.65
            : 1.0, // రీల్స్ కి పొడవుగా, పోస్టులకి స్క్వేర్
      ),
      itemCount: _docs.length + (_hasMore && widget.isScrollable ? 3 : 0),
      itemBuilder: (context, index) {
        if (index >= _docs.length) {
          return Container(
            color: Colors.grey.withValues(alpha: 0.2),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        var data = _docs[index].data() as Map<String, dynamic>;
        String mediaUrl = "";

        if (data['postData'] is List && (data['postData'] as List).isNotEmpty) {
          mediaUrl = data['postData'][0];
        } else {
          mediaUrl =
              data['postData'] ?? data['storyUrl'] ?? data['videoUrl'] ?? "";
        }

        return GestureDetector(
          onTap: () {
            if (widget.isReel) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ScrollingReelsScreen(
                    reelIds: _docs.map((d) => d.id).toList(),
                    initialIndex: index,
                  ),
                ),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ScrollingPostsScreen(
                    postIds: _docs.map((d) => d.id).toList(),
                    initialIndex: index,
                  ),
                ),
              );
            }
          },
          child: CachedMediaWidget(
            mediaUrl: mediaUrl,
            type: data['type'] ?? (widget.isReel ? 'video' : 'image'),
            isGrid: true,
          ),
        );
      },
    );
  }
}

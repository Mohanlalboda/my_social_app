// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import '../../widgets/post_widget.dart';
import '../../widgets/reel_item.dart';
import '../../utils/constants.dart';

class NearMeScreen extends StatefulWidget {
  const NearMeScreen({super.key});

  @override
  State<NearMeScreen> createState() => _NearMeScreenState();
}

class _NearMeScreenState extends State<NearMeScreen> {
  Position? _currentPosition;
  bool _isLoading = true;
  String _statusText = "Searching for nearby content... 🛰️";
  List<DocumentSnapshot> _nearbyDocs = [];
  final double _maxDistanceInKm = 500.0;

  // 🌟 PAGINATION
  DocumentSnapshot? _lastDocument;
  bool _hasMoreData = true;
  bool _isFetchingMore = false;

  @override
  void initState() {
    super.initState();
    _getUserLocationAndPosts();
  }

  Future<void> _getUserLocationAndPosts() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted)
        setState(() {
          _statusText = "Please turn on GPS 📍";
          _isLoading = false;
        });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted)
          setState(() {
            _statusText = "Location permission denied 🛑";
            _isLoading = false;
          });
        return;
      }
    }

    try {
      Position position = await Geolocator.getCurrentPosition();
      if (mounted) setState(() => _currentPosition = position);
      _fetchNearbyContent(isInitial: true);
    } catch (e) {
      if (mounted)
        setState(() {
          _statusText = "Error getting location";
          _isLoading = false;
        });
    }
  }

  // 🌟 ADVANCED PAGINATION LOGIC
  Future<void> _fetchNearbyContent({bool isInitial = false}) async {
    if (_currentPosition == null || !_hasMoreData) return;

    // ఒకేసారి రెండుసార్లు లాగకుండా ఆపుతున్నాం
    if (!isInitial && _isFetchingMore) return;

    if (isInitial) {
      setState(() => _isLoading = true);
    } else {
      setState(() => _isFetchingMore = true);
    }

    try {
      List<DocumentSnapshot> newFilteredDocs = [];
      int fetchAttempts = 0;

      // 🌟 THE FIX: దగ్గర్లో ఉన్నవి దొరికే వరకు (లేదా గరిష్టంగా 5 సార్లు = 100 పోస్ట్‌లు) వెతుకుతూనే ఉంటాం!
      while (newFilteredDocs.isEmpty && _hasMoreData && fetchAttempts < 5) {
        fetchAttempts++;

        Query q = FirebaseFirestore.instance
            .collection('posts')
            .orderBy('timestamp', descending: true)
            .limit(20);

        if (_lastDocument != null) {
          q = q.startAfterDocument(_lastDocument!);
        }

        var snapshot = await q.get();
        if (snapshot.docs.length < 20) _hasMoreData = false;

        if (snapshot.docs.isNotEmpty) {
          _lastDocument = snapshot.docs.last;

          for (var doc in snapshot.docs) {
            var data = doc.data() as Map<String, dynamic>;

            if (data['latitude'] != null && data['longitude'] != null) {
              // 🌟 THE FIX: String వచ్చినా సరే డబుల్ లోకి మార్చుకుని క్రాష్ అవ్వకుండా కాపాడుతాం
              double lat = double.tryParse(data['latitude'].toString()) ?? 0.0;
              double lng = double.tryParse(data['longitude'].toString()) ?? 0.0;

              if (lat != 0.0 && lng != 0.0) {
                double distInMeters = Geolocator.distanceBetween(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                  lat,
                  lng,
                );

                double distInKm = distInMeters / 1000;
                if (distInKm <= _maxDistanceInKm) {
                  newFilteredDocs.add(doc);
                }
              }
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          if (isInitial) {
            _nearbyDocs = newFilteredDocs;
            if (_nearbyDocs.isEmpty)
              _statusText = "No posts found near you 🏕️";
            _isLoading = false;
          } else {
            _nearbyDocs.addAll(newFilteredDocs);
            _isFetchingMore = false;
          }
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _statusText = "Error fetching content";
          _isLoading = false;
          _isFetchingMore = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        title: const Text(
          "Nearby Discovery",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: brandGradient.colors[0]),
            )
          : _nearbyDocs.isEmpty
          ? Center(
              child: Text(
                _statusText,
                style: const TextStyle(color: Colors.grey),
              ),
            )
          : PageView.builder(
              scrollDirection: Axis.vertical,
              itemCount: _nearbyDocs.length + (_hasMoreData ? 1 : 0),
              onPageChanged: (index) {
                if (index >= _nearbyDocs.length - 1 &&
                    _hasMoreData &&
                    !_isFetchingMore) {
                  _fetchNearbyContent();
                }
              },
              itemBuilder: (context, index) {
                if (index == _nearbyDocs.length) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: brandGradient.colors[0],
                    ),
                  );
                }

                var data = _nearbyDocs[index].data() as Map<String, dynamic>;
                String type = data['type'] ?? "image";

                if (type == 'video') {
                  return ReelItem(
                    reel: data,
                    reelId: _nearbyDocs[index].id,
                    isCurrentPage: true,
                  );
                } else {
                  return Center(
                    child: SingleChildScrollView(child: PostWidget(post: data)),
                  );
                }
              },
            ),
    );
  }
}

// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import '../../widgets/post_widget.dart';
import '../../widgets/reel_item.dart';
import '../../utils/constants.dart';

// 🌟 THE FIX: యాడ్స్ ఇంపోర్ట్స్ పక్కాగా ఉండాలి
import '../../services/ad_helper.dart';
import '../../widgets/my_native_ad_widget.dart';

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

  DocumentSnapshot? _lastDocument;
  bool _hasMoreData = true;
  bool _isFetchingMore = false;

  // 🌟 ఇంటర్‌స్టీషియల్ యాడ్స్ కోసం స్వైప్ కౌంటర్
  int _swipeCount = 0;

  @override
  void initState() {
    super.initState();
    _getUserLocationAndPosts();
    AdHelper.loadInterstitial(); // 🌟 యాడ్ ముందుగానే లోడ్ చేసి ఉంచుతాం
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

  Future<void> _fetchNearbyContent({bool isInitial = false}) async {
    if (_currentPosition == null || !_hasMoreData) return;

    if (!isInitial && _isFetchingMore) return;

    if (isInitial) {
      setState(() => _isLoading = true);
    } else {
      setState(() => _isFetchingMore = true);
    }

    try {
      List<DocumentSnapshot> newFilteredDocs = [];
      int fetchAttempts = 0;

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

    // 🌟 THE FIX: ప్రతి 3 పోస్ట్‌లకు 1 నేటివ్ యాడ్ వచ్చేలా క్యాలిక్యులేషన్ మార్చాను
    int adCount = _nearbyDocs.length ~/ 3;
    int totalItems = _nearbyDocs.length + adCount + (_hasMoreData ? 1 : 0);

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
              itemCount: totalItems,
              onPageChanged: (index) {
                _swipeCount++;

                // 🌟 THE FIX: ప్రతి 4 స్వైప్స్ కి ఒక ఫుల్ స్క్రీన్ యాడ్ వస్తుంది (Interstitial)
                if (_swipeCount > 0 && _swipeCount % 4 == 0) {
                  AdHelper.showInterstitial();
                }

                if (index >= totalItems - 2 &&
                    _hasMoreData &&
                    !_isFetchingMore) {
                  _fetchNearbyContent();
                }
              },
              itemBuilder: (context, index) {
                // లాస్ట్ ఐటెమ్ (లోడింగ్ స్పిన్నర్)
                if (index == totalItems - 1 && _hasMoreData) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: brandGradient.colors[0],
                    ),
                  );
                }

                // 🌟 THE FIX: ప్రతి 3 పోస్ట్‌లకి నేటివ్ యాడ్ వస్తుంది (index 3, 7, 11...)
                if (index > 0 && index % 4 == 3) {
                  return Scaffold(
                    backgroundColor: isDark ? Colors.black : Colors.white,
                    body: const Center(
                      child: MyNativeAdWidget(), // నేటివ్ యాడ్ విడ్జెట్
                    ),
                  );
                }

                // ఒరిజినల్ పోస్ట్ ఇండెక్స్ కి మారుస్తున్నాం
                int docIndex = index - (index ~/ 4);
                if (docIndex >= _nearbyDocs.length)
                  return const SizedBox(); // సేఫ్టీ చెక్

                var data = _nearbyDocs[docIndex].data() as Map<String, dynamic>;
                String type = data['type'] ?? "image";

                if (type == 'video') {
                  return ReelItem(
                    reel: data,
                    reelId: _nearbyDocs[docIndex].id,
                    isCurrentPage: true, // ఇక్కడ వీడియో ప్లే అవుతుంది
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

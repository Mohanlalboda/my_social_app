// ignore_for_file: curly_braces_in_flow_control_structures, use_build_context_synchronously

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

    // 🌟 THE FIX: ఇక్కడే ప్లే స్టోర్ కి కావాల్సిన Disclosure Pop-up పెట్టాం
    if (permission == LocationPermission.denied) {
      bool? userAgreed = await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[900]
              : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Row(
            children: [
              Icon(Icons.location_on, color: Colors.red),
              SizedBox(width: 10),
              Text("Use your location?", style: TextStyle(fontSize: 18)),
            ],
          ),
          content: const Text(
            "MyBanjara collects location data to enable the 'Near Me' feature, allowing you to discover and connect with nearby creators and posts. We only access this data while the app is in use.",
            style: TextStyle(fontSize: 15, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                "NO THANKS",
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("ALLOW", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      // యూజర్ ALLOW నొక్కితేనే సిస్టమ్ పర్మిషన్ అడుగుతాం
      if (userAgreed == true) {
        permission = await Geolocator.requestPermission();
      } else {
        if (mounted)
          setState(() {
            _statusText = "Location access is required 🛑";
            _isLoading = false;
          });
        return;
      }

      if (permission == LocationPermission.denied) {
        if (mounted)
          setState(() {
            _statusText = "Location permission denied 🛑";
            _isLoading = false;
          });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted)
        setState(() {
          _statusText = "Location permissions are permanently denied.";
          _isLoading = false;
        });
      return;
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

    // ఎంతమంది నేటివ్ యాడ్స్ వస్తాయో ముందుగానే లెక్కిస్తున్నాం
    // ప్రతి 11 పోస్టులకి ఒక యాడ్ (4, 15, 26...)
    int adCount = 0;
    if (_nearbyDocs.length >= 4) {
      adCount = 1 + ((_nearbyDocs.length - 4) ~/ 11);
    }

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

                // 🌟 THE FIX: కస్టమ్ Interstitial Ad లాజిక్ (10, 21, 32...)
                // 10వ పోస్ట్ దగ్గర, ఆ తర్వాత ప్రతి 11 పోస్ట్ లకి (21, 32)
                if (_swipeCount == 10 ||
                    (_swipeCount > 10 && (_swipeCount - 10) % 11 == 0)) {
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

                // 🌟 THE FIX: కస్టమ్ Native Ad లాజిక్ (4, 15, 26...)
                // 4వ పోస్ట్ దగ్గర (index 3), ఆ తర్వాత ప్రతి 11 పోస్ట్ లకి
                if (index == 3 || (index > 3 && (index - 3) % 11 == 0)) {
                  return Scaffold(
                    backgroundColor: isDark ? Colors.black : Colors.white,
                    body: const Center(
                      child: MyNativeAdWidget(), // నేటివ్ యాడ్ విడ్జెట్
                    ),
                  );
                }

                // ఒరిజినల్ పోస్ట్ ఇండెక్స్ కి మారుస్తున్నాం
                int adCountBeforeThisIndex = 0;
                if (index > 3) {
                  adCountBeforeThisIndex = 1 + ((index - 4) ~/ 11);
                }

                int docIndex = index - adCountBeforeThisIndex;

                if (docIndex >= _nearbyDocs.length || docIndex < 0) {
                  return const SizedBox(); // సేఫ్టీ చెక్
                }

                var data = _nearbyDocs[docIndex].data() as Map<String, dynamic>;
                String type = data['type'] ?? "image";

                if (type == 'video') {
                  return ReelItem(
                    reel: data,
                    reelId: _nearbyDocs[docIndex].id,
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

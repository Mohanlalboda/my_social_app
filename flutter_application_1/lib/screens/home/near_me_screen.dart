// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../widgets/safe_elements.dart';
import '../../widgets/cached_media_widget.dart';

class NearMeScreen extends StatefulWidget {
  const NearMeScreen({super.key});

  @override
  State<NearMeScreen> createState() => _NearMeScreenState();
}

class _NearMeScreenState extends State<NearMeScreen> {
  Position? _currentPosition;
  bool _isLoading = true;
  String _statusText = "Searching for location... 🛰️";

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _nearbyPosts = [];
  final double _maxDistanceInKm = 20.0; // 20 కి.మీ పరిధిలో ఉన్నవి మాత్రమే!

  @override
  void initState() {
    super.initState();
    _getUserLocationAndPosts();
  }

  // 📍 1. యూజర్ లొకేషన్ తీసుకోవడం
  Future<void> _getUserLocationAndPosts() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // 🌟 FIX: స్క్రీన్ ఇంకా ఉంటేనే setState చేయాలి
      if (mounted) {
        setState(() {
          _statusText = "Please turn on your GPS Location! 📍";
          _isLoading = false;
        });
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() {
            _statusText = "Location permissions denied! 🚫";
            _isLoading = false;
          });
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() {
          _statusText = "Location permissions are permanently denied.";
          _isLoading = false;
        });
      }
      return;
    }

    if (mounted)
      setState(() => _statusText = "Getting your exact coordinates... 🎯");

    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (e) {
      debugPrint("Location error: $e");
    }

    // 🌟 FIX: లొకేషన్ తెచ్చుకునే లోపు యూజర్ బ్యాక్ కి వెళ్లిపోతే, కింద ఫంక్షన్ రన్ అవ్వకూడదు
    if (!mounted) return;

    _fetchNearbyPosts();
  }

  // 📡 2. చుట్టుపక్కల పోస్ట్‌లను ఫెచ్ చేసి ఫిల్టర్ చేయడం
  Future<void> _fetchNearbyPosts() async {
    if (mounted)
      setState(() => _statusText = "Scanning radar for nearby posts... 📡");

    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      List<QueryDocumentSnapshot<Map<String, dynamic>>> filteredPosts = [];

      for (var doc in snapshot.docs) {
        var data = doc.data();

        if (data.containsKey('latitude') && data.containsKey('longitude')) {
          double postLat = data['latitude'];
          double postLng = data['longitude'];

          if (_currentPosition != null) {
            double distanceInMeters = Geolocator.distanceBetween(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              postLat,
              postLng,
            );

            double distanceInKm = distanceInMeters / 1000;

            if (distanceInKm <= _maxDistanceInKm) {
              filteredPosts.add(doc);
            }
          }
        }
      }

      // 🌟 FIX: డేటా వచ్చాక స్క్రీన్ ఉందో లేదో చెక్ చేసి అప్‌డేట్ చేయాలి
      if (mounted) {
        setState(() {
          _nearbyPosts = filteredPosts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Radar Error: $e");
      if (mounted) {
        setState(() {
          _statusText = "Failed to load radar! ⚠️";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[100],
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.location_on, color: Colors.red),
            const SizedBox(width: 5),
            Text(
              "Near Me (${_maxDistanceInKm.toInt()}km)",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.radar, color: Colors.blue),
            onPressed: () {
              if (mounted) setState(() => _isLoading = true);
              _getUserLocationAndPosts();
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.red),
                  const SizedBox(height: 20),
                  Text(
                    _statusText,
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            )
          : _nearbyPosts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_off, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 10),
                  const Text(
                    "No posts found near you! 🤷‍♂️",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    "Be the first to post in your area!",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _nearbyPosts.length,
              itemBuilder: (context, index) {
                var data = _nearbyPosts[index].data();
                String ownerId = data['ownerId'] ?? '';
                String caption = data['caption'] ?? '';
                List mediaUrls = data['postData'] ?? [];
                String type = data['type'] ?? 'image';
                DateTime? time = (data['timestamp'] as Timestamp?)?.toDate();
                String timeStr = time != null ? timeago.format(time) : 'now';

                return Card(
                  margin: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 10,
                  ),
                  color: isDark ? Colors.grey[900] : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        leading: FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(ownerId)
                              .get(),
                          builder: (ctx, snap) {
                            if (!snap.hasData)
                              return const CircleAvatar(radius: 20);
                            var userData =
                                snap.data!.data() as Map<String, dynamic>;
                            return SafeProfilePic(
                              base64String: userData['profilePic'],
                              radius: 20,
                              fallbackText: 'U',
                            );
                          },
                        ),
                        title: FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(ownerId)
                              .get(),
                          builder: (ctx, snap) {
                            if (!snap.hasData) return const Text("User");
                            var userData =
                                snap.data!.data() as Map<String, dynamic>;
                            return Text(
                              userData['username'] ?? "User",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                        subtitle: Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 12,
                              color: Colors.red,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              "Nearby • $timeStr",
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (mediaUrls.isNotEmpty)
                        CachedMediaWidget(
                          mediaUrl: mediaUrls[0],
                          type: type,
                          isGrid: false,
                        ),

                      if (caption.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Text(
                            caption,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

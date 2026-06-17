// lib/screens/search/banjara_radar_screen.dart
// ignore_for_file: unused_import, use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart'; // 🌟 THE FIX: Missing import added!

import '../../utils/constants.dart';
import '../profile/profile_screen.dart';
import '../chat/chat_room_screen.dart';

class BanjaraRadarScreen extends StatefulWidget {
  const BanjaraRadarScreen({super.key});

  @override
  State<BanjaraRadarScreen> createState() => _BanjaraRadarScreenState();
}

class _BanjaraRadarScreenState extends State<BanjaraRadarScreen> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  GoogleMapController? _mapController;
  Position? _currentPosition;
  Set<Marker> _markers = {};
  List<Map<String, dynamic>> _nearbyDataList = [];

  bool _isLocating = true;
  String _statusText = "Starting Banjara Radar... 🛰️";

  Map<String, dynamic>? _myUserData;
  bool _isGhostMode = false;

  String _selectedFilter = "All Users";
  String _searchQuery = "";

  StreamSubscription<QuerySnapshot>? _usersSubscription;

  @override
  void initState() {
    super.initState();
    _initMapAndLocation();
  }

  @override
  void dispose() {
    _usersSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // 📍 1. లొకేషన్ పర్మిషన్స్ మరియు ఘోస్ట్ మోడ్ చెక్
  Future<void> _initMapAndLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted)
        setState(() {
          _isLocating = false;
          _statusText = "Please enable GPS Location services.";
        });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted)
          setState(() {
            _isLocating = false;
            _statusText = "Location permission denied.";
          });
        return;
      }
    }

    Position pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    var myDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUid)
        .get();
    if (myDoc.exists) {
      _myUserData = myDoc.data();
      _isGhostMode = _myUserData?['isGhostMode'] ?? false;
    }

    if (!_isGhostMode) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .update({'latitude': pos.latitude, 'longitude': pos.longitude});
    }

    if (mounted) {
      setState(() {
        _currentPosition = pos;
        _isLocating = false;
      });
      _listenToNearbyData();
    }
  }

  // 📡 2. ఫైర్‌బేస్ నుండి డేటా తెచ్చుకుని మ్యాప్ & లిస్ట్ కి ఇవ్వడం
  void _listenToNearbyData() {
    _usersSubscription = FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .listen((snapshot) async {
          if (_currentPosition == null) return;

          List<Map<String, dynamic>> tempList = [];
          Set<Marker> tempMarkers = {};

          for (var doc in snapshot.docs) {
            if (doc.id == currentUid) continue;

            var data = doc.data();
            if (data['isGhostMode'] == true) continue;

            if (data['latitude'] != null && data['longitude'] != null) {
              double lat = double.parse(data['latitude'].toString());
              double lng = double.parse(data['longitude'].toString());

              double distanceInMeters = Geolocator.distanceBetween(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
                lat,
                lng,
              );
              double distanceInKm = distanceInMeters / 1000;

              if (distanceInKm <= 50) {
                String pinType = data['accountType'] ?? "user";
                String surname = (data['gothra'] ?? "")
                    .toString()
                    .toLowerCase();
                String village = (data['thanda'] ?? "")
                    .toString()
                    .toLowerCase();

                bool shouldAdd = false;

                if (_selectedFilter == "All Users" &&
                    pinType != "event" &&
                    pinType != "shop") {
                  shouldAdd = true;
                } else if (_selectedFilter == "Search by Surname" &&
                    pinType != "event" &&
                    pinType != "shop") {
                  if (_searchQuery.isEmpty || surname.contains(_searchQuery))
                    shouldAdd = true;
                } else if (_selectedFilter == "Search by Village") {
                  if (_searchQuery.isEmpty || village.contains(_searchQuery))
                    shouldAdd = true;
                } else if (_selectedFilter == "Nearby Events 🎪" &&
                    pinType == "event") {
                  shouldAdd = true;
                } else if (_selectedFilter == "Local Shops 🛍️" &&
                    pinType == "shop") {
                  shouldAdd = true;
                }

                if (shouldAdd) {
                  data['uid'] = doc.id;
                  data['distance'] = distanceInKm.toStringAsFixed(1);
                  tempList.add(data);

                  BitmapDescriptor customIcon;
                  String displayTitle = data['username'] ?? "User";

                  if (pinType == "shop") {
                    customIcon = await _getMarkerWithText(
                      displayTitle,
                      Colors.blue,
                      "shop",
                    );
                  } else if (pinType == "event") {
                    customIcon = await _getMarkerWithText(
                      displayTitle,
                      Colors.green,
                      "event",
                    );
                  } else {
                    String? pPic = data['profilePic'] ?? data['profilePicture'];
                    String fallback = displayTitle.isNotEmpty
                        ? displayTitle[0]
                        : "U";
                    customIcon = await _getUserProfileMarker(pPic, fallback);
                  }

                  tempMarkers.add(
                    Marker(
                      markerId: MarkerId(doc.id),
                      position: LatLng(lat, lng),
                      icon: customIcon,
                      anchor: const Offset(0.5, 1.0),
                      infoWindow: InfoWindow(
                        title: displayTitle,
                        snippet: "${data['distance']} KM away",
                      ),
                      onTap: () {
                        _showPinDetailsPopup(data);
                      },
                    ),
                  );
                }
              }
            }
          }

          tempList.sort(
            (a, b) => double.parse(
              a['distance'],
            ).compareTo(double.parse(b['distance'])),
          );

          if (mounted) {
            setState(() {
              _nearbyDataList = tempList;
              _markers = tempMarkers;
            });
          }
        });
  }

  // ---------------------------------------------------------
  // 🌟 NEW: షాప్/ఈవెంట్ డిటైల్స్ మరియు డిలీట్ ఆప్షన్ (Popup)
  // ---------------------------------------------------------
  void _showPinDetailsPopup(Map<String, dynamic> data) {
    String type = data['accountType'] ?? "user";
    String name = data['username'] ?? "Name";
    String desc = data['thanda'] ?? "No description available.";
    String distance = data['distance'] ?? "0";
    String uid = data['uid'];
    String ownerId = data['ownerId'] ?? "";
    String image =
        data['profilePic'] ?? ""; // 🌟 THE FIX: Here the variable is 'image'

    bool isMine = ownerId == currentUid;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: type == 'shop'
                        ? Colors.blue
                        : (type == 'event' ? Colors.green : Colors.grey),
                    // 🌟 THE FIX: Used CachedNetworkImageProvider with correct variable 'image'
                    backgroundImage: image.isNotEmpty
                        ? CachedNetworkImageProvider(image)
                        : null,
                    child: image.isEmpty
                        ? Icon(
                            type == 'shop'
                                ? Icons.storefront
                                : (type == 'event'
                                      ? Icons.event
                                      : Icons.person),
                            color: Colors.white,
                            size: 35,
                          )
                        : null,
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          "${type.toUpperCase()} • $distance KM Away 📍",
                          style: const TextStyle(
                            color: Colors.blueAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (type == 'shop' || type == 'event') ...[
                const Text(
                  "Description / Details:",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 30),
              ],

              if (isMine)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.delete_forever, color: Colors.white),
                    label: const Text(
                      "Delete this Pin",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      _deletePin(uid);
                    },
                  ),
                )
              else if (type == "user")
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.person, color: Colors.white),
                    label: const Text(
                      "View Profile",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfileScreen(userId: uid),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // 🗑️ పిన్ డిలీట్ ఫంక్షన్
  Future<void> _deletePin(String uid) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Pin?"),
        content: const Text(
          "Are you sure you want to delete this pin from the map?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("🗑️ Pin deleted successfully!")),
        );
      }
    }
  }

  // 👻 3. ఘోస్ట్ మోడ్ టోగుల్
  Future<void> _toggleGhostMode() async {
    setState(() => _isGhostMode = !_isGhostMode);
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUid)
        .update({
          'isGhostMode': _isGhostMode,
          'latitude': _isGhostMode
              ? FieldValue.delete()
              : _currentPosition?.latitude,
          'longitude': _isGhostMode
              ? FieldValue.delete()
              : _currentPosition?.longitude,
        });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isGhostMode
              ? "👻 Ghost Mode ON: Invisible"
              : "📍 Ghost Mode OFF: Visible",
        ),
        backgroundColor: _isGhostMode ? Colors.purple : Colors.green,
      ),
    );
  }

  // ➕ 4. ADD SHOP / EVENT FORM
  void _showAddPinForm() {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("📍 లొకేషన్ లోడ్ అయ్యే వరకు ఆగండి బాస్!")),
      );
      return;
    }

    final nameController = TextEditingController();
    final infoController = TextEditingController();
    String pinType = "shop";
    DateTime selectedEndDateTime = DateTime.now().add(const Duration(days: 1));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "➕ Add Shop / Event on Map",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<String>(
                  value: pinType,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                      value: "shop",
                      child: Text("Store / Shop 🏪"),
                    ),
                    DropdownMenuItem(
                      value: "event",
                      child: Text("Festival / Event 🚩"),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => pinType = val);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: "Name (పేరు)",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: infoController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: "Description / Details",
                    border: OutlineInputBorder(),
                  ),
                ),

                if (pinType == "event") ...[
                  const SizedBox(height: 15),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Event Ends on (ముగింపు సమయం):",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Card(
                    color: Colors.orange.shade50,
                    child: ListTile(
                      leading: const Icon(Icons.alarm, color: Colors.orange),
                      title: Text(
                        "${selectedEndDateTime.day}/${selectedEndDateTime.month}/${selectedEndDateTime.year}  -  ${TimeOfDay.fromDateTime(selectedEndDateTime).format(context)}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.edit,
                        size: 18,
                        color: Colors.orange,
                      ),
                      onTap: () async {
                        DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: selectedEndDateTime,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 90),
                          ),
                        );

                        if (pickedDate != null) {
                          TimeOfDay? pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(
                              selectedEndDateTime,
                            ),
                          );

                          if (pickedTime != null) {
                            setModalState(() {
                              selectedEndDateTime = DateTime(
                                pickedDate.year,
                                pickedDate.month,
                                pickedDate.day,
                                pickedTime.hour,
                                pickedTime.minute,
                              );
                            });
                          }
                        }
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  "📌 Note: మీ కరెంట్ లొకేషన్‌లోనే ఈ పిన్ యాడ్ అవుతుంది.",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
              ),
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                Navigator.pop(ctx);

                await FirebaseFirestore.instance.collection('users').add({
                  'username': nameController.text.trim(),
                  'gothra': pinType == "shop" ? "Shop" : "Event",
                  'thanda': infoController.text.trim(),
                  'accountType': pinType,
                  'latitude': _currentPosition!.latitude,
                  'longitude': _currentPosition!.longitude,
                  'isGhostMode': false,
                  'ownerId': currentUid,
                  'timestamp': FieldValue.serverTimestamp(),
                  'endDate': pinType == "event"
                      ? Timestamp.fromDate(selectedEndDateTime)
                      : null,
                });

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        "🎉 ${pinType.toUpperCase()} యాడ్ అయ్యింది!",
                      ),
                    ),
                  );
                }
              },
              child: const Text(
                "ADD PIN",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // 🎨 5. మార్కర్స్ డిజైన్ ఫంక్షన్స్ (సూది పిన్స్ & ప్రొఫైల్ పిక్స్)
  // ---------------------------------------------------------
  Future<BitmapDescriptor> _getMarkerWithText(
    String name,
    Color pinColor,
    String type,
  ) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double boxWidth = 100.0,
        boxHeight = 32.0,
        arrowWidth = 10.0,
        arrowHeight = 8.0,
        totalHeight = boxHeight + arrowHeight,
        radius = 10.0;
    final Paint fillPaint = Paint()
      ..color = pinColor
      ..style = PaintingStyle.fill;
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final Path arrowPath = Path();
    arrowPath.moveTo((boxWidth / 2) - (arrowWidth / 2), boxHeight - 2);
    arrowPath.lineTo(boxWidth / 2, totalHeight);
    arrowPath.lineTo((boxWidth / 2) + (arrowWidth / 2), boxHeight - 2);
    arrowPath.close();
    canvas.drawPath(arrowPath, fillPaint);
    canvas.drawPath(arrowPath, borderPaint);

    final RRect boxRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0.0, 0.0, boxWidth, boxHeight),
      const Radius.circular(radius),
    );
    canvas.drawRRect(boxRect, fillPaint);
    canvas.drawRRect(boxRect, borderPaint);

    String iconPrefix = type == "shop" ? "🏪 " : "🚩 ";
    String cleanName = name.length > 7 ? '${name.substring(0, 5)}..' : name;

    TextPainter painter = TextPainter(textDirection: TextDirection.ltr);
    painter.text = TextSpan(
      text: iconPrefix + cleanName,
      style: const TextStyle(
        fontSize: 10.5,
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    );
    painter.layout();
    painter.paint(
      canvas,
      Offset((boxWidth - painter.width) / 2, (boxHeight - painter.height) / 2),
    );

    final img = await pictureRecorder.endRecording().toImage(
      boxWidth.toInt(),
      totalHeight.toInt(),
    );
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(data!.buffer.asUint8List());
  }

  Future<BitmapDescriptor> _getUserProfileMarker(
    String? imageSource,
    String fallbackLetter,
  ) async {
    const double size = 38.0, totalHeight = 50.0;
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint()..isAntiAlias = true;

    final Path pinPath = Path();
    pinPath.moveTo(size / 2, totalHeight);
    pinPath.lineTo((size / 2) - 6, size - 4);
    pinPath.lineTo((size / 2) + 6, size - 4);
    pinPath.close();
    paint.color = Colors.orange.shade800;
    canvas.drawPath(pinPath, paint);

    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, paint);
    paint.color = Colors.white;
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      (size / 2) - 2.0,
      paint,
    );

    final Path clipPath = Path()
      ..addOval(const Rect.fromLTWH(2, 2, size - 4, size - 4));
    canvas.save();
    canvas.clipPath(clipPath);

    bool imgLoaded = false;
    if (imageSource != null && imageSource.trim().isNotEmpty) {
      try {
        String src = imageSource.trim();
        Uint8List imageBytes = Uint8List(0);
        if (src.startsWith('http')) {
          final Completer<Uint8List> bytesCompleter = Completer();
          final NetworkImage networkImage = NetworkImage(src);
          final ImageStream stream = networkImage.resolve(
            ImageConfiguration.empty,
          );
          late ImageStreamListener listener;
          listener = ImageStreamListener((ImageInfo info, bool syncCall) async {
            final ByteData? data = await info.image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            if (data != null && !bytesCompleter.isCompleted)
              bytesCompleter.complete(data.buffer.asUint8List());
            stream.removeListener(listener);
          });
          stream.addListener(listener);
          imageBytes = await bytesCompleter.future.timeout(
            const Duration(seconds: 5),
            onTimeout: () => Uint8List(0),
          );
        }
        if (imageBytes.isNotEmpty) {
          final ui.Codec codec = await ui.instantiateImageCodec(imageBytes);
          final ui.FrameInfo frameInfo = await codec.getNextFrame();
          canvas.drawImageRect(
            frameInfo.image,
            Rect.fromLTWH(
              0,
              0,
              frameInfo.image.width.toDouble(),
              frameInfo.image.height.toDouble(),
            ),
            const Rect.fromLTWH(2, 2, size - 4, size - 4),
            paint,
          );
          imgLoaded = true;
        }
      } catch (e) {
        imgLoaded = false;
      }
    }

    if (!imgLoaded) {
      paint.color = Colors.orange.shade400;
      canvas.drawRect(const Rect.fromLTWH(2, 2, size - 4, size - 4), paint);
      TextPainter painter = TextPainter(textDirection: TextDirection.ltr);
      painter.text = TextSpan(
        text: fallbackLetter.toUpperCase(),
        style: const TextStyle(
          fontSize: 16.0,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      );
      painter.layout();
      painter.paint(
        canvas,
        Offset((size - painter.width) / 2, (size - painter.height) / 2),
      );
    }
    canvas.restore();
    final img = await pictureRecorder.endRecording().toImage(
      size.toInt(),
      totalHeight.toInt(),
    );
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(data!.buffer.asUint8List());
  }

  // ---------------------------------------------------------
  // 📱 6. స్క్రీన్ UI (Split Screen)
  // ---------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      drawer: _buildFilterDrawer(isDark),
      appBar: AppBar(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        title: Text(
          "Banjara Radar 📡 ($_selectedFilter)",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isGhostMode ? Icons.visibility_off : Icons.visibility,
              color: _isGhostMode ? Colors.purple : Colors.green,
            ),
            onPressed: _toggleGhostMode,
          ),
        ],
      ),
      body: _isLocating
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 10),
                  Text(_statusText),
                ],
              ),
            )
          : _currentPosition == null
          ? const Center(child: Text("Location required to use Radar."))
          : Column(
              children: [
                Expanded(
                  flex: 45,
                  child: Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: LatLng(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                          ),
                          zoom: 12,
                        ),
                        myLocationEnabled: !_isGhostMode,
                        zoomControlsEnabled: false,
                        onMapCreated: (controller) =>
                            _mapController = controller,
                        markers: _markers,
                      ),

                      if (_selectedFilter == "Search by Surname" ||
                          _selectedFilter == "Search by Village")
                        Positioned(
                          top: 10,
                          left: 15,
                          right: 15,
                          child: Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: TextField(
                              onChanged: (val) {
                                setState(
                                  () => _searchQuery = val.toLowerCase(),
                                );
                              },
                              decoration: InputDecoration(
                                hintText:
                                    "Enter ${_selectedFilter == 'Search by Surname' ? 'Surname' : 'Village'}...",
                                prefixIcon: const Icon(Icons.search),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 15,
                                  vertical: 15,
                                ),
                              ),
                            ),
                          ),
                        ),

                      // 🌟 "Add Event/Shop" Button
                      Positioned(
                        bottom: 10,
                        left: 10,
                        child: FloatingActionButton.extended(
                          heroTag: "add_pin_btn",
                          backgroundColor: Colors.orange.shade700,
                          onPressed: _showAddPinForm,
                          icon: const Icon(
                            Icons.add_location_alt_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          label: const Text(
                            "Add",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      // లొకేషన్ జూమ్ బటన్
                      Positioned(
                        bottom: 10,
                        right: 10,
                        child: FloatingActionButton(
                          heroTag: "my_loc_btn",
                          mini: true,
                          backgroundColor: Colors.white,
                          onPressed: () {
                            _mapController?.animateCamera(
                              CameraUpdate.newLatLngZoom(
                                LatLng(
                                  _currentPosition!.latitude,
                                  _currentPosition!.longitude,
                                ),
                                13.0,
                              ),
                            );
                          },
                          child: const Icon(
                            Icons.my_location,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  height: 3,
                  color: Colors.blueAccent.withValues(alpha: 0.5),
                ),

                Expanded(
                  flex: 55,
                  child: _nearbyDataList.isEmpty
                      ? Center(
                          child: Text(
                            "No users found for '$_selectedFilter'. 🏜️",
                            style: const TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _nearbyDataList.length,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemBuilder: (context, index) {
                            var data = _nearbyDataList[index];
                            String uid = data['uid'];
                            String name = data['username'] ?? "User";
                            String pic =
                                data['profilePic'] ??
                                ""; // 🌟 THE FIX: Here is the 'pic' variable
                            String type = data['accountType'] ?? "user";
                            String distance = data['distance'] ?? "0";
                            String village = data['thanda'] ?? "";
                            String surname = data['gothra'] ?? "";

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              color: isDark
                                  ? Colors.grey[900]
                                  : Colors.grey[100],
                              child: ListTile(
                                leading: GestureDetector(
                                  onTap: () {
                                    _showPinDetailsPopup(data);
                                  },
                                  child: CircleAvatar(
                                    backgroundColor: type == 'shop'
                                        ? Colors.blue
                                        : (type == 'event'
                                              ? Colors.green
                                              : Colors.grey),
                                    // 🌟 THE FIX: Used CachedNetworkImageProvider with correct variable 'pic'
                                    backgroundImage:
                                        (type == 'user' && pic.isNotEmpty)
                                        ? CachedNetworkImageProvider(pic)
                                        : null,
                                    child: type == 'shop'
                                        ? const Icon(
                                            Icons.storefront,
                                            color: Colors.white,
                                          )
                                        : (type == 'event'
                                              ? const Icon(
                                                  Icons.event,
                                                  color: Colors.white,
                                                )
                                              : null),
                                  ),
                                ),
                                title: Text(
                                  type == "user" ? "$surname $name" : name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  "${type.toUpperCase()} • $distance km away\n📍 $village",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                  maxLines: 2,
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.directions,
                                        color: Colors.orange,
                                      ),
                                      onPressed: () {
                                        double lat = data['latitude'];
                                        double lng = data['longitude'];
                                        _mapController?.animateCamera(
                                          CameraUpdate.newLatLngZoom(
                                            LatLng(lat, lng),
                                            15,
                                          ),
                                        );
                                      },
                                    ),
                                    if (type == "user")
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blueAccent,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                          ),
                                        ),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => ChatRoomScreen(
                                                receiverUid: uid,
                                                receiverUsername: name,
                                              ),
                                            ),
                                          );
                                        },
                                        child: const Text(
                                          "Chat",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                onTap: () {
                                  _showPinDetailsPopup(data);
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  // 📝 7. డ్రాయర్ మెనూ (Filters)
  Widget _buildFilterDrawer(bool isDark) {
    return Drawer(
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blueAccent),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.radar_rounded, size: 40, color: Colors.white),
                SizedBox(height: 10),
                Text(
                  "Radar Filters",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          _buildDrawerTile("All Users", Icons.people, "All Users", isDark),
          _buildDrawerTile(
            "Search by Surname",
            Icons.badge,
            "Search by Surname",
            isDark,
          ),
          _buildDrawerTile(
            "Search by Village",
            Icons.gite_rounded,
            "Search by Village",
            isDark,
          ),
          const Divider(),
          _buildDrawerTile(
            "Nearby Events 🎪",
            Icons.event,
            "Nearby Events 🎪",
            isDark,
          ),
          _buildDrawerTile(
            "Local Shops 🛍️",
            Icons.storefront,
            "Local Shops 🛍️",
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerTile(
    String title,
    IconData icon,
    String filterType,
    bool isDark,
  ) {
    return ListTile(
      leading: Icon(icon, color: isDark ? Colors.white70 : Colors.black87),
      title: Text(
        title,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      ),
      trailing: _selectedFilter == filterType
          ? const Icon(Icons.check_circle, color: Colors.blueAccent)
          : null,
      onTap: () {
        setState(() {
          _selectedFilter = filterType;
          _searchQuery = "";
        });
        Navigator.pop(context);
        _listenToNearbyData();
      },
    );
  }
}

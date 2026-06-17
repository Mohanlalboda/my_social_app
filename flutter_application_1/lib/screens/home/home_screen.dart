// lib/screens/home/home_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_update/in_app_update.dart'; // 🌟 అప్‌డేట్ కోసం ప్యాకేజీ

import '../../utils/constants.dart';
import '../search/search_screen.dart';
import 'notifications_screen.dart';

// క్రియేట్ చేయబోయే కొత్త విడ్జెట్స్
import 'widgets/home_stories_bar.dart';
import 'widgets/home_feed_list.dart';
import 'widgets/add_post_bottom_sheet.dart';

// 🌟 THE FIX: యూనివర్సల్ మ్యూట్ సిస్టమ్ కోసం గ్లోబల్ వేరియబుల్
final ValueNotifier<bool> globalMuteNotifier = ValueNotifier<bool>(true);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedFeedTab = 0;
  String _myVillageName = "";
  String _myProfilePic = "";
  final String _currentUid = FirebaseAuth.instance.currentUser!.uid;
  int _refreshFeedKey = 0;

  @override
  void initState() {
    super.initState();
    _fetchUserVillageData();
    _checkForUpdate(); // 🌟 అప్‌డేట్ చెక్ ఇక్కడ యాడ్ చేశాం
  }

  // 🚀 IN-APP UPDATE లాజిక్
  Future<void> _checkForUpdate() async {
    try {
      AppUpdateInfo updateInfo = await InAppUpdate.checkForUpdate();
      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        // అప్‌డేట్ ఉంటే Flexible అప్‌డేట్ స్టార్ట్ చేస్తుంది
        await InAppUpdate.startFlexibleUpdate();
        await InAppUpdate.completeFlexibleUpdate();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('యాప్ సక్సెస్ ఫుల్ గా అప్‌డేట్ అయ్యింది! 🎉'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("Update check failed: $e");
    }
  }

  void _fetchUserVillageData() async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUid)
          .get();
      if (userDoc.exists && userDoc.data() != null) {
        var data = userDoc.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _myVillageName = (data['village'] ?? "").toString().trim();
            _myProfilePic = (data['profilePic'] ?? "").toString().trim();
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching user village data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[200],
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        title: ShaderMask(
          shaderCallback: (bounds) => brandGradient.createShader(
            Rect.fromLTWH(0, 0, bounds.width, bounds.height),
          ),
          child: Text(
            "MyBanjara",
            style: GoogleFonts.lobster(fontSize: 28, color: Colors.white),
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(
              _selectedFeedTab == 0
                  ? Icons.language_rounded
                  : Icons.gite_rounded,
              color: _selectedFeedTab == 0 ? iconColor : Colors.blueAccent,
              size: 26,
            ),
            onPressed: () {
              setState(() => _selectedFeedTab = _selectedFeedTab == 0 ? 1 : 0);
              if (_selectedFeedTab == 1 && _myVillageName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "Please update your Tanda/Village name in your Profile! 🏕️",
                    ),
                  ),
                );
              }
            },
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(_currentUid)
                .collection('notifications')
                .where('isSeen', isEqualTo: false)
                .snapshots(),
            builder: (context, snapshot) {
              bool hasUnread =
                  snapshot.hasData && snapshot.data!.docs.isNotEmpty;
              return IconButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                ),
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(Icons.favorite_border, color: iconColor, size: 26),
                    if (hasUnread)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 10,
                            minHeight: 10,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.add_box_outlined, color: iconColor, size: 26),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                builder: (ctx) => AddPostBottomSheet(
                  onPostUploaded: () => setState(() => _refreshFeedKey++),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.search_rounded, color: iconColor, size: 26),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          HomeStoriesBar(
            myVillageName: _myVillageName,
            myProfilePic: _myProfilePic,
          ),
          Expanded(
            child: UnifiedFeedList(
              selectedFeedTab: _selectedFeedTab,
              myVillageName: _myVillageName,
              refreshKey: _refreshFeedKey,
            ),
          ),
        ],
      ),
    );
  }
}

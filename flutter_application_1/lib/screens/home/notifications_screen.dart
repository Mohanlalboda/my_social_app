// lib/screens/home/notifications_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../profile/profile_screen.dart';
import 'post_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _markNotificationsAsRead();
  }

  // 🔴 1. చూడని నోటిఫికేషన్స్ అన్నింటినీ 'చదివేశాం' అని మార్చడం
  void _markNotificationsAsRead() async {
    var snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUid)
        .collection('notifications')
        .where('isSeen', isEqualTo: false)
        .get();

    var batch = FirebaseFirestore.instance.batch();
    for (var doc in snap.docs) {
      batch.update(doc.reference, {'isSeen': true});
    }
    batch.commit();
  }

  // 🔴 2. ఒకేసారి అన్నీ డిలీట్ చేయడం (Clear All)
  void _clearAllNotifications() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Clear All?"),
        content: const Text(
          "Are you sure you want to delete all notifications?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Clear", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      var snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('notifications')
          .get();

      var batch = FirebaseFirestore.instance.batch();
      for (var doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("All notifications cleared!")),
        );
      }
    }
  }

  // 🔴 3. సింగిల్ నోటిఫికేషన్ డిలీట్ (Swipe to Delete కోసం)
  void _deleteSingleNotification(String notifId) {
    FirebaseFirestore.instance
        .collection('users')
        .doc(currentUid)
        .collection('notifications')
        .doc(notifId)
        .delete();
  }

  // 🔴 4. ఫాలో బ్యాక్ లాజిక్
  Future<void> _followBack(String targetUid, String notifId) async {
    // వాళ్ళ ఫాలోవర్స్ లో మనల్ని యాడ్ చేయడం
    await FirebaseFirestore.instance.collection('users').doc(targetUid).update({
      'followers': FieldValue.arrayUnion([currentUid]),
    });
    // మన ఫాలోయింగ్ లో వాళ్ళని యాడ్ చేయడం
    await FirebaseFirestore.instance.collection('users').doc(currentUid).update(
      {
        'following': FieldValue.arrayUnion([targetUid]),
      },
    );

    // నోటిఫికేషన్ టెక్స్ట్ మార్చడం లేదా టైప్ మార్చడం (బటన్ పోవడానికి)
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUid)
        .collection('notifications')
        .doc(notifId)
        .update({'type': 'followed_back', 'text': 'You followed them back.'});

    // 🌟 THE FIX: await తర్వాత context వాడే ముందు mounted చెక్ చేయడం!
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Followed back successfully!")),
    );
  }

  // 🔴 5. ప్రైవేట్ అకౌంట్ రిక్వెస్ట్ యాక్సెప్ట్ చేయడం
  Future<void> _acceptRequest(String targetUid, String notifId) async {
    // మన ఫాలోవర్స్ లోకి వాళ్ళని యాడ్ చేసుకోవడం
    await FirebaseFirestore.instance.collection('users').doc(currentUid).update(
      {
        'followers': FieldValue.arrayUnion([targetUid]),
      },
    );
    await FirebaseFirestore.instance.collection('users').doc(targetUid).update({
      'following': FieldValue.arrayUnion([currentUid]),
    });

    // రిక్వెస్ట్ నోటిఫికేషన్ ని 'యాక్సెప్ట్ చేసాం' అని మార్చడం
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUid)
        .collection('notifications')
        .doc(notifId)
        .update({
          'type': 'request_accepted',
          'text': 'You accepted their follow request.',
        });
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
        title: const Text(
          'Activity 🔔',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          // 🌟 క్లియర్ ఆల్ బటన్
          IconButton(
            icon: const Icon(
              Icons.delete_sweep_rounded,
              color: Colors.redAccent,
              size: 28,
            ),
            onPressed: _clearAllNotifications,
            tooltip: "Clear All",
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUid)
            .collection('notifications')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 60,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'No new activity.',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var notifData = doc.data();
              String notifId = doc.id;

              String senderUid = notifData['senderUid'] ?? '';
              String username = notifData['username'] ?? 'Someone';
              String profilePic = notifData['profilePic'] ?? '';
              String type = notifData['type'] ?? '';
              String text = notifData['text'] ?? '';
              String postId = notifData['postId'] ?? '';
              String postType = notifData['postType'] ?? 'post';
              String postThumbnail =
                  notifData['postPic'] ?? ''; // పోస్ట్ బొమ్మ (ఉంటే)
              var timestamp = notifData['timestamp'];
              bool isSeen = notifData['isSeen'] ?? true;

              // 🌟 స్వైప్ టు డిలీట్ కోసం Dismissible వాడాము
              return Dismissible(
                key: Key(notifId),
                direction: DismissDirection.endToStart,
                onDismissed: (direction) => _deleteSingleNotification(notifId),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Colors.redAccent,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                child: Container(
                  color: isSeen
                      ? Colors.transparent
                      : Colors.blueAccent.withValues(alpha: 0.1),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfileScreen(userId: senderUid),
                          ),
                        );
                      },
                      child: CircleAvatar(
                        radius: 24,
                        backgroundImage: profilePic.isNotEmpty
                            ? CachedNetworkImageProvider(
                                profilePic,
                              ) // 🌟 Cached
                            : const CachedNetworkImageProvider(
                                'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png',
                              ),
                      ),
                    ),
                    title: RichText(
                      text: TextSpan(
                        style: TextStyle(color: textColor, fontSize: 14),
                        children: [
                          TextSpan(
                            text: '$username ',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: text),
                        ],
                      ),
                    ),
                    subtitle: Text(
                      timestamp != null
                          ? timeago.format((timestamp as Timestamp).toDate())
                          : 'Just now',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    // 🌟 స్మార్ట్ బటన్స్ లాజిక్ ఇక్కడ ఉంది
                    trailing: _buildTrailingWidget(
                      type,
                      senderUid,
                      notifId,
                      postThumbnail,
                    ),
                    onTap: () {
                      if ((type == 'like' || type == 'comment') &&
                          postId.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PostDetailScreen(
                              postId: postId,
                              type: postType,
                            ),
                          ),
                        );
                      } else if (type == 'follow' || type == 'followed_back') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfileScreen(userId: senderUid),
                          ),
                        );
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // 🌟 టైప్ ని బట్టి పక్కన (Trailing) ఏం చూపాలో డిసైడ్ చేసే ఫంక్షన్
  Widget? _buildTrailingWidget(
    String type,
    String senderUid,
    String notifId,
    String postThumbnail,
  ) {
    if (type == 'follow') {
      return SizedBox(
        height: 30,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () => _followBack(senderUid, notifId),
          child: const Text(
            "Follow Back",
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    } else if (type == 'follow_request') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.check_circle, color: Colors.green, size: 28),
            onPressed: () => _acceptRequest(senderUid, notifId),
          ),
          IconButton(
            icon: const Icon(Icons.cancel, color: Colors.redAccent, size: 28),
            onPressed: () => _deleteSingleNotification(
              notifId,
            ), // రిజెక్ట్ అంటే డిలీట్ చేయడమే
          ),
        ],
      );
    } else if ((type == 'like' || type == 'comment') &&
        postThumbnail.isNotEmpty) {
      return SizedBox(
        width: 45,
        height: 45,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: CachedNetworkImage(
            // 🌟 Cached
            imageUrl: postThumbnail,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(color: Colors.grey[800]),
          ),
        ),
      );
    }
    return null;
  }
}

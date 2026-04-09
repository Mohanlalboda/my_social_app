// ignore_for_file: curly_braces_in_flow_control_structures, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../widgets/safe_elements.dart';
import 'chat_screen.dart';
import '../community/community_list_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  void _showFollowersToChat() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(15.0),
              child: Text(
                "Select Contact",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUid)
                    .get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  List following =
                      (snapshot.data!.data()
                          as Map<String, dynamic>)['following'] ??
                      [];

                  if (following.isEmpty) {
                    return const Center(
                      child: Text("You are not following anyone yet."),
                    );
                  }

                  return ListView.builder(
                    controller: controller,
                    itemCount: following.length,
                    itemBuilder: (context, index) {
                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(following[index])
                            .get(),
                        builder: (context, userSnap) {
                          if (!userSnap.hasData || !userSnap.data!.exists) {
                            return const SizedBox();
                          }
                          var userData =
                              userSnap.data!.data() as Map<String, dynamic>;

                          return ListTile(
                            leading: SafeProfilePic(
                              base64String: userData['profilePic'],
                              radius: 20,
                              fallbackText: userData['username'][0],
                            ),
                            title: Text(
                              userData['username'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(userData['bio'] ?? '', maxLines: 1),
                            onTap: () {
                              Navigator.pop(ctx);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    receiverId: following[index],
                                    receiverName: userData['username'],
                                    receiverPic: userData['profilePic'] ?? '',
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteChat(String chatRoomId) async {
    try {
      await FirebaseFirestore.instance
          .collection('chatRooms')
          .doc(chatRoomId)
          .set({
            'deletedBy': FieldValue.arrayUnion([currentUid]),
          }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Chat deleted from your inbox"),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint("Chat Delete Error: $e");
    }
  }

  void _showAddNoteDialog(Map<String, dynamic> myUserData) {
    TextEditingController noteController = TextEditingController();
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        title: const Text("Share a thought..."),
        content: TextField(
          controller: noteController,
          maxLength: 60, // 🌟 THE FIX: నోట్ మరీ పెద్దగా లేకుండా 60 కి మార్చాను
          decoration: InputDecoration(
            hintText: "What's on your mind?",
            hintStyle: const TextStyle(color: Colors.grey),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            onPressed: () async {
              String text = noteController.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(ctx);
                await FirebaseFirestore.instance
                    .collection('notes')
                    .doc(currentUid)
                    .set({
                      'uid': currentUid,
                      'text': text,
                      'username': myUserData['username'] ?? 'User',
                      'profilePic': myUserData['profilePic'] ?? '',
                      'timestamp': FieldValue.serverTimestamp(),
                    });
              }
            },
            child: const Text("Share", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection(List myFollowing, Map<String, dynamic> myUserData) {
    DateTime yesterday = DateTime.now().subtract(const Duration(hours: 24));
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notes')
          .where('timestamp', isGreaterThanOrEqualTo: yesterday)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SizedBox(
            height: 130,
            child: Center(
              child: Text(
                "Unable to load notes",
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 130,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        var allNotes = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          return myFollowing.contains(data['uid']) || data['uid'] == currentUid;
        }).toList();

        allNotes.sort((a, b) {
          Timestamp? t1 = (a.data() as Map)['timestamp'] as Timestamp?;
          Timestamp? t2 = (b.data() as Map)['timestamp'] as Timestamp?;
          if (t1 == null || t2 == null) return 0;
          return t2.compareTo(t1);
        });

        bool hasMyNote = allNotes.any(
          (doc) => (doc.data() as Map)['uid'] == currentUid,
        );
        Map<String, dynamic>? myNoteData;
        if (hasMyNote) {
          myNoteData =
              allNotes
                      .firstWhere(
                        (doc) => (doc.data() as Map)['uid'] == currentUid,
                      )
                      .data()
                  as Map<String, dynamic>;
          allNotes.removeWhere(
            (doc) => (doc.data() as Map)['uid'] == currentUid,
          );
        }

        String myNoteText = hasMyNote ? myNoteData!['text'] : "Note...";

        return Container(
          height: 145, // 🌟 THE FIX: పర్ఫెక్ట్ హైట్
          padding: const EdgeInsets.only(top: 15, bottom: 5),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            children: [
              // ------------------- 1. My Note -------------------
              GestureDetector(
                onTap: () => _showAddNoteDialog(myUserData),
                child: Container(
                  width:
                      80, // 🌟 THE FIX: ఫిక్స్‌డ్ విడ్త్ వల్ల బబుల్స్ ఓవర్‌లాప్ అవ్వవు
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  child: Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.topCenter,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                              top: 18,
                            ), // బబుల్ కి ప్లేస్ ఇచ్చాం
                            child: SafeProfilePic(
                              base64String: myUserData['profilePic'] ?? '',
                              radius: 32,
                              fallbackText:
                                  (myUserData['username'] != null &&
                                      myUserData['username']
                                          .toString()
                                          .isNotEmpty)
                                  ? myUserData['username'][0].toUpperCase()
                                  : 'U',
                            ),
                          ),
                          Positioned(
                            top: 0,
                            child: Container(
                              constraints: const BoxConstraints(
                                maxWidth: 80,
                                maxHeight: 40,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.grey[800] : Colors.white,
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              // 🌟 THE FIX: Marquee తీసేసి నార్మల్ Text వాడాం, క్లీన్ గా కనిపిస్తుంది
                              child: Text(
                                myNoteText,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1.2,
                                  fontWeight: hasMyNote
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: hasMyNote
                                      ? (isDark ? Colors.white : Colors.black)
                                      : Colors.grey,
                                ),
                              ),
                            ),
                          ),
                          if (!hasMyNote)
                            Positioned(
                              bottom: 0,
                              right: 2,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark ? Colors.black : Colors.white,
                                    width: 2,
                                  ),
                                ),
                                padding: const EdgeInsets.all(2),
                                child: const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Your note",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ------------------- 2. Friends' Notes -------------------
              ...allNotes.map((doc) {
                var noteData = doc.data() as Map<String, dynamic>;
                String friendId = noteData['uid'];
                String friendName = noteData['username'] ?? 'User';
                String friendNoteText = noteData['text'];

                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(friendId)
                      .get(),
                  builder: (context, userSnap) {
                    bool isOnline = false;
                    if (userSnap.hasData && userSnap.data!.exists) {
                      isOnline =
                          (userSnap.data!.data()
                              as Map<String, dynamic>)['isOnline'] ??
                          false;
                    }

                    return Container(
                      width: 80, // 🌟 THE FIX: ఇక్కడ కూడా ఫిక్స్‌డ్ విడ్త్
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      child: Column(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.topCenter,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 18),
                                child: SafeProfilePic(
                                  base64String: noteData['profilePic'] ?? '',
                                  radius: 32,
                                  fallbackText: friendName.isNotEmpty
                                      ? friendName[0].toUpperCase()
                                      : 'U',
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 2,
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: isOnline ? Colors.green : Colors.red,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.black
                                          : Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 0,
                                child: Container(
                                  constraints: const BoxConstraints(
                                    maxWidth: 80,
                                    maxHeight: 40,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.grey[800]
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(15),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.1,
                                        ),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  // 🌟 THE FIX: ఇక్కడ కూడా Marquee తీసేసి నార్మల్ Text వాడాం
                                  child: Text(
                                    friendNoteText,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      height: 1.2,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            friendName,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: isDark ? Colors.black : Colors.white,
        appBar: AppBar(
          backgroundColor: isDark ? Colors.black : Colors.white,
          elevation: 0,
          title: Text(
            "Inbox",
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          bottom: const TabBar(
            indicatorColor: Color(0xFFFD1D1D),
            labelColor: Color(0xFFFD1D1D),
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: "Chats"),
              Tab(text: "Communities"),
              Tab(text: "Calls"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // 🌟 1. CHATS TAB
            Scaffold(
              backgroundColor: isDark ? Colors.black : Colors.white,
              floatingActionButton: FloatingActionButton(
                onPressed: _showFollowersToChat,
                backgroundColor: const Color(0xFFFD1D1D),
                child: const Icon(Icons.message, color: Colors.white),
              ),
              body: FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUid)
                    .get(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData)
                    return const Center(child: CircularProgressIndicator());
                  var myData =
                      userSnap.data!.data() as Map<String, dynamic>? ?? {};
                  List myFollowing = List.from(myData['following'] ?? []);

                  return RefreshIndicator(
                    color: const Color(0xFFFD1D1D),
                    onRefresh: () async {
                      setState(() {});
                      await Future.delayed(const Duration(seconds: 1));
                    },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      children: [
                        _buildNotesSection(myFollowing, myData),
                        const Divider(height: 1),

                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('chatRooms')
                              .where('users', arrayContains: currentUid)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return const SizedBox(
                                height: 300,
                                child: Center(
                                  child: Text("Error loading chats"),
                                ),
                              );
                            }
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const SizedBox(
                                height: 300,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }

                            var visibleChatRooms = snapshot.data!.docs.where((
                              room,
                            ) {
                              var roomData =
                                  room.data() as Map<String, dynamic>;
                              List deletedBy = roomData['deletedBy'] ?? [];
                              return !deletedBy.contains(currentUid);
                            }).toList();

                            if (visibleChatRooms.isEmpty) {
                              return const SizedBox(
                                height: 300,
                                child: Center(
                                  child: Text(
                                    "No chats yet. Start a conversation! 💬",
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              );
                            }

                            visibleChatRooms.sort((a, b) {
                              var aData = a.data() as Map<String, dynamic>;
                              var bData = b.data() as Map<String, dynamic>;
                              Timestamp? t1 = aData['timestamp'] as Timestamp?;
                              Timestamp? t2 = bData['timestamp'] as Timestamp?;
                              if (t1 == null && t2 == null) return 0;
                              if (t1 == null) return 1;
                              if (t2 == null) return -1;
                              return t2.compareTo(t1);
                            });

                            return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: visibleChatRooms.length,
                              itemBuilder: (context, index) {
                                var roomData =
                                    visibleChatRooms[index].data()
                                        as Map<String, dynamic>;
                                String roomId = visibleChatRooms[index].id;
                                List users = roomData['users'];
                                String otherUserId = users.firstWhere(
                                  (id) => id != currentUid,
                                  orElse: () => "",
                                );
                                if (otherUserId.isEmpty)
                                  return const SizedBox();

                                int unreadCount =
                                    roomData['unread_$currentUid'] ?? 0;
                                bool hasUnread = unreadCount > 0;
                                DateTime time =
                                    (roomData['timestamp'] as Timestamp?)
                                        ?.toDate() ??
                                    DateTime.now();

                                return Dismissible(
                                  key: Key(roomId),
                                  direction: DismissDirection.endToStart,
                                  onDismissed: (direction) =>
                                      _deleteChat(roomId),
                                  background: Container(
                                    color: Colors.red,
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                    child: const Icon(
                                      Icons.delete,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ),
                                  child: FutureBuilder<DocumentSnapshot>(
                                    future: FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(otherUserId)
                                        .get(),
                                    builder: (context, userSnap) {
                                      if (userSnap.connectionState ==
                                          ConnectionState.waiting) {
                                        return const ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor: Colors.grey,
                                            radius: 25,
                                          ),
                                        );
                                      }
                                      if (!userSnap.hasData ||
                                          !userSnap.data!.exists)
                                        return const SizedBox();

                                      var userData =
                                          userSnap.data!.data()
                                              as Map<String, dynamic>? ??
                                          {};
                                      String name =
                                          userData['username'] ?? 'User';
                                      String pic = userData['profilePic'] ?? '';
                                      bool isOnline =
                                          userData['isOnline'] ?? false;

                                      return ListTile(
                                        leading: Stack(
                                          children: [
                                            SafeProfilePic(
                                              base64String: pic,
                                              radius: 25,
                                              fallbackText: name.isNotEmpty
                                                  ? name[0].toUpperCase()
                                                  : 'U',
                                            ),
                                            Positioned(
                                              bottom: 0,
                                              right: 0,
                                              child: Container(
                                                width: 14,
                                                height: 14,
                                                decoration: BoxDecoration(
                                                  color: isOnline
                                                      ? Colors.green
                                                      : Colors.red,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: isDark
                                                        ? Colors.black
                                                        : Colors.white,
                                                    width: 2,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        title: Text(
                                          name,
                                          style: TextStyle(
                                            fontWeight: hasUnread
                                                ? FontWeight.bold
                                                : FontWeight.w600,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                          ),
                                        ),
                                        subtitle:
                                            roomData['typing_$otherUserId'] ==
                                                true
                                            ? const Text(
                                                "typing...",
                                                maxLines: 1,
                                                style: TextStyle(
                                                  color: Colors.green,
                                                  fontStyle: FontStyle.italic,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              )
                                            : null,
                                        trailing: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              timeago.format(
                                                time,
                                                locale: 'en_short',
                                              ),
                                              style: TextStyle(
                                                color: hasUnread
                                                    ? Colors.blue
                                                    : Colors.grey,
                                                fontSize: 12,
                                                fontWeight: hasUnread
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            if (hasUnread)
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  5,
                                                ),
                                                decoration: const BoxDecoration(
                                                  color: Colors.red,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Text(
                                                  unreadCount > 9
                                                      ? "9+"
                                                      : unreadCount.toString(),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        onTap: () {
                                          FirebaseFirestore.instance
                                              .collection('chatRooms')
                                              .doc(roomId)
                                              .update({
                                                'unread_$currentUid': 0,
                                              });
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => ChatScreen(
                                                receiverId: otherUserId,
                                                receiverName: name,
                                                receiverPic: pic,
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // 🌟 2. COMMUNITIES TAB
            const CommunityListScreen(),

            // 🌟 3. CALLS TAB
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.call, size: 80, color: Colors.grey),
                  SizedBox(height: 10),
                  Text(
                    "Audio & Video Calls Coming Soon!",
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

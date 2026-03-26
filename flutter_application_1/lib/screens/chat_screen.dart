// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cached_video_player_plus/cached_video_player_plus.dart';
import 'package:video_player/video_player.dart';

import '../services/fcm_sender_service.dart'; // 🌟 నోటిఫికేషన్ సర్వీస్
import '../widgets/safe_elements.dart';

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  final String receiverPic;

  const ChatScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
    required this.receiverPic,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  late String roomId;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    roomId = currentUid.hashCode <= widget.receiverId.hashCode
        ? "${currentUid}_${widget.receiverId}"
        : "${widget.receiverId}_$currentUid";
  }

  // 🌟 టెక్స్ట్ మెసేజ్ పంపడం + నోటిఫికేషన్
  void _sendMessage() async {
    if (_msgController.text.trim().isEmpty) return;
    String msg = _msgController.text.trim();
    _msgController.clear();

    FirebaseFirestore.instance.collection('chatRooms').doc(roomId).set({
      'typing_$currentUid': false,
    }, SetOptions(merge: true));

    var timestamp = FieldValue.serverTimestamp();

    await FirebaseFirestore.instance
        .collection('chatRooms')
        .doc(roomId)
        .collection('messages')
        .add({
          'senderId': currentUid,
          'receiverId': widget.receiverId,
          'text': msg,
          'type': 'text',
          'isRead': false,
          'timestamp': timestamp,
        });

    await FirebaseFirestore.instance.collection('chatRooms').doc(roomId).set({
      'users': [currentUid, widget.receiverId],
      'lastMessage': msg,
      'timestamp': timestamp,
      'unread_${widget.receiverId}': FieldValue.increment(1),
    }, SetOptions(merge: true));

    // 🔔 నోటిఫికేషన్ పంపడం
    _sendPushNotification(msg);
  }

  // 🌟 మీడియా (Photo/Video) అప్‌లోడ్ లాజిక్ + నోటిఫికేషన్
  Future<void> _uploadFileLogic(File file, String type) async {
    try {
      String ext = type == 'video' ? 'mp4' : 'jpg';
      String fileName = "${DateTime.now().millisecondsSinceEpoch}.$ext";
      Reference ref = FirebaseStorage.instance.ref().child(
        'chat_media/$roomId/$fileName',
      );

      UploadTask uploadTask = ref.putFile(file);
      TaskSnapshot snap = await uploadTask;
      String fileUrl = await snap.ref.getDownloadURL();

      var timestamp = FieldValue.serverTimestamp();
      String msgText = type == 'image' ? '📷 Photo' : '🎥 Video';

      await FirebaseFirestore.instance
          .collection('chatRooms')
          .doc(roomId)
          .collection('messages')
          .add({
            'senderId': currentUid,
            'receiverId': widget.receiverId,
            'text': msgText,
            'mediaUrl': fileUrl,
            'type': type,
            'isRead': false,
            'timestamp': timestamp,
          });

      await FirebaseFirestore.instance.collection('chatRooms').doc(roomId).set({
        'users': [currentUid, widget.receiverId],
        'lastMessage': msgText,
        'timestamp': timestamp,
        'unread_${widget.receiverId}': FieldValue.increment(1),
      }, SetOptions(merge: true));

      // 🔔 మీడియా నోటిఫికేషన్ పంపడం
      _sendPushNotification(msgText);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed: $e")));
    }
  }

  // 🌟 పుష్ నోటిఫికేషన్ సెండ్ చేసే కామన్ ఫంక్షన్
  void _sendPushNotification(String content) async {
    try {
      var senderSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .get();
      String senderName =
          (senderSnap.data() as Map<String, dynamic>)['username'] ?? 'Someone';

      await FcmSenderService.sendNotification(
        receiverId: widget.receiverId,
        title: senderName,
        body: content,
      );
    } catch (e) {
      debugPrint("Notification Error: $e");
    }
  }

  // --- మిగతా పికింగ్ లాజిక్ (మార్పు లేదు) ---

  Future<void> _pickSingleMedia(ImageSource source, bool isVideo) async {
    final picker = ImagePicker();
    try {
      XFile? file = isVideo
          ? await picker.pickVideo(source: source)
          : await picker.pickImage(source: source, imageQuality: 70);

      if (file != null) {
        setState(() => _isUploading = true);
        await _uploadFileLogic(File(file.path), isVideo ? 'video' : 'image');
        if (mounted) setState(() => _isUploading = false);
      }
    } catch (e) {
      debugPrint("Error picking media: $e");
    }
  }

  Future<void> _pickMultipleImages() async {
    final picker = ImagePicker();
    try {
      final List<XFile> files = await picker.pickMultiImage(imageQuality: 70);
      if (files.isNotEmpty) {
        setState(() => _isUploading = true);
        for (var file in files) {
          await _uploadFileLogic(File(file.path), 'image');
        }
        if (mounted) setState(() => _isUploading = false);
      }
    } catch (e) {
      debugPrint("Error picking multiple images: $e");
    }
  }

  void _showAttachmentOptions() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Wrap(
          children: [
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.purple,
                child: Icon(Icons.photo_library, color: Colors.white),
              ),
              title: Text(
                "Gallery Photos",
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickMultipleImages();
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.pink,
                child: Icon(Icons.videocam, color: Colors.white),
              ),
              title: Text(
                "Gallery Video",
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickSingleMedia(ImageSource.gallery, true);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _onTyping(String val) {
    FirebaseFirestore.instance.collection('chatRooms').doc(roomId).set({
      'typing_$currentUid': val.isNotEmpty,
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[200],
      appBar: AppBar(
        backgroundColor: isDark ? Colors.grey[900] : const Color(0xFF007AFF),
        elevation: 1,
        titleSpacing: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            SafeProfilePic(
              base64String: widget.receiverPic,
              radius: 18,
              fallbackText: widget.receiverName.isNotEmpty
                  ? widget.receiverName[0]
                  : 'U',
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.receiverName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('chatRooms')
                      .doc(roomId)
                      .snapshots(),
                  builder: (context, roomSnap) {
                    bool isTyping = false;
                    if (roomSnap.hasData && roomSnap.data!.exists) {
                      isTyping =
                          (roomSnap.data!.data()
                              as Map<
                                String,
                                dynamic
                              >)['typing_${widget.receiverId}'] ??
                          false;
                    }
                    if (isTyping)
                      return const Text(
                        "typing...",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      );

                    return StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(widget.receiverId)
                          .snapshots(),
                      builder: (context, userSnap) {
                        bool isOnline = false;
                        if (userSnap.hasData && userSnap.data!.exists)
                          isOnline =
                              (userSnap.data!.data()
                                  as Map<String, dynamic>)['isOnline'] ??
                              false;
                        return Text(
                          isOnline ? "Active now" : "Offline",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chatRooms')
                  .doc(roomId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                  return const Center(
                    child: Text(
                      "Say hi! 👋",
                      style: TextStyle(color: Colors.grey),
                    ),
                  );

                var messages = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var msgData =
                        messages[index].data() as Map<String, dynamic>;
                    bool isMe = msgData['senderId'] == currentUid;
                    bool isRead = msgData['isRead'] ?? false;
                    String msgType = msgData['type'] ?? 'text';
                    DateTime time =
                        (msgData['timestamp'] as Timestamp?)?.toDate() ??
                        DateTime.now();
                    String timeStr = DateFormat('hh:mm a').format(time);

                    if (!isMe && !isRead) {
                      FirebaseFirestore.instance
                          .collection('chatRooms')
                          .doc(roomId)
                          .collection('messages')
                          .doc(messages[index].id)
                          .update({'isRead': true});
                    }

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: msgType == 'text'
                              ? (isMe
                                    ? const Color(0xFFE1FFC7)
                                    : (isDark
                                          ? Colors.grey[800]
                                          : Colors.white))
                              : Colors.transparent,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: isMe
                                ? const Radius.circular(16)
                                : const Radius.circular(0),
                            bottomRight: isMe
                                ? const Radius.circular(0)
                                : const Radius.circular(16),
                          ),
                          boxShadow: [
                            if (!isDark && msgType == 'text')
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 2,
                              ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: isMe
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            if (msgType == 'text')
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                child: Text(
                                  msgData['text'],
                                  style: TextStyle(
                                    color: isMe
                                        ? Colors.black87
                                        : (isDark
                                              ? Colors.white
                                              : Colors.black),
                                    fontSize: 15,
                                  ),
                                ),
                              ),

                            if (msgType == 'image')
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FullScreenImageViewer(
                                      imageUrl: msgData['mediaUrl'] ?? '',
                                    ),
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: CachedNetworkImage(
                                    imageUrl: msgData['mediaUrl'] ?? '',
                                    width:
                                        MediaQuery.of(context).size.width * 0.6,
                                    fit: BoxFit.cover,
                                    placeholder: (c, u) => Container(
                                      width: 200,
                                      height: 200,
                                      color: Colors.grey[300],
                                      child: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                            if (msgType == 'video')
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FullScreenVideoViewer(
                                      videoUrl: msgData['mediaUrl'] ?? '',
                                    ),
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Container(
                                        width:
                                            MediaQuery.of(context).size.width *
                                            0.6,
                                        height: 250,
                                        color: Colors.black87,
                                      ),
                                      const Icon(
                                        Icons.play_circle_fill,
                                        color: Colors.white,
                                        size: 50,
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            const SizedBox(height: 3),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: msgType == 'text' ? 10 : 4,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    timeStr,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 10,
                                    ),
                                  ),
                                  if (isMe) const SizedBox(width: 4),
                                  if (isMe)
                                    Icon(
                                      Icons.done_all,
                                      size: 14,
                                      color: isRead ? Colors.blue : Colors.grey,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          if (_isUploading)
            const LinearProgressIndicator(color: Color(0xFF007AFF)),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            color: isDark ? Colors.grey[900] : Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    onChanged: _onTyping,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      hintText: "Message...",
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: isDark ? Colors.black : Colors.grey[200],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      prefixIcon: IconButton(
                        icon: const Icon(
                          Icons.emoji_emotions_outlined,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Stickers feature coming soon! 🚀"),
                            ),
                          );
                        },
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.attach_file,
                              color: Colors.grey,
                            ),
                            onPressed: _showAttachmentOptions,
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.camera_alt,
                              color: Colors.grey,
                            ),
                            onPressed: () =>
                                _pickSingleMedia(ImageSource.camera, false),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFF007AFF),
                  radius: 22,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// FullScreenImageViewer & FullScreenVideoViewer క్లాసులు కూడా ఇక్కడే ఉంచండి... (గతంలో ఇచ్చినట్లే)
class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  const FullScreenImageViewer({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            placeholder: (context, url) =>
                const CircularProgressIndicator(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class FullScreenVideoViewer extends StatefulWidget {
  final String videoUrl;
  const FullScreenVideoViewer({super.key, required this.videoUrl});
  @override
  State<FullScreenVideoViewer> createState() => _FullScreenVideoViewerState();
}

class _FullScreenVideoViewerState extends State<FullScreenVideoViewer> {
  late CachedVideoPlayerPlus _player;
  bool _isInitialized = false;
  @override
  void initState() {
    super.initState();
    _player = CachedVideoPlayerPlus.networkUrl(Uri.parse(widget.videoUrl));
    _player.initialize().then((_) {
      if (mounted) {
        setState(() => _isInitialized = true);
        _player.controller.play();
        _player.controller.setLooping(true);
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: _isInitialized
            ? AspectRatio(
                aspectRatio: _player.controller.value.aspectRatio,
                child: VideoPlayer(_player.controller),
              )
            : const CircularProgressIndicator(color: Colors.white),
      ),
      floatingActionButton: _isInitialized
          ? FloatingActionButton(
              backgroundColor: Colors.white.withValues(alpha: 0.5),
              onPressed: () {
                setState(() {
                  _player.controller.value.isPlaying
                      ? _player.controller.pause()
                      : _player.controller.play();
                });
              },
              child: Icon(
                _player.controller.value.isPlaying
                    ? Icons.pause
                    : Icons.play_arrow,
                color: Colors.black,
              ),
            )
          : null,
    );
  }
}

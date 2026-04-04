// ignore_for_file: curly_braces_in_flow_control_structures, use_build_context_synchronously

import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';

import '../../services/fcm_sender_service.dart';
import '../../widgets/safe_elements.dart';
import '../posts/scrolling_posts_screen.dart';
import '../reels/scrolling_reels_screen.dart';
import '../../widgets/audio_message_widget.dart';
import '../common/full_screen_media.dart';

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

  final ValueNotifier<bool> _isTypingNotifier = ValueNotifier(false);
  Timer? _typingTimer;

  bool _isUploading = false;
  bool _isVanishMode = false;

  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;

  bool _isReceiverPrivate = false;
  bool _amIFollowingReceiver = false;
  bool _isLoadingStatus = true;

  final LinearGradient brandGradient = const LinearGradient(
    colors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFF56040)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    roomId = currentUid.hashCode <= widget.receiverId.hashCode
        ? "${currentUid}_${widget.receiverId}"
        : "${widget.receiverId}_$currentUid";
    _checkPrivacyStatus();
    _listenToVanishMode();
    _clearUnreadStatus();
  }

  void _clearUnreadStatus() async {
    try {
      var snap = await FirebaseFirestore.instance
          .collection('chatRooms')
          .doc(roomId)
          .collection('messages')
          .where('receiverId', isEqualTo: currentUid)
          .where('isRead', isEqualTo: false)
          .get();

      if (snap.docs.isNotEmpty) {
        WriteBatch batch = FirebaseFirestore.instance.batch();
        for (var doc in snap.docs) {
          batch.update(doc.reference, {'isRead': true});
        }
        batch.update(
          FirebaseFirestore.instance.collection('chatRooms').doc(roomId),
          {'unread_$currentUid': 0},
        );
        await batch.commit();
      }
    } catch (e) {
      debugPrint("Unread clear error: $e");
    }
  }

  void _listenToVanishMode() {
    FirebaseFirestore.instance
        .collection('chatRooms')
        .doc(roomId)
        .snapshots()
        .listen((snap) {
          if (snap.exists && mounted) {
            setState(
              () => _isVanishMode = snap.data()?['isVanishMode'] ?? false,
            );
          }
        });
  }

  void _toggleVanishMode() async {
    bool nextState = !_isVanishMode;
    await FirebaseFirestore.instance.collection('chatRooms').doc(roomId).set({
      'isVanishMode': nextState,
    }, SetOptions(merge: true));
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _msgController.dispose();
    _typingTimer?.cancel();
    _isTypingNotifier.dispose();
    super.dispose();
  }

  void _onTyping(String val) {
    bool hasText = val.trim().isNotEmpty;
    if (_isTypingNotifier.value != hasText) {
      _isTypingNotifier.value = hasText;
      FirebaseFirestore.instance.collection('chatRooms').doc(roomId).set({
        'typing_$currentUid': hasText,
      }, SetOptions(merge: true));
    }

    if (_typingTimer?.isActive ?? false) _typingTimer!.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        FirebaseFirestore.instance.collection('chatRooms').doc(roomId).set({
          'typing_$currentUid': false,
        }, SetOptions(merge: true));
      }
    });
  }

  Future<void> _checkPrivacyStatus() async {
    try {
      var receiverDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.receiverId)
          .get();
      if (receiverDoc.exists) {
        var data = receiverDoc.data() as Map<String, dynamic>;
        setState(() {
          _isReceiverPrivate = data['isPrivate'] ?? false;
          _amIFollowingReceiver = (data['followers'] ?? []).contains(
            currentUid,
          );
          _isLoadingStatus = false;
        });
        if (_isReceiverPrivate && !_amIFollowingReceiver)
          _sendFriendRequestIfNoPrior();
      }
    } catch (e) {
      debugPrint("Privacy check failed: $e");
    }
  }

  Future<void> _sendFriendRequestIfNoPrior() async {
    try {
      var existingRequests = await FirebaseFirestore.instance
          .collection('chatRooms')
          .doc(roomId)
          .collection('messages')
          .where('type', isEqualTo: 'friend_request')
          .where('senderId', isEqualTo: currentUid)
          .get();
      if (existingRequests.docs.isEmpty) {
        await FirebaseFirestore.instance
            .collection('chatRooms')
            .doc(roomId)
            .collection('messages')
            .add({
              'senderId': currentUid,
              'receiverId': widget.receiverId,
              'text': "Please accept me as a friend",
              'type': 'friend_request',
              'status': 'pending',
              'isRead': false,
              'timestamp': FieldValue.serverTimestamp(),
            });
      }
    } catch (e) {
      debugPrint("Friend request check failed: $e");
    }
  }

  void _sendMessage() async {
    if (_msgController.text.trim().isEmpty) return;
    String msg = _msgController.text.trim();
    _msgController.clear();

    _isTypingNotifier.value = false;

    var timestamp = FieldValue.serverTimestamp();
    FirebaseFirestore.instance.collection('chatRooms').doc(roomId).set({
      'typing_$currentUid': false,
    }, SetOptions(merge: true));

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
          'isVanish': _isVanishMode,
          'timestamp': timestamp,
          'isEdited': false,
          'isDeleted': false,
          'deletedBy': [],
        });

    await FirebaseFirestore.instance.collection('chatRooms').doc(roomId).set({
      'users': [currentUid, widget.receiverId],
      'lastMessage': _isVanishMode ? "🤫 Secret Message" : msg,
      'timestamp': timestamp,
      'unread_${widget.receiverId}': FieldValue.increment(1),
      'deletedBy': [],
    }, SetOptions(merge: true));

    _sendPushNotification(_isVanishMode ? "🤫 Sent a secret message" : msg);
  }

  void _reactToMessage(String msgId, String emoji) async {
    await FirebaseFirestore.instance
        .collection('chatRooms')
        .doc(roomId)
        .collection('messages')
        .doc(msgId)
        .update({'reaction': emoji});
  }

  Future<void> _uploadFileLogic(File file, String type) async {
    try {
      setState(() => _isUploading = true);
      File fileToUpload = file;
      if (type == 'image') {
        final tempDir = await getTemporaryDirectory();
        final outPath =
            "${tempDir.path}/comp_${DateTime.now().millisecondsSinceEpoch}.jpg";
        var comp = await FlutterImageCompress.compressAndGetFile(
          file.path,
          outPath,
          quality: 60,
          minWidth: 1080,
          minHeight: 1080,
        );
        if (comp != null) fileToUpload = File(comp.path);
      } else if (type == 'video') {
        MediaInfo? mediaInfo = await VideoCompress.compressVideo(
          file.path,
          quality: VideoQuality.MediumQuality,
          includeAudio: true,
        );
        if (mediaInfo != null && mediaInfo.file != null)
          fileToUpload = mediaInfo.file!;
      }

      String ext = type == 'video' ? 'mp4' : (type == 'audio' ? 'm4a' : 'jpg');
      Reference ref = FirebaseStorage.instance.ref().child(
        'chat_media/$roomId/${DateTime.now().millisecondsSinceEpoch}.$ext',
      );
      UploadTask uploadTask = ref.putFile(fileToUpload);
      String fileUrl = await (await uploadTask).ref.getDownloadURL();

      var timestamp = FieldValue.serverTimestamp();
      String msgText = type == 'image'
          ? '📷 Photo'
          : (type == 'video' ? '🎥 Video' : '🎤 Voice Message');

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
            'isVanish': _isVanishMode,
            'timestamp': timestamp,
            'isDeleted': false,
            'deletedBy': [],
          });

      await FirebaseFirestore.instance.collection('chatRooms').doc(roomId).set({
        'users': [currentUid, widget.receiverId],
        'lastMessage': _isVanishMode ? "🤫 Secret Media" : msgText,
        'timestamp': timestamp,
        'unread_${widget.receiverId}': FieldValue.increment(1),
        'deletedBy': [],
      }, SetOptions(merge: true));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed: $e")));
    } finally {
      if (mounted) setState(() => _isUploading = false);
      if (type == 'video') VideoCompress.deleteAllCache();
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        String path =
            '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );
        setState(() => _isRecording = true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Microphone permission required!")),
        );
      }
    } catch (e) {
      debugPrint("Recording error: $e");
    }
  }

  Future<void> _stopRecordingAndSend() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
      if (path != null) {
        await _uploadFileLogic(File(path), 'audio');
      }
    } catch (e) {
      debugPrint("Stop recording error: $e");
      setState(() => _isRecording = false);
    }
  }

  void _sendPushNotification(String content) async {
    try {
      var senderSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .get();
      String senderName = senderSnap.data()?['username'] ?? 'Someone';
      await FcmSenderService.sendNotification(
        receiverId: widget.receiverId,
        title: senderName,
        body: content,
      );
    } catch (e) {
      debugPrint("Push Notification error: $e");
    }
  }

  Future<void> _pickSingleMedia(ImageSource source, bool isVideo) async {
    final picker = ImagePicker();
    XFile? file = isVideo
        ? await picker.pickVideo(source: source)
        : await picker.pickImage(source: source, imageQuality: 70);
    if (file != null) {
      await _uploadFileLogic(File(file.path), isVideo ? 'video' : 'image');
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
              title: const Text("Photos"),
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
              title: const Text("Video"),
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

  Future<void> _pickMultipleImages() async {
    final picker = ImagePicker();
    final List<XFile> files = await picker.pickMultiImage(imageQuality: 70);
    if (files.isNotEmpty) {
      for (var file in files) await _uploadFileLogic(File(file.path), 'image');
    }
  }

  void _showMessageOptions(
    String msgId,
    String currentText,
    bool isTextMsg,
    bool isMe,
  ) {
    const List<String> emojis = ['❤️', '😂', '😮', '😢', '🙏', '👍'];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: emojis
                    .map(
                      (emoji) => GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          _reactToMessage(msgId, emoji);
                        },
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const Divider(height: 1),
            if (isTextMsg && isMe)
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text("Edit Message"),
                onTap: () {
                  Navigator.pop(ctx);
                  _editMessage(msgId, currentText);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.orange),
              title: const Text("Delete for me"),
              onTap: () {
                Navigator.pop(ctx);
                _deleteMessageForMe(msgId);
              },
            ),
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  "Delete for everyone",
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteMessageForEveryone(msgId);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _editMessage(String msgId, String currentText) {
    TextEditingController editCtrl = TextEditingController(text: currentText);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Message"),
        content: TextField(controller: editCtrl, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              String nt = editCtrl.text.trim();
              if (nt.isNotEmpty && nt != currentText) {
                await FirebaseFirestore.instance
                    .collection('chatRooms')
                    .doc(roomId)
                    .collection('messages')
                    .doc(msgId)
                    .update({'text': nt, 'isEdited': true});
              }
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _deleteMessageForMe(String msgId) async {
    await FirebaseFirestore.instance
        .collection('chatRooms')
        .doc(roomId)
        .collection('messages')
        .doc(msgId)
        .update({
          'deletedBy': FieldValue.arrayUnion([currentUid]),
        });
  }

  void _deleteMessageForEveryone(String msgId) async {
    await FirebaseFirestore.instance
        .collection('chatRooms')
        .doc(roomId)
        .collection('messages')
        .doc(msgId)
        .update({
          'text': "🚫 This message was deleted",
          'isDeleted': true,
          'mediaUrl': FieldValue.delete(),
          'type': 'text',
        });
  }

  void _clearChat() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Clear Chat?"),
        content: const Text(
          "This will delete all messages for you. The other person can still see them.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Clear All", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        var messages = await FirebaseFirestore.instance
            .collection('chatRooms')
            .doc(roomId)
            .collection('messages')
            .get();
        WriteBatch batch = FirebaseFirestore.instance.batch();
        for (var doc in messages.docs) {
          batch.update(doc.reference, {
            'deletedBy': FieldValue.arrayUnion([currentUid]),
          });
        }
        await batch.commit();

        await FirebaseFirestore.instance
            .collection('chatRooms')
            .doc(roomId)
            .update({'lastMessage': "Chat cleared"});
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Chat cleared!")));
      } catch (e) {
        debugPrint("Clear chat failed: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    bool isRestricted =
        !_isLoadingStatus && _isReceiverPrivate && !_amIFollowingReceiver;
    Color scaffoldColor = _isVanishMode
        ? const Color(0xFF0F0C29)
        : (isDark ? Colors.black : Colors.grey[200]!);

    return Scaffold(
      backgroundColor: scaffoldColor,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: _isVanishMode ? null : brandGradient,
            color: _isVanishMode ? Colors.black : null,
          ),
        ),
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
                        bool isOnline =
                            (userSnap.hasData && userSnap.data!.exists)
                            ? ((userSnap.data!.data()
                                      as Map<String, dynamic>)['isOnline'] ??
                                  false)
                            : false;
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
        actions: [
          IconButton(
            icon: Icon(
              _isVanishMode ? Icons.auto_fix_normal : Icons.auto_fix_high,
              color: _isVanishMode ? Colors.purpleAccent : Colors.white,
            ),
            onPressed: _toggleVanishMode,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (val) {
              if (val == 'clear') _clearChat();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'clear',
                child: Text("Clear All Chat"),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isVanishMode)
            Container(
              padding: const EdgeInsets.all(5),
              color: Colors.purple.withValues(alpha: 0.2),
              width: double.infinity,
              child: const Text(
                "🤫 Vanish mode is on.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ),
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

                if (snapshot.hasData) {
                  var unreadCount = snapshot.data!.docs
                      .where(
                        (d) =>
                            d['receiverId'] == currentUid &&
                            d['isRead'] == false,
                      )
                      .length;
                  if (unreadCount > 0)
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _clearUnreadStatus(),
                    );
                }

                var messages =
                    snapshot.data?.docs.where((doc) {
                      return !((doc.data() as Map)['deletedBy'] ?? []).contains(
                        currentUid,
                      );
                    }).toList() ??
                    [];

                if (messages.isEmpty)
                  return const Center(
                    child: Text(
                      "Say hi! 👋",
                      style: TextStyle(color: Colors.grey),
                    ),
                  );

                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var msgData =
                        messages[index].data() as Map<String, dynamic>;
                    String msgId = messages[index].id;
                    bool isMe = msgData['senderId'] == currentUid;
                    bool isRead = msgData['isRead'] ?? false;
                    String msgType = msgData['type'] ?? 'text';
                    bool isVanishMsg = msgData['isVanish'] ?? false;
                    String reaction = msgData['reaction'] ?? '';
                    String timeStr = msgData['timestamp'] != null
                        ? DateFormat(
                            'hh:mm a',
                          ).format((msgData['timestamp'] as Timestamp).toDate())
                        : "...";

                    if (isRead && isVanishMsg) {
                      Future.delayed(const Duration(seconds: 5), () {
                        FirebaseFirestore.instance
                            .collection('chatRooms')
                            .doc(roomId)
                            .collection('messages')
                            .doc(msgId)
                            .delete();
                      });
                    }

                    if (msgType == 'friend_request') {
                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[850] : Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Column(
                          children: [
                            Icon(
                              Icons.lock_person,
                              size: 40,
                              color: Colors.blueGrey,
                            ),
                            SizedBox(height: 10),
                            Text(
                              "Follow request",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      );
                    }

                    if (msgType == 'shared_reel' || msgType == 'shared_post') {
                      return GestureDetector(
                        onLongPress: () =>
                            _showMessageOptions(msgId, "", false, isMe),
                        onTap: () {
                          if (msgType == 'shared_reel')
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ScrollingReelsScreen(
                                  reelIds: [msgData['sharedPostId']],
                                  initialIndex: 0,
                                ),
                              ),
                            );
                          else
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ScrollingPostsScreen(
                                  postIds: [msgData['sharedPostId']],
                                  initialIndex: 0,
                                ),
                              ),
                            );
                        },
                        child: Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.all(10),
                            width: 200,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[850] : Colors.white,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: CachedNetworkImage(
                                imageUrl: msgData['mediaUrl'] ?? '',
                                height: 200,
                                fit: BoxFit.cover,
                                errorWidget: (c, u, e) =>
                                    const Icon(Icons.error),
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    return GestureDetector(
                      onLongPress: () => _showMessageOptions(
                        msgId,
                        msgData['text'] ?? "",
                        msgType == 'text',
                        isMe,
                      ),
                      child: Align(
                        alignment: isMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isMe
                                ? (isVanishMsg
                                      ? Colors.deepPurple[700]
                                      : const Color(0xFFE1FFC7))
                                : (isDark ? Colors.grey[800] : Colors.white),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Column(
                            crossAxisAlignment: isMe
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              if (msgType == 'text')
                                Text(
                                  msgData['text'] ?? "",
                                  style: TextStyle(
                                    color: isMe
                                        ? Colors.black87
                                        : (isDark
                                              ? Colors.white
                                              : Colors.black),
                                  ),
                                )
                              else if (msgType == 'audio')
                                AudioMessageWidget(
                                  audioUrl: msgData['mediaUrl'] ?? '',
                                  isMe: isMe,
                                )
                              else if (msgType == 'image')
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
                                    borderRadius: BorderRadius.circular(10),
                                    child: CachedNetworkImage(
                                      imageUrl: msgData['mediaUrl'] ?? '',
                                      width: 200,
                                      errorWidget: (c, u, e) =>
                                          const Icon(Icons.error),
                                    ),
                                  ),
                                )
                              else if (msgType == 'video')
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
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      color: Colors.black,
                                      width: 200,
                                      height: 150,
                                      child: const Icon(
                                        Icons.play_circle_fill,
                                        color: Colors.white,
                                        size: 40,
                                      ),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 3),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    timeStr,
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  if (isMe)
                                    Icon(
                                      Icons.done_all,
                                      size: 12,
                                      color: isRead ? Colors.blue : Colors.grey,
                                    ),
                                ],
                              ),
                              if (reaction.isNotEmpty)
                                Text(
                                  reaction,
                                  style: const TextStyle(fontSize: 14),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_isUploading)
            const LinearProgressIndicator(color: Color(0xFFFD1D1D)),
          if (isRestricted)
            Container(
              padding: const EdgeInsets.all(15),
              child: const Text(
                "Request pending... 🔒",
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                        filled: true,
                        fillColor: isDark ? Colors.black : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 10,
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

                  // 🌟 ValueNotifier తో బ్లింకింగ్ ఆగిపోయింది + యానిమేటెడ్ మైక్
                  ValueListenableBuilder<bool>(
                    valueListenable: _isTypingNotifier,
                    builder: (context, isTypingNow, child) {
                      return isTypingNow
                          ? CircleAvatar(
                              backgroundColor: const Color(0xFFFD1D1D),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.send,
                                  color: Colors.white,
                                ),
                                onPressed: _sendMessage,
                              ),
                            )
                          : GestureDetector(
                              onTap: () {
                                ScaffoldMessenger.of(context).clearSnackBars();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                      "🎤 Hold to record audio. Release to send.",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    backgroundColor: Colors.grey[800],
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                              onLongPress: _startRecording,
                              onLongPressUp: _stopRecordingAndSend,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeInOut,
                                width: _isRecording ? 50 : 40,
                                height: _isRecording ? 50 : 40,
                                margin: const EdgeInsets.only(
                                  left: 5,
                                  right: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: _isRecording
                                      ? Colors.red
                                      : const Color(0xFFFD1D1D),
                                  shape: BoxShape.circle,
                                  boxShadow: _isRecording
                                      ? [
                                          BoxShadow(
                                            color: Colors.red.withValues(
                                              alpha: 0.5,
                                            ),
                                            blurRadius: 10,
                                            spreadRadius: 2,
                                          ),
                                        ]
                                      : [],
                                ),
                                child: Icon(
                                  Icons.mic,
                                  color: Colors.white,
                                  size: _isRecording ? 28 : 22,
                                ),
                              ),
                            );
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

import 'community_info_screen.dart';
import '../../widgets/safe_elements.dart';
import '../../widgets/cached_media_widget.dart';
import '../common/full_screen_media.dart';
import '../../widgets/audio_message_widget.dart';

class CommunityChatScreen extends StatefulWidget {
  final String communityId;
  final String communityName;
  final String communityIcon;

  const CommunityChatScreen({
    super.key,
    required this.communityId,
    required this.communityName,
    required this.communityIcon,
  });

  @override
  State<CommunityChatScreen> createState() => _CommunityChatScreenState();
}

class _CommunityChatScreenState extends State<CommunityChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  bool _isUploading = false;
  Map<String, dynamic>? myUserData;

  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;

  // 🌟 FIX: Blinking problem solve cheyadaniki ValueNotifier vaaduthunnam!
  final ValueNotifier<bool> _isTypingNotifier = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _fetchMyData();
  }

  @override
  void dispose() {
    _msgController.dispose();
    _audioRecorder.dispose();
    _isTypingNotifier.dispose(); // 🌟 Notifier ni dispose chesthunnam
    super.dispose();
  }

  void _fetchMyData() async {
    try {
      var doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .get();
      if (doc.exists && mounted) {
        setState(() => myUserData = doc.data());
      }
    } catch (e) {
      debugPrint("UserData Fetch Error: $e");
    }
  }

  void _sendMessage({String? mediaUrl, String type = 'text'}) async {
    String text = _msgController.text.trim();
    if (text.isEmpty && mediaUrl == null) return;
    if (myUserData == null) return;

    _msgController.clear();
    _isTypingNotifier.value =
        false; // 🌟 Message send cheyagane malli Mic button ravali

    String messageContent = type == 'image'
        ? '📷 Photo'
        : (type == 'video'
              ? '🎬 Video'
              : (type == 'audio' ? '🎤 Voice Note' : text));
    var timestamp = FieldValue.serverTimestamp();

    try {
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('messages')
          .add({
            'senderId': currentUid,
            'senderName': myUserData!['username'] ?? 'User',
            'senderPic': myUserData!['profilePic'] ?? '',
            'text': text,
            'imageUrl': mediaUrl ?? '',
            'type': type,
            'timestamp': timestamp,
            'deletedBy': [],
            'reactions': {},
          });

      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .update({
            'lastMessage': "${myUserData!['username']}: $messageContent",
            'lastMessageTime': timestamp,
          });
    } catch (e) {
      debugPrint("Send Message Error: $e");
    }
  }

  Future<void> _sendMedia(bool isVideo) async {
    final picker = ImagePicker();
    final XFile? media = isVideo
        ? await picker.pickVideo(source: ImageSource.gallery)
        : await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);

    if (media != null) {
      setState(() => _isUploading = true);
      try {
        String ext = isVideo ? "mp4" : "jpg";
        String fileName = "${DateTime.now().millisecondsSinceEpoch}.$ext";
        Reference ref = FirebaseStorage.instance
            .ref()
            .child('community_media')
            .child(widget.communityId)
            .child(fileName);

        UploadTask uploadTask = ref.putFile(File(media.path));
        TaskSnapshot snapshot = await uploadTask;
        String downloadUrl = await snapshot.ref.getDownloadURL();

        _sendMessage(mediaUrl: downloadUrl, type: isVideo ? 'video' : 'image');
      } catch (e) {
        debugPrint("Media Upload Error: $e");
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.image, color: Colors.blue),
              title: const Text("Photo"),
              onTap: () {
                Navigator.pop(ctx);
                _sendMedia(false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Colors.red),
              title: const Text("Video"),
              onTap: () {
                Navigator.pop(ctx);
                _sendMedia(true);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        String filePath =
            '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: filePath,
        );
        setState(() => _isRecording = true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Microphone permission required!")),
        );
      }
    } catch (e) {
      debugPrint("Recording Start Error: $e");
    }
  }

  Future<void> _stopRecordingAndSend() async {
    try {
      String? path = await _audioRecorder.stop();
      setState(() => _isRecording = false);

      if (path != null) {
        setState(() => _isUploading = true);
        String fileName = "audio_${DateTime.now().millisecondsSinceEpoch}.m4a";
        Reference ref = FirebaseStorage.instance
            .ref()
            .child('community_media')
            .child(widget.communityId)
            .child(fileName);
        await ref.putFile(File(path));
        String downloadUrl = await ref.getDownloadURL();
        _sendMessage(mediaUrl: downloadUrl, type: 'audio');
      }
    } catch (e) {
      debugPrint("Recording Stop Error: $e");
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showMessageOptions(
    String msgId,
    bool isMe,
    Map<String, dynamic> msgData,
  ) {
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
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['❤️', '😂', '😮', '😢', '🙏', '👍'].map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      FirebaseFirestore.instance
                          .collection('communities')
                          .doc(widget.communityId)
                          .collection('messages')
                          .doc(msgId)
                          .set({
                            'reactions': {currentUid: emoji},
                          }, SetOptions(merge: true));
                    },
                    child: Text(emoji, style: const TextStyle(fontSize: 28)),
                  );
                }).toList(),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text("Delete for me"),
              onTap: () {
                Navigator.pop(ctx);
                FirebaseFirestore.instance
                    .collection('communities')
                    .doc(widget.communityId)
                    .collection('messages')
                    .doc(msgId)
                    .set({
                      'deletedBy': FieldValue.arrayUnion([currentUid]),
                    }, SetOptions(merge: true));
              },
            ),
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text(
                  "Delete for everyone",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  FirebaseFirestore.instance
                      .collection('communities')
                      .doc(widget.communityId)
                      .collection('messages')
                      .doc(msgId)
                      .delete();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[200],
      appBar: AppBar(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        elevation: 1,
        titleSpacing: 0,
        title: Row(
          children: [
            SafeProfilePic(
              base64String: widget.communityIcon,
              radius: 18,
              fallbackText: widget.communityName.isNotEmpty
                  ? widget.communityName[0].toUpperCase()
                  : 'C',
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.communityName,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    "Community Group",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.info_outline,
              color: isDark ? Colors.white : Colors.black,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CommunityInfoScreen(communityId: widget.communityId),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('communities')
                  .doc(widget.communityId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                var messages =
                    snapshot.data?.docs.where((doc) {
                      var data = doc.data() as Map<String, dynamic>;
                      List deletedBy = data['deletedBy'] ?? [];
                      return !deletedBy.contains(currentUid);
                    }).toList() ??
                    [];

                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      "Say hi to the community! 👋",
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var msgDoc = messages[index];
                    var msgData = msgDoc.data() as Map<String, dynamic>;
                    String msgId = msgDoc.id;
                    bool isMe = msgData['senderId'] == currentUid;
                    String type = msgData['type'] ?? 'text';
                    DateTime? time = (msgData['timestamp'] as Timestamp?)
                        ?.toDate();
                    String timeStr = time != null
                        ? timeago.format(time, locale: 'en_short')
                        : 'now';

                    Map reactions = msgData['reactions'] ?? {};

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: GestureDetector(
                        onLongPress: () =>
                            _showMessageOptions(msgId, isMe, msgData),
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (!isMe) ...[
                                SafeProfilePic(
                                  base64String: msgData['senderPic'] ?? '',
                                  radius: 12,
                                  fallbackText:
                                      (msgData['senderName'] ?? 'U')[0]
                                          .toUpperCase(),
                                ),
                                const SizedBox(width: 5),
                              ],
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: isMe
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isMe
                                            ? const Color(0xFF833AB4)
                                            : (isDark
                                                  ? Colors.grey[800]
                                                  : Colors.white),
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(15),
                                          topRight: const Radius.circular(15),
                                          bottomLeft: Radius.circular(
                                            isMe ? 15 : 0,
                                          ),
                                          bottomRight: Radius.circular(
                                            isMe ? 0 : 15,
                                          ),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (!isMe)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 5,
                                              ),
                                              child: Text(
                                                msgData['senderName'] ?? 'User',
                                                style: TextStyle(
                                                  color: Colors.blueAccent[100],
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          if (type == 'text')
                                            Text(
                                              msgData['text'] ?? '',
                                              style: TextStyle(
                                                color: isMe
                                                    ? Colors.white
                                                    : (isDark
                                                          ? Colors.white
                                                          : Colors.black),
                                                fontSize: 15,
                                              ),
                                            )
                                          else if (type == 'image')
                                            GestureDetector(
                                              onTap: () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      FullScreenImageViewer(
                                                        imageUrl:
                                                            msgData['imageUrl'] ??
                                                            '',
                                                      ),
                                                ),
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                child: SafeImage(
                                                  base64String:
                                                      msgData['imageUrl'] ?? '',
                                                ),
                                              ),
                                            )
                                          else if (type == 'video')
                                            GestureDetector(
                                              onTap: () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      FullScreenVideoViewer(
                                                        videoUrl:
                                                            msgData['imageUrl'] ??
                                                            '',
                                                      ),
                                                ),
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                child: SizedBox(
                                                  height: 200,
                                                  width: 200,
                                                  child: CachedMediaWidget(
                                                    mediaUrl:
                                                        msgData['imageUrl'] ??
                                                        '',
                                                    type: 'video',
                                                    isGrid: true,
                                                  ),
                                                ),
                                              ),
                                            )
                                          else if (type == 'audio')
                                            AudioMessageWidget(
                                              audioUrl:
                                                  msgData['imageUrl'] ?? '',
                                              isMe: isMe,
                                            ),

                                          const SizedBox(height: 3),
                                          Text(
                                            timeStr,
                                            style: TextStyle(
                                              color: isMe
                                                  ? Colors.white70
                                                  : Colors.grey,
                                              fontSize: 9,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (reactions.isNotEmpty)
                                      Container(
                                        transform: Matrix4.translationValues(
                                          0,
                                          -10,
                                          0,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.grey[700]
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          boxShadow: [
                                            const BoxShadow(
                                              color: Colors.black12,
                                              blurRadius: 2,
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: reactions.values
                                              .toSet()
                                              .map(
                                                (emoji) => Text(
                                                  emoji.toString(),
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                      ),
                                  ],
                                ),
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
            const LinearProgressIndicator(color: Color(0xFF833AB4)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            color: isDark ? Colors.grey[900] : Colors.white,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file, color: Colors.blue),
                  onPressed: _showAttachmentOptions,
                ),
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    // 🌟 FIX: setState theesesi ValueNotifier ki marcham
                    onChanged: (val) {
                      bool hasText = val.trim().isNotEmpty;
                      if (_isTypingNotifier.value != hasText) {
                        _isTypingNotifier.value = hasText;
                      }
                    },
                    decoration: InputDecoration(
                      hintText: "Message...",
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: isDark ? Colors.black : Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 5),

                // 🌟 FIX: ValueListenableBuilder vadadam valla kevalam ee button matrame maruthundi!
                ValueListenableBuilder<bool>(
                  valueListenable: _isTypingNotifier,
                  builder: (context, isTyping, child) {
                    return isTyping
                        ? IconButton(
                            icon: const Icon(
                              Icons.send,
                              color: Color(0xFF833AB4),
                            ),
                            onPressed: () => _sendMessage(),
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
                              margin: const EdgeInsets.only(left: 5, right: 5),
                              decoration: BoxDecoration(
                                color: _isRecording
                                    ? Colors.red
                                    : const Color(0xFF833AB4),
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

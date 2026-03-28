// ignore_for_file: curly_braces_in_flow_control_structures, use_build_context_synchronously

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
import 'package:record/record.dart'; // 🌟 వాయిస్ రికార్డింగ్ కోసం
import 'package:audioplayers/audioplayers.dart'; // 🌟 ఆడియో ప్లేయర్
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';
import '../services/fcm_sender_service.dart';
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
  bool _isTyping = false; // 🌟 టైపింగ్ స్టేటస్ పసిగట్టడానికి

  // 🌟 వాయిస్ రికార్డింగ్ వేరియబుల్స్
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;

  bool _isReceiverPrivate = false;
  bool _amIFollowingReceiver = false;
  bool _isLoadingStatus = true;

  @override
  void initState() {
    super.initState();
    roomId = currentUid.hashCode <= widget.receiverId.hashCode
        ? "${currentUid}_${widget.receiverId}"
        : "${widget.receiverId}_$currentUid";
    _checkPrivacyStatus();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _msgController.dispose();
    super.dispose();
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
      debugPrint("Privacy Check Error: $e");
    }
  }

  Future<void> _sendFriendRequestIfNoPrior() async {
    var existingRequests = await FirebaseFirestore.instance
        .collection('chatRooms')
        .doc(roomId)
        .collection('messages')
        .where('type', isEqualTo: 'friend_request')
        .where('senderId', isEqualTo: currentUid)
        .get();
    if (existingRequests.docs.isEmpty) {
      var timestamp = FieldValue.serverTimestamp();
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
            'timestamp': timestamp,
          });
      await FirebaseFirestore.instance.collection('chatRooms').doc(roomId).set({
        'users': [currentUid, widget.receiverId],
        'lastMessage': "Sent a friend request",
        'timestamp': timestamp,
        'unread_${widget.receiverId}': FieldValue.increment(1),
      }, SetOptions(merge: true));
      _sendPushNotification("Please accept me as a friend");
    }
  }

  Future<void> _acceptRequest(String msgId, String senderId) async {
    await FirebaseFirestore.instance.collection('users').doc(currentUid).update(
      {
        'followers': FieldValue.arrayUnion([senderId]),
      },
    );
    await FirebaseFirestore.instance.collection('users').doc(senderId).update({
      'following': FieldValue.arrayUnion([currentUid]),
    });
    await FirebaseFirestore.instance
        .collection('chatRooms')
        .doc(roomId)
        .collection('messages')
        .doc(msgId)
        .update({'status': 'accepted'});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Request Accepted! ✅"),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _rejectRequest(String msgId) async {
    await FirebaseFirestore.instance
        .collection('chatRooms')
        .doc(roomId)
        .collection('messages')
        .doc(msgId)
        .update({'status': 'rejected'});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Request Rejected ❌"),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _sendMessage() async {
    if (_msgController.text.trim().isEmpty) return;
    String msg = _msgController.text.trim();
    _msgController.clear();
    setState(() => _isTyping = false);

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
          'isEdited': false,
          'isDeleted': false,
        });

    await FirebaseFirestore.instance.collection('chatRooms').doc(roomId).set({
      'users': [currentUid, widget.receiverId],
      'lastMessage': msg,
      'timestamp': timestamp,
      'unread_${widget.receiverId}': FieldValue.increment(1),
    }, SetOptions(merge: true));

    _sendPushNotification(msg);
  }

  // 🌟 UPDATE: కుదించిన (Compressed) ఫైల్స్ అప్‌లోడ్ చేసే లాజిక్
  Future<void> _uploadFileLogic(File file, String type) async {
    try {
      File fileToUpload = file; // డీఫాల్ట్ గా ఒరిజినల్ ఫైల్

      // 📸 1. IMAGE COMPRESSION (5MB -> ~500KB)
      if (type == 'image') {
        final tempDir = await getTemporaryDirectory();
        final outPath =
            "${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg";

        var compressedImage = await FlutterImageCompress.compressAndGetFile(
          file.path,
          outPath,
          quality:
              60, // 🌟 క్వాలిటీ 60% కి తగ్గించాం (కంటికి తేడా తెలియదు, సైజ్ సగానికి పడిపోతుంది)
          minWidth: 1080,
          minHeight: 1080,
        );

        if (compressedImage != null) {
          fileToUpload = File(compressedImage.path);
          debugPrint("✅ Image Compressed!");
        }
      }
      // 🎥 2. VIDEO COMPRESSION (Medium Quality)
      else if (type == 'video') {
        MediaInfo? mediaInfo = await VideoCompress.compressVideo(
          file.path,
          quality:
              VideoQuality.MediumQuality, // 🌟 మొబైల్ కి పర్ఫెక్ట్ క్వాలిటీ
          deleteOrigin: false,
          includeAudio: true,
        );

        if (mediaInfo != null && mediaInfo.file != null) {
          fileToUpload = mediaInfo.file!;
          debugPrint("✅ Video Compressed: ${mediaInfo.filesize} bytes");
        }
      }

      // 🌟 కంప్రెస్ అయిన ఫైల్ ని ఫైర్‌బేస్ కి పంపుతున్నాం!
      String ext = type == 'video' ? 'mp4' : (type == 'audio' ? 'm4a' : 'jpg');
      String fileName = "${DateTime.now().millisecondsSinceEpoch}.$ext";
      Reference ref = FirebaseStorage.instance.ref().child(
        'chat_media/$roomId/$fileName',
      );

      UploadTask uploadTask = ref.putFile(fileToUpload);
      TaskSnapshot snap = await uploadTask;
      String fileUrl = await snap.ref.getDownloadURL();

      var timestamp = FieldValue.serverTimestamp();
      String msgText = type == 'image'
          ? '📷 Photo'
          : (type == 'video'
                ? '🎥 Video'
                : (type == 'audio' ? '🎤 Voice Message' : '🎯 Sticker'));

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
            'isDeleted': false,
          });

      await FirebaseFirestore.instance.collection('chatRooms').doc(roomId).set({
        'users': [currentUid, widget.receiverId],
        'lastMessage': msgText,
        'timestamp': timestamp,
        'unread_${widget.receiverId}': FieldValue.increment(1),
      }, SetOptions(merge: true));

      _sendPushNotification(msgText);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed: $e")));
    } finally {
      // వీడియో కంప్రెస్ అయ్యాక క్యాచీ ని క్లీన్ చేయడం (స్టోరేజ్ ఫుల్ అవ్వకుండా)
      if (type == 'video') {
        VideoCompress.deleteAllCache();
      }
    }
  }

  // 🌟 VOICE RECORDING LOGIC
  Future<void> _startRecording() async {
    if (await Permission.microphone.request().isGranted) {
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
  }

  Future<void> _stopRecordingAndSend() async {
    final path = await _audioRecorder.stop();
    setState(() => _isRecording = false);
    if (path != null) {
      setState(() => _isUploading = true);
      await _uploadFileLogic(File(path), 'audio');
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _handleStickerUpload(String filePath) async {
    setState(() => _isUploading = true);
    await _uploadFileLogic(File(filePath), 'image');
    if (mounted) setState(() => _isUploading = false);
  }

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
      debugPrint("Error: $e");
    }
  }

  Future<void> _pickMultipleImages() async {
    final picker = ImagePicker();
    try {
      final List<XFile> files = await picker.pickMultiImage(imageQuality: 70);
      if (files.isNotEmpty) {
        setState(() => _isUploading = true);
        for (var file in files)
          await _uploadFileLogic(File(file.path), 'image');
        if (mounted) setState(() => _isUploading = false);
      }
    } catch (e) {
      debugPrint("Error: $e");
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
    setState(() => _isTyping = val.isNotEmpty);
    FirebaseFirestore.instance.collection('chatRooms').doc(roomId).set({
      'typing_$currentUid': val.isNotEmpty,
    }, SetOptions(merge: true));
  }

  void _showMessageOptions(String msgId, String currentText, bool isTextMsg) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            if (isTextMsg)
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text("Edit Message"),
                onTap: () {
                  Navigator.pop(ctx);
                  _editMessage(msgId, currentText);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                "Delete for everyone",
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _deleteMessage(msgId);
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
              String newText = editCtrl.text.trim();
              if (newText.isNotEmpty && newText != currentText) {
                await FirebaseFirestore.instance
                    .collection('chatRooms')
                    .doc(roomId)
                    .collection('messages')
                    .doc(msgId)
                    .update({'text': newText, 'isEdited': true});
              }
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _deleteMessage(String msgId) async {
    await FirebaseFirestore.instance
        .collection('chatRooms')
        .doc(roomId)
        .collection('messages')
        .doc(msgId)
        .update({
          'text': "🚫 This message was deleted",
          'isDeleted': true,
          'mediaUrl': FieldValue.delete(),
        });
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    bool isRestricted =
        !_isLoadingStatus && _isReceiverPrivate && !_amIFollowingReceiver;

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
                    if (roomSnap.hasData && roomSnap.data!.exists)
                      isTyping =
                          (roomSnap.data!.data()
                              as Map<
                                String,
                                dynamic
                              >)['typing_${widget.receiverId}'] ??
                          false;
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
                    String msgId = messages[index].id;
                    bool isMe = msgData['senderId'] == currentUid;
                    bool isRead = msgData['isRead'] ?? false;
                    String msgType = msgData['type'] ?? 'text';
                    String requestStatus = msgData['status'] ?? 'pending';
                    bool isDeleted = msgData['isDeleted'] ?? false;
                    bool isEdited = msgData['isEdited'] ?? false;
                    DateTime time =
                        (msgData['timestamp'] as Timestamp?)?.toDate() ??
                        DateTime.now();
                    String timeStr = DateFormat('hh:mm a').format(time);

                    if (!isMe && !isRead)
                      FirebaseFirestore.instance
                          .collection('chatRooms')
                          .doc(roomId)
                          .collection('messages')
                          .doc(msgId)
                          .update({'isRead': true});

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
                        child: Column(
                          children: [
                            Icon(
                              Icons.lock_person,
                              size: 40,
                              color: isDark ? Colors.white70 : Colors.blueGrey,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              isMe
                                  ? "Friend request sent to ${widget.receiverName}"
                                  : "${widget.receiverName} wants to follow you",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              msgData['text'],
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white70
                                    : Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 15),
                            if (!isMe && requestStatus == 'pending')
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  ElevatedButton(
                                    onPressed: () => _rejectRequest(msgId),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red[100],
                                      foregroundColor: Colors.red,
                                      elevation: 0,
                                    ),
                                    child: const Text("Reject"),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => _acceptRequest(
                                      msgId,
                                      msgData['senderId'],
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                    ),
                                    child: const Text("Accept"),
                                  ),
                                ],
                              )
                            else if (requestStatus == 'accepted')
                              const Text(
                                "Request Accepted ✅",
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            else if (requestStatus == 'rejected')
                              const Text(
                                "Request Rejected ❌",
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            else
                              const Text(
                                "Waiting for approval...",
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                      );
                    }

                    // 🌟 NORMAL MESSAGES UI
                    return GestureDetector(
                      onLongPress: () {
                        if (isMe && !isDeleted)
                          _showMessageOptions(
                            msgId,
                            msgData['text'],
                            msgType == 'text',
                          );
                      },
                      child: Align(
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
                            color:
                                (msgType == 'text' ||
                                    msgType == 'audio' ||
                                    isDeleted)
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
                              if (!isDark &&
                                  (msgType == 'text' ||
                                      msgType == 'audio' ||
                                      isDeleted))
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
                              if (isDeleted)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.block,
                                        size: 14,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        msgData['text'],
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontStyle: FontStyle.italic,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else if (msgType == 'text')
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
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
                                      if (isEdited)
                                        const Padding(
                                          padding: EdgeInsets.only(left: 5),
                                          child: Text(
                                            " (edited)",
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 10,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                )
                              else if (msgType ==
                                  'audio') // 🌟 ఆడియో ప్లేయర్ UI
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
                                    borderRadius: BorderRadius.circular(12),
                                    child: CachedNetworkImage(
                                      imageUrl: msgData['mediaUrl'] ?? '',
                                      width:
                                          MediaQuery.of(context).size.width *
                                          0.6,
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
                                    borderRadius: BorderRadius.circular(12),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Container(
                                          width:
                                              MediaQuery.of(
                                                context,
                                              ).size.width *
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
                                  horizontal:
                                      (msgType == 'text' ||
                                          msgType == 'audio' ||
                                          isDeleted)
                                      ? 10
                                      : 4,
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
                                        color: isRead
                                            ? Colors.blue
                                            : Colors.grey,
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
            const LinearProgressIndicator(color: Color(0xFF007AFF)),
          if (isRestricted)
            Container(
              padding: const EdgeInsets.all(15),
              color: isDark ? Colors.grey[900] : Colors.white,
              width: double.infinity,
              child: const Text(
                "You can't reply until they accept your request. 🔒",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              color: isDark ? Colors.grey[900] : Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: _isRecording
                        // 🌟 రికార్డింగ్ అవుతున్నప్పుడు కనిపించే UI
                        ? Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.mic, color: Colors.red),
                                SizedBox(width: 10),
                                Text(
                                  "Recording...",
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          )
                        // 🌟 నార్మల్ టెక్స్ట్ ఫీల్డ్
                        : TextField(
                            controller: _msgController,
                            onChanged: _onTyping,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                            ),
                            contentInsertionConfiguration:
                                ContentInsertionConfiguration(
                                  onContentInserted:
                                      (KeyboardInsertedContent content) async {
                                        if (content.hasData) {
                                          final tempDir = Directory.systemTemp;
                                          final file = File(
                                            '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.png',
                                          );
                                          await file.writeAsBytes(
                                            content.data!,
                                          );
                                          _handleStickerUpload(file.path);
                                        }
                                      },
                                  allowedMimeTypes: const <String>[
                                    'image/png',
                                    'image/gif',
                                    'image/jpeg',
                                  ],
                                ),
                            decoration: InputDecoration(
                              hintText: "Message...",
                              hintStyle: const TextStyle(color: Colors.grey),
                              filled: true,
                              fillColor: isDark
                                  ? Colors.black
                                  : Colors.grey[200],
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
                                onPressed: () {},
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
                                    onPressed: () => _pickSingleMedia(
                                      ImageSource.camera,
                                      false,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  // 🌟 టైప్ చేస్తే SEND బటన్, ఖాళీగా ఉంటే MIC బటన్
                  _isTyping
                      ? CircleAvatar(
                          backgroundColor: const Color(0xFF007AFF),
                          radius: 22,
                          child: IconButton(
                            icon: const Icon(
                              Icons.send,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: _sendMessage,
                          ),
                        )
                      : GestureDetector(
                          onLongPress:
                              _startRecording, // నొక్కి పట్టుకుంటే రికార్డ్
                          onLongPressUp:
                              _stopRecordingAndSend, // వదిలేస్తే సెండ్ అవుతుంది
                          child: CircleAvatar(
                            backgroundColor: _isRecording
                                ? Colors.red
                                : const Color(0xFF007AFF),
                            radius: 24,
                            child: const Icon(
                              Icons.mic,
                              color: Colors.white,
                              size: 24,
                            ),
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

// 🌟 ఆడియో ప్లే చేయడానికి కొత్త విడ్జెట్
class AudioMessageWidget extends StatefulWidget {
  final String audioUrl;
  final bool isMe;
  const AudioMessageWidget({
    super.key,
    required this.audioUrl,
    required this.isMe,
  });
  @override
  State<AudioMessageWidget> createState() => _AudioMessageWidgetState();
}

class _AudioMessageWidgetState extends State<AudioMessageWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) setState(() => _duration = newDuration);
    });
    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) setState(() => _position = newPosition);
    });
    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted)
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatTime(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      width: MediaQuery.of(context).size.width * 0.6,
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
              size: 35,
              color: widget.isMe ? Colors.green[800] : Colors.blue,
            ),
            onPressed: () async {
              if (_isPlaying)
                await _audioPlayer.pause();
              else
                await _audioPlayer.play(UrlSource(widget.audioUrl));
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    activeTrackColor: widget.isMe
                        ? Colors.green[700]
                        : Colors.blue,
                    inactiveTrackColor: Colors.grey[400],
                    thumbColor: widget.isMe ? Colors.green[800] : Colors.blue,
                  ),
                  child: Slider(
                    min: 0,
                    max: _duration.inSeconds > 0
                        ? _duration.inSeconds.toDouble()
                        : 1.0,
                    value: _position.inSeconds.toDouble().clamp(
                      0,
                      _duration.inSeconds > 0
                          ? _duration.inSeconds.toDouble()
                          : 1.0,
                    ),
                    onChanged: (val) async {
                      await _audioPlayer.seek(Duration(seconds: val.toInt()));
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Text(
                    _formatTime(_position),
                    style: TextStyle(fontSize: 10, color: Colors.grey[700]),
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

// పాత వ్యూయర్స్
class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  const FullScreenImageViewer({super.key, required this.imageUrl});
  @override
  Widget build(BuildContext context) => Scaffold(
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
          placeholder: (c, u) =>
              const CircularProgressIndicator(color: Colors.white),
        ),
      ),
    ),
  );
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
    _player = CachedVideoPlayerPlus.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
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
  Widget build(BuildContext context) => Scaffold(
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
            onPressed: () => setState(
              () => _player.controller.value.isPlaying
                  ? _player.controller.pause()
                  : _player.controller.play(),
            ),
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

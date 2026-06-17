// lib/screens/chat/chat_room_screen.dart

import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart'; // 🌟 THE FIX: Caching

import '../../services/firestore_methods.dart';
import '../../widgets/voice_player_bubble.dart';
import '../../widgets/forward_message_sheet.dart';
import '../../widgets/full_screen_image_viewer.dart';
import '../calls/calls_screen.dart'; // 🌟 THE FIX: Call Screen Navigation

class ChatRoomScreen extends StatefulWidget {
  final String receiverUid;
  final String receiverUsername;

  const ChatRoomScreen({
    super.key,
    required this.receiverUid,
    required this.receiverUsername,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final currentUid = FirebaseAuth.instance.currentUser!.uid;
  late String chatRoomId;
  bool isVanishModeActive = false;
  String _selectedTheme = "Default";

  bool _isMeTyping = false;
  Timer? _typingTimer;
  bool _isReceiverTyping = false;
  Map<String, dynamic>? _replyingToMessage;

  late AudioRecorder _audioRecorder;
  bool _isRecording = false;
  bool _isTextEmpty = true;

  late Stream<QuerySnapshot> _messagesStream;
  late Stream<DocumentSnapshot> _userStream;

  @override
  void initState() {
    super.initState();
    List<String> ids = [currentUid, widget.receiverUid];
    ids.sort();
    chatRoomId = ids.join("_");

    _audioRecorder = AudioRecorder();

    _messagesStream = FirestoreMethods().getMessages(
      currentUid,
      widget.receiverUid,
    );
    _userStream = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.receiverUid)
        .snapshots();

    FirestoreMethods().markMessageAsRead(chatRoomId);
    _listenToChatRoomLive();

    _messageController.addListener(() {
      _onTextChanged();
      bool currentEmptyState = _messageController.text.trim().isEmpty;
      if (_isTextEmpty != currentEmptyState) {
        if (mounted) {
          setState(() {
            _isTextEmpty = currentEmptyState;
          });
        }
      }
    });
  }

  void _listenToChatRoomLive() {
    FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(chatRoomId)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists && mounted) {
            var chatData = snapshot.data();
            Map<String, dynamic> typingMap = chatData?['typingStatus'] ?? {};

            setState(() {
              isVanishModeActive = chatData?['isVanishMode'] ?? false;
              _isReceiverTyping = typingMap[widget.receiverUid] ?? false;
              _selectedTheme = chatData?['chatTheme'] ?? "Default";
            });

            FirestoreMethods().markMessageAsRead(chatRoomId);
          }
        });
  }

  Map<String, dynamic> _getThemeColors(bool isDark) {
    switch (_selectedTheme) {
      case "Lavender 💜":
        return {
          'bg': isDark ? const Color(0xFF1A1525) : const Color(0xFFF3E5F5),
          'myBubble': Colors.purple,
          'otherBubble': isDark ? const Color(0xFF2D253A) : Colors.purple[100]!,
          'appBar': isDark ? const Color(0xFF140F1D) : Colors.purple[50]!,
        };
      case "Sunset 🌅":
        return {
          'bg': isDark ? const Color(0xFF241510) : const Color(0xFFFFF3E0),
          'myBubble': Colors.orangeAccent[700]!,
          'otherBubble': isDark ? const Color(0xFF3A241C) : Colors.orange[100]!,
          'appBar': isDark ? const Color(0xFF1C0F0A) : Colors.orange[50]!,
        };
      case "Midnight Blue 💙":
        return {
          'bg': isDark ? const Color(0xFF0B132B) : const Color(0xFFE0F7FA),
          'myBubble': const Color(0xFF1D4ED8),
          'otherBubble': isDark ? const Color(0xFF1C2541) : Colors.blue[100]!,
          'appBar': isDark ? const Color(0xFF070A13) : Colors.blue[50]!,
        };
      case "Default":
      default:
        return {
          'bg': isVanishModeActive
              ? const Color(0xFF0D0B14)
              : (isDark ? Colors.black : Colors.grey[50]),
          'myBubble': isVanishModeActive
              ? Colors.purple[700]!
              : Colors.blueAccent,
          'otherBubble': isVanishModeActive
              ? Colors.grey[900]!
              : (isDark ? Colors.grey[800]! : Colors.grey[300]!),
          'appBar': isVanishModeActive
              ? const Color(0xFF141122)
              : (isDark ? Colors.black : Colors.white),
        };
    }
  }

  void _openThemeSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final List<String> themesList = [
          "Default",
          "Lavender 💜",
          "Sunset 🌅",
          "Midnight Blue 💙",
        ];
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Chat Theme 🎨',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 10),
              Column(
                children: themesList.map((themeName) {
                  return ListTile(
                    title: Text(
                      themeName,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    trailing: _selectedTheme == themeName
                        ? const Icon(
                            Icons.check_circle,
                            color: Colors.blueAccent,
                          )
                        : null,
                    onTap: () async {
                      Navigator.pop(context);
                      await FirestoreMethods().updateChatTheme(
                        chatRoomId,
                        themeName,
                      );
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _onTextChanged() {
    if (_messageController.text.trim().isNotEmpty && !_isMeTyping) {
      _isMeTyping = true;
      FirestoreMethods().updateTypingStatus(chatRoomId, true);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isMeTyping) {
        _isMeTyping = false;
        FirestoreMethods().updateTypingStatus(chatRoomId, false);
      }
    });
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getTemporaryDirectory();
        String filePath =
            '${directory.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const RecordConfig(), path: filePath);
        setState(() => _isRecording = true);
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
      if (path != null) {
        await FirestoreMethods().sendVoiceMessage(
          widget.receiverUid,
          File(path),
          isVanish: isVanishModeActive,
        );
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  void _send() async {
    if (_messageController.text.trim().isNotEmpty) {
      String msg = _messageController.text.trim();
      _messageController.clear();
      _isMeTyping = false;
      FirestoreMethods().updateTypingStatus(chatRoomId, false);

      if (_replyingToMessage != null) {
        var tempReply = _replyingToMessage!;
        setState(() => _replyingToMessage = null);
        await FirestoreMethods().sendReplyMessage(
          receiverId: widget.receiverUid,
          message: msg,
          repliedToData: tempReply,
          isVanish: isVanishModeActive,
        );
      } else {
        await FirestoreMethods().sendMessage(
          widget.receiverUid,
          msg,
          isVanish: isVanishModeActive,
        );
      }
    }
  }

  void _showAttachmentsMenu() {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 30,
            runSpacing: 25,
            children: [
              _buildAttachmentIcon(
                Icons.insert_drive_file,
                Colors.deepPurpleAccent,
                "Document",
                () async {
                  Navigator.pop(ctx);
                  FilePickerResult? result = await FilePicker.platform
                      .pickFiles(type: FileType.any);
                  if (result != null && result.files.single.path != null) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(content: Text("Uploading Document... ⏳")),
                    );
                    await FirestoreMethods().sendDocumentMessage(
                      widget.receiverUid,
                      File(result.files.single.path!),
                      result.files.single.name,
                      isVanish: isVanishModeActive,
                    );
                  }
                },
              ),
              _buildAttachmentIcon(
                Icons.camera_alt,
                Colors.pinkAccent,
                "Camera",
                () async {
                  Navigator.pop(ctx);
                  final pickedFile = await ImagePicker().pickImage(
                    source: ImageSource.camera,
                    imageQuality: 70,
                  );
                  if (pickedFile != null) {
                    await FirestoreMethods().sendImageMessage(
                      widget.receiverUid,
                      File(pickedFile.path),
                      isVanish: isVanishModeActive,
                    );
                  }
                },
              ),
              _buildAttachmentIcon(
                Icons.photo_library,
                Colors.purpleAccent,
                "Gallery",
                () async {
                  Navigator.pop(ctx);
                  final pickedFile = await ImagePicker().pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 70,
                  );
                  if (pickedFile != null) {
                    await FirestoreMethods().sendImageMessage(
                      widget.receiverUid,
                      File(pickedFile.path),
                      isVanish: isVanishModeActive,
                    );
                  }
                },
              ),
              _buildAttachmentIcon(
                Icons.location_on,
                Colors.green,
                "Location",
                () async {
                  Navigator.pop(ctx);
                  bool serviceEnabled =
                      await Geolocator.isLocationServiceEnabled();
                  if (!serviceEnabled) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text("Location services are disabled."),
                      ),
                    );
                    return;
                  }
                  LocationPermission permission =
                      await Geolocator.checkPermission();
                  if (permission == LocationPermission.denied) {
                    permission = await Geolocator.requestPermission();
                    if (permission == LocationPermission.denied) return;
                  }
                  if (permission == LocationPermission.whileInUse ||
                      permission == LocationPermission.always) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(content: Text("Fetching Location... ⏳")),
                    );
                    Position position = await Geolocator.getCurrentPosition(
                      locationSettings: const LocationSettings(
                        accuracy: LocationAccuracy.high,
                      ),
                    );
                    await FirestoreMethods().sendLocationMessage(
                      widget.receiverUid,
                      position.latitude,
                      position.longitude,
                      isVanish: isVanishModeActive,
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAttachmentIcon(
    IconData icon,
    Color color,
    String label,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  void _showMessageOptions(
    String messageId,
    bool isMe,
    bool isLastMessage,
    String msgText,
    String senderId,
    String messageType,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        final List<String> emojis = ["❤️", "😂", "😮", "😢", "🙏", "👍"];
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.all(12),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: emojis.map((emoji) {
                  return InkWell(
                    onTap: () async {
                      Navigator.pop(context);
                      await FirestoreMethods().updateMessageReaction(
                        chatRoomId,
                        messageId,
                        emoji,
                      );
                    },
                    child: Text(emoji, style: const TextStyle(fontSize: 26)),
                  );
                }).toList(),
              ),
              const Divider(height: 20),

              if (messageType == 'text' || messageType == 'image') ...[
                ListTile(
                  leading: const Icon(
                    Icons.reply_rounded,
                    color: Colors.blueAccent,
                  ),
                  title: const Text(
                    'Reply',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _replyingToMessage = {
                        'messageId': messageId,
                        'message': messageType == 'image'
                            ? '📷 Image'
                            : msgText,
                        'senderName': senderId == currentUid
                            ? 'You'
                            : widget.receiverUsername,
                      };
                    });
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.green,
                  ),
                  title: const Text(
                    'Forward Message',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      builder: (context) => ForwardMessageSheet(
                        messageText: msgText,
                        messageType: messageType,
                      ),
                    );
                  },
                ),
              ],

              const Divider(height: 10),

              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.grey),
                title: const Text(
                  'Delete for me',
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await FirestoreMethods().deleteMessage(
                    chatRoomId,
                    messageId,
                    isLastMessage,
                    forEveryone: false,
                  );
                },
              ),

              if (isMe)
                ListTile(
                  leading: const Icon(
                    Icons.delete_forever,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    'Delete for everyone',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await FirestoreMethods().deleteMessage(
                      chatRoomId,
                      messageId,
                      isLastMessage,
                      forEveryone: true,
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _audioRecorder.dispose();
    _messageController.dispose();
    FirestoreMethods().updateTypingStatus(chatRoomId, false);
    if (isVanishModeActive) {
      FirestoreMethods().cleanVanishMessages(chatRoomId);
    }
    super.dispose();
  }

  Widget _buildSharedMediaCard(
    String imageUrl,
    String type,
    String mediaId,
    bool isDark,
  ) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Row(
              children: [
                Icon(
                  type == 'shared_reel'
                      ? Icons.movie_creation_outlined
                      : Icons.image_outlined,
                  size: 16,
                  color: Colors.grey,
                ),
                const SizedBox(width: 6),
                Text(
                  type == 'shared_reel' ? "Banjara Reel 🎬" : "Banjara Post 📸",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          // 🌟 THE FIX: Shared Media Images Caching
          CachedNetworkImage(
            imageUrl: imageUrl,
            width: 220,
            height: 180,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              width: 220,
              height: 180,
              color: Colors.grey[800],
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.grey[300],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: const Text(
              'View Media 🚀',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.blueAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(
    String fileUrl,
    String fileName,
    bool isMe,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: () async {
        final Uri url = Uri.parse(fileUrl);
        if (await canLaunchUrl(url))
          await launchUrl(url, mode: LaunchMode.externalApplication);
      },
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.white.withValues(alpha: 0.2)
              : (isDark ? Colors.grey[800] : Colors.grey[300]),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.picture_as_pdf_rounded,
              color: Colors.redAccent,
              size: 36,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isMe
                          ? Colors.white
                          : (isDark ? Colors.white : Colors.black87),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "PDF Document",
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard(String locationUrl, bool isMe, bool isDark) {
    return GestureDetector(
      onTap: () async {
        final Uri url = Uri.parse(locationUrl);
        if (await canLaunchUrl(url))
          await launchUrl(url, mode: LaunchMode.externalApplication);
      },
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.white.withValues(alpha: 0.2)
              : (isDark ? Colors.grey[800] : Colors.grey[300]),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.green.withValues(alpha: 0.2),
              child: const Icon(Icons.location_on, color: Colors.green),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Live Location",
                    style: TextStyle(
                      color: isMe
                          ? Colors.white
                          : (isDark ? Colors.white : Colors.black87),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Tap to view on Map",
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyQuoteWidget(Map<String, dynamic> replyData, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.black12,
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: Colors.blueAccent, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            replyData['senderName'] ?? 'User',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.blueAccent,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            replyData['message'] ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // 🌟 THE FIX: Call Screen Navigation Logic
  void _handleCallClicked(bool isVideo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          channelId:
              chatRoomId, // మన చాట్ రూమ్ ఐడీ నే కాలింగ్ కి ఛానల్ గా వాడుతున్నాం
          isVideoCall: isVideo,
          targetName: widget.receiverUsername,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeColors = _getThemeColors(isDark);

    return Scaffold(
      backgroundColor: themeColors['bg'],
      appBar: AppBar(
        backgroundColor: themeColors['appBar'],
        elevation: 0.5,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        titleSpacing: 0,
        title: StreamBuilder<DocumentSnapshot>(
          stream: _userStream,
          builder: (context, snapshot) {
            String statusText = 'Offline';
            bool isOnline = false;
            bool isVerified = false;
            String profilePic =
                'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png';

            if (snapshot.hasData && snapshot.data!.exists) {
              var userData = snapshot.data!.data() as Map<String, dynamic>;
              isOnline = userData['isOnline'] ?? false;
              isVerified = userData['isVerified'] ?? false;
              profilePic = userData['profilePic'] ?? profilePic;
              var lastSeen = userData['lastSeen'];

              if (isOnline) {
                statusText = 'Online 🟢';
              } else if (lastSeen != null) {
                DateTime lastSeenDate = (lastSeen as Timestamp).toDate();
                statusText =
                    'Active ${timeago.format(lastSeenDate, locale: 'en_short')} ago';
              }
            }

            String subtitleStatus = _isReceiverTyping
                ? 'Typing...'
                : statusText;
            Color subtitleColor = _isReceiverTyping
                ? Colors.blueAccent
                : (isVanishModeActive
                      ? Colors.purpleAccent
                      : (isOnline ? Colors.green : Colors.grey));

            return Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FullScreenImageViewer(
                          imageUrl: profilePic,
                          tag: 'profile_pic_${widget.receiverUid}',
                        ),
                      ),
                    );
                  },
                  child: Hero(
                    tag: 'profile_pic_${widget.receiverUid}',
                    child: CircleAvatar(
                      radius: 18,
                      // 🌟 THE FIX: Profile Pic Caching
                      backgroundImage: CachedNetworkImageProvider(profilePic),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              widget.receiverUsername,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isVanishModeActive
                                    ? Colors.purple[100]
                                    : (isDark ? Colors.white : Colors.black),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified,
                              color: Colors.blueAccent,
                              size: 15,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isVanishModeActive && !_isReceiverTyping
                            ? 'Vanish Mode 👻'
                            : subtitleStatus,
                        style: TextStyle(
                          color: subtitleColor,
                          fontSize: 12,
                          fontWeight: _isReceiverTyping
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam_rounded, color: Colors.blueAccent),
            onPressed: () => _handleCallClicked(true), // 🌟 Video Call
          ),
          IconButton(
            icon: const Icon(Icons.call_rounded, color: Colors.blueAccent),
            onPressed: () => _handleCallClicked(false), // 🌟 Audio Call
          ),
          IconButton(
            icon: AnimatedOpacity(
              opacity: isVanishModeActive ? 1.0 : 0.4,
              duration: const Duration(milliseconds: 300),
              child: const Text("👻", style: TextStyle(fontSize: 22)),
            ),
            onPressed: () => FirestoreMethods().toggleVanishMode(
              chatRoomId,
              !isVanishModeActive,
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'theme') {
                _openThemeSelector();
              } else if (value == 'clear') {
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                await FirestoreMethods().clearChatMessages(chatRoomId);
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text("Chat cleared successfully! 🧼"),
                  ),
                );
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'theme',
                child: Row(
                  children: [
                    Icon(Icons.palette_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('Change Theme'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(
                      Icons.cleaning_services_outlined,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Clear Chat',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _messagesStream,
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      isVanishModeActive
                          ? 'Messages will vanish when you close the chat 👻'
                          : 'Say Hi! 👋',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    var data = doc.data() as Map<String, dynamic>;

                    List deletedFor = data['deletedFor'] ?? [];
                    if (deletedFor.contains(currentUid))
                      return const SizedBox.shrink();

                    bool isMe = data['senderId'] == currentUid;
                    String messageText = data['message'] ?? '';
                    String messageType = data['messageType'] ?? 'text';
                    String messageId = data['messageId'] ?? doc.id;
                    bool isVanishMsg = data['isVanish'] ?? false;
                    String reactionEmoji = data['reaction'] ?? '';
                    String mediaId = data['mediaId'] ?? '';
                    String fileName = data['fileName'] ?? 'Document';
                    bool isLastMessage = index == 0;
                    String msgStatus = data['status'] ?? 'sent';
                    Map<String, dynamic>? repliedTo = data['repliedTo'];

                    bool isSharedMedia =
                        messageType == 'shared_post' ||
                        messageType == 'shared_reel';
                    bool isAudio = messageType == 'audio';
                    bool isDocument = messageType == 'document';
                    bool isLocation = messageType == 'location';
                    bool isImage = messageType == 'image';

                    Color bubbleColor = isMe
                        ? themeColors['myBubble']
                        : themeColors['otherBubble'];

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onLongPress: () => _showMessageOptions(
                          messageId,
                          isMe,
                          isLastMessage,
                          messageText,
                          data['senderId'],
                          messageType,
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(
                                left: 16,
                                right: 16,
                                top: 8,
                                bottom: 12,
                              ),
                              padding:
                                  (isImage ||
                                      isSharedMedia ||
                                      isAudio ||
                                      isDocument ||
                                      isLocation)
                                  ? EdgeInsets.zero
                                  : const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                              decoration: BoxDecoration(
                                color:
                                    (isImage ||
                                        isSharedMedia ||
                                        isAudio ||
                                        isDocument ||
                                        isLocation)
                                    ? Colors.transparent
                                    : bubbleColor,
                                border: isVanishMsg
                                    ? Border.all(
                                        color: Colors.purpleAccent.withValues(
                                          alpha: 0.5,
                                        ),
                                        width: 1,
                                      )
                                    : null,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(12),
                                  topRight: const Radius.circular(12),
                                  bottomLeft: Radius.circular(isMe ? 12 : 0),
                                  bottomRight: Radius.circular(isMe ? 0 : 12),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: isMe
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isImage)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      // 🌟 THE FIX: Chat Image Caching
                                      child: CachedNetworkImage(
                                        imageUrl: messageText,
                                        width: 220,
                                        height: 220,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            Container(
                                              width: 220,
                                              height: 220,
                                              color: Colors.grey[800],
                                              child: const Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              ),
                                            ),
                                      ),
                                    )
                                  else if (isSharedMedia)
                                    _buildSharedMediaCard(
                                      messageText,
                                      messageType,
                                      mediaId,
                                      isDark,
                                    )
                                  else if (isDocument)
                                    _buildDocumentCard(
                                      messageText,
                                      fileName,
                                      isMe,
                                      isDark,
                                    )
                                  else if (isLocation)
                                    _buildLocationCard(
                                      messageText,
                                      isMe,
                                      isDark,
                                    )
                                  else if (isAudio)
                                    Card(
                                      color: bubbleColor,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      margin: EdgeInsets.zero,
                                      child: VoicePlayerBubble(
                                        audioUrl: messageText,
                                        isMe: isMe,
                                      ),
                                    )
                                  else
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (repliedTo != null)
                                          _buildReplyQuoteWidget(
                                            repliedTo,
                                            isDark,
                                          ),
                                        Text(
                                          isVanishMsg
                                              ? "👻 $messageText"
                                              : messageText,
                                          style: TextStyle(
                                            color: isMe
                                                ? Colors.white
                                                : (isDark
                                                      ? Colors.white
                                                      : Colors.black87),
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),

                                  if (isMe &&
                                      !isAudio &&
                                      !isSharedMedia &&
                                      !isImage &&
                                      !isDocument &&
                                      !isLocation) ...[
                                    const SizedBox(height: 2),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          msgStatus == 'read'
                                              ? Icons.done_all
                                              : (msgStatus == 'delivered'
                                                    ? Icons.done_all
                                                    : Icons.check),
                                          color: msgStatus == 'read'
                                              ? Colors.lightBlueAccent
                                              : Colors.white70,
                                          size: 14,
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (isMe &&
                                (isImage ||
                                    isSharedMedia ||
                                    isAudio ||
                                    isDocument ||
                                    isLocation))
                              Positioned(
                                bottom: 12,
                                right: 20,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.black45,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    msgStatus == 'read'
                                        ? Icons.done_all
                                        : (msgStatus == 'delivered'
                                              ? Icons.done_all
                                              : Icons.check),
                                    color: msgStatus == 'read'
                                        ? Colors.lightBlueAccent
                                        : Colors.white,
                                    size: 12,
                                  ),
                                ),
                              ),
                            if (reactionEmoji.isNotEmpty)
                              Positioned(
                                bottom: 2,
                                right: isMe ? 24 : null,
                                left: !isMe ? 24 : null,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.grey[850]
                                        : Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.1,
                                        ),
                                        blurRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    reactionEmoji,
                                    style: const TextStyle(fontSize: 13),
                                  ),
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
          if (_replyingToMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.grey[200],
                border: const Border(
                  top: BorderSide(color: Colors.grey, width: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.reply_rounded,
                    color: Colors.blueAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Replying to ${_replyingToMessage!['senderName']}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.blueAccent,
                          ),
                        ),
                        Text(
                          _replyingToMessage!['message'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                    onPressed: () => setState(() => _replyingToMessage = null),
                  ),
                ],
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.attach_file_rounded,
                      size: 26,
                      color: isVanishModeActive
                          ? Colors.purpleAccent
                          : Colors.grey[600],
                    ),
                    onPressed: _showAttachmentsMenu,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: TextStyle(
                        color: isVanishModeActive
                            ? Colors.white
                            : (isDark ? Colors.white : Colors.black),
                      ),
                      decoration: InputDecoration(
                        hintText: _isRecording
                            ? 'Recording audio... 🎙️'
                            : (isVanishModeActive
                                  ? 'Vanish Mode Message...'
                                  : 'Type a message...'),
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: isVanishModeActive
                            ? const Color(0xFF1A162E)
                            : (isDark ? Colors.grey[900] : Colors.grey[200]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _isTextEmpty
                      ? GestureDetector(
                          onLongPressStart: (_) => _startRecording(),
                          onLongPressEnd: (_) => _stopRecording(),
                          child: CircleAvatar(
                            radius: 24,
                            backgroundColor: _isRecording
                                ? Colors.redAccent
                                : (isVanishModeActive
                                      ? Colors.purpleAccent
                                      : Colors.blueAccent),
                            child: Icon(
                              _isRecording ? Icons.mic : Icons.mic_none,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        )
                      : IconButton(
                          icon: Icon(
                            Icons.send,
                            color: isVanishModeActive
                                ? Colors.purpleAccent
                                : Colors.blueAccent,
                            size: 28,
                          ),
                          onPressed: _send,
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

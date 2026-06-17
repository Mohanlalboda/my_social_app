// lib/screens/chat/group_chat_room_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/firestore_methods.dart';
import 'group_info_screen.dart';
import '../../widgets/voice_player_bubble.dart';
import '../../widgets/full_screen_image_viewer.dart';
import 'package:cached_network_image/cached_network_image.dart';

class GroupChatRoomScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String groupPic;

  const GroupChatRoomScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.groupPic,
  });

  @override
  State<GroupChatRoomScreen> createState() => _GroupChatRoomScreenState();
}

class _GroupChatRoomScreenState extends State<GroupChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  late AudioRecorder _audioRecorder;
  bool _isRecording = false;
  bool _isTextEmpty = true;
  Map<String, dynamic>? _replyingToMessage;

  bool isAdminOnly = false;
  bool amIAdmin = false;
  String? pinnedMessage;

  // 🌟 THE FIX: స్క్రీన్ బ్లింక్ అవ్వకుండా గ్రూప్ మెసేజ్ స్ట్రీమ్ ని ఇక్కడే దాచుకుంటున్నాం
  late Stream<QuerySnapshot> _groupMessagesStream;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();

    // 🌟 THE FIX: స్ట్రీమ్ ని ఒక్కసారే కాల్ చేసి మెమరీలో పెట్టుకుంటున్నాం
    _groupMessagesStream = FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(widget.groupId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();

    _messageController.addListener(() {
      bool currentEmptyState = _messageController.text.trim().isEmpty;
      if (_isTextEmpty != currentEmptyState) {
        if (mounted) {
          setState(() => _isTextEmpty = currentEmptyState);
        }
      }
    });
    _listenToGroupData();
  }

  void _listenToGroupData() {
    FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(widget.groupId)
        .snapshots()
        .listen((doc) {
          if (doc.exists && mounted) {
            var data = doc.data() as Map<String, dynamic>;
            List admins = data['admins'] ?? [];
            setState(() {
              amIAdmin = admins.contains(currentUid);
              isAdminOnly = data['isAdminOnly'] ?? false;
              pinnedMessage = data['pinnedMessage'];
            });
          }
        });
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _sendGroupMsg() async {
    if (_messageController.text.trim().isNotEmpty) {
      String msg = _messageController.text.trim();
      _messageController.clear();

      if (_replyingToMessage != null) {
        var tempReply = _replyingToMessage!;
        setState(() => _replyingToMessage = null);
        await FirestoreMethods().sendGroupReplyMessage(
          groupId: widget.groupId,
          message: msg,
          repliedToData: tempReply,
        );
      } else {
        await FirestoreMethods().sendGroupMessage(widget.groupId, msg);
      }
    }
  }

  Future<void> _startGroupRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getTemporaryDirectory();
        String filePath =
            '${directory.path}/group_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const RecordConfig(), path: filePath);
        setState(() => _isRecording = true);
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> _stopGroupRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
      if (path != null) {
        await FirestoreMethods().sendGroupVoiceMessage(
          widget.groupId,
          File(path),
        );
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  void _showCreatePollDialog() {
    TextEditingController questionController = TextEditingController();
    List<TextEditingController> optionControllers = [
      TextEditingController(),
      TextEditingController(),
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                "Create Poll 📊",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: questionController,
                      decoration: const InputDecoration(
                        labelText: "Ask a question",
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...List.generate(
                      optionControllers.length,
                      (index) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: TextField(
                          controller: optionControllers[index],
                          decoration: InputDecoration(
                            labelText: "Option ${index + 1}",
                            isDense: true,
                          ),
                        ),
                      ),
                    ),
                    if (optionControllers.length < 5)
                      TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text("Add Option"),
                        onPressed: () => setModalState(
                          () => optionControllers.add(TextEditingController()),
                        ),
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
                  onPressed: () {
                    String q = questionController.text.trim();
                    List<String> opts = optionControllers
                        .map((c) => c.text.trim())
                        .where((t) => t.isNotEmpty)
                        .toList();
                    if (q.isNotEmpty && opts.length >= 2) {
                      Navigator.pop(ctx);
                      FirestoreMethods().sendGroupPoll(widget.groupId, q, opts);
                    }
                  },
                  child: const Text(
                    "Send",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _sendEmergencyAlert() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          "Emergency Alert 🚨",
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "Are you sure you want to send an emergency alert? This will highlight your message in red to all members.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              FirestoreMethods().sendGroupEmergencyMessage(
                widget.groupId,
                "🚨 EMERGENCY! I need immediate help!",
              );
            },
            child: const Text(
              "Send Alert",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
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
                    await FirestoreMethods().sendGroupDocumentMessage(
                      widget.groupId,
                      File(result.files.single.path!),
                      result.files.single.name,
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
                  if (pickedFile != null)
                    await FirestoreMethods().sendGroupImageMessage(
                      widget.groupId,
                      File(pickedFile.path),
                    );
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
                  if (pickedFile != null)
                    await FirestoreMethods().sendGroupImageMessage(
                      widget.groupId,
                      File(pickedFile.path),
                    );
                },
              ),
              _buildAttachmentIcon(
                Icons.location_on,
                Colors.green,
                "Location",
                () async {
                  Navigator.pop(ctx);
                  Position position = await Geolocator.getCurrentPosition(
                    locationSettings: const LocationSettings(
                      accuracy: LocationAccuracy.high,
                    ),
                  );
                  await FirestoreMethods().sendGroupLocationMessage(
                    widget.groupId,
                    position.latitude,
                    position.longitude,
                  );
                },
              ),
              _buildAttachmentIcon(Icons.poll_rounded, Colors.teal, "Poll", () {
                Navigator.pop(ctx);
                _showCreatePollDialog();
              }),
              _buildAttachmentIcon(
                Icons.warning_amber_rounded,
                Colors.redAccent,
                "Emergency",
                () {
                  Navigator.pop(ctx);
                  _sendEmergencyAlert();
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
            backgroundColor: color.withAlpha(38),
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
    String senderName,
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
                children: emojis
                    .map(
                      (emoji) => InkWell(
                        onTap: () async {
                          Navigator.pop(context);
                          await FirestoreMethods().updateGroupMessageReaction(
                            widget.groupId,
                            messageId,
                            emoji,
                          );
                        },
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const Divider(height: 20),
              if (messageType == 'text' || messageType == 'image')
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
                        'senderName': senderName,
                      };
                    });
                  },
                ),
              if (amIAdmin &&
                  (messageType == 'text' || messageType == 'emergency'))
                ListTile(
                  leading: const Icon(
                    Icons.push_pin_rounded,
                    color: Colors.orangeAccent,
                  ),
                  title: const Text(
                    'Pin Message',
                    style: TextStyle(
                      color: Colors.orangeAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await FirestoreMethods().pinGroupMessage(
                      widget.groupId,
                      msgText,
                    );
                  },
                ),
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
                  await FirestoreMethods().deleteGroupMessage(
                    widget.groupId,
                    messageId,
                    isLastMessage,
                    forEveryone: false,
                  );
                },
              ),
              if (isMe || amIAdmin)
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
                    await FirestoreMethods().deleteGroupMessage(
                      widget.groupId,
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

  Widget _buildPollCard(
    Map<String, dynamic> data,
    String messageId,
    bool isDark,
  ) {
    List<dynamic> options = data['options'] ?? [];
    int totalVotes = options.fold(
      0,
      (acc, item) => acc + (item['votes'] as List).length,
    );

    return Container(
      width: 250,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.poll_rounded, color: Colors.teal, size: 18),
              const SizedBox(width: 5),
              Text(
                "Poll",
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            data['message'],
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(options.length, (index) {
            List votes = options[index]['votes'];
            double percent = totalVotes == 0 ? 0 : votes.length / totalVotes;
            bool iVoted = votes.contains(currentUid);
            return GestureDetector(
              onTap: () => FirestoreMethods().voteOnPoll(
                widget.groupId,
                messageId,
                index,
              ),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                height: 35,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  children: [
                    FractionallySizedBox(
                      widthFactor: percent,
                      child: Container(
                        decoration: BoxDecoration(
                          color: iVoted
                              ? Colors.teal.withAlpha(100)
                              : Colors.blueAccent.withAlpha(50),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            options[index]['option'],
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontWeight: iVoted
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          Text(
                            "${(percent * 100).toInt()}%",
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          Text(
            "$totalVotes Votes",
            style: const TextStyle(color: Colors.grey, fontSize: 11),
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
        if (await canLaunchUrl(Uri.parse(fileUrl)))
          await launchUrl(
            Uri.parse(fileUrl),
            mode: LaunchMode.externalApplication,
          );
      },
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.white.withAlpha(50)
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
        if (await canLaunchUrl(Uri.parse(locationUrl)))
          await launchUrl(
            Uri.parse(locationUrl),
            mode: LaunchMode.externalApplication,
          );
      },
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.white.withAlpha(50)
              : (isDark ? Colors.grey[800] : Colors.grey[300]),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.green.withAlpha(50),
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

  void _handleCallClicked(String type) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Banjara $type Calls coming soon! 🚀"),
        backgroundColor: Colors.blueAccent,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[50],
      appBar: AppBar(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        elevation: 0.5,
        iconTheme: IconThemeData(color: textColor),
        titleSpacing: 0,
        title: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FullScreenImageViewer(
                    imageUrl: widget.groupPic,
                    tag: 'group_pic_${widget.groupId}',
                  ),
                ),
              ),
              child: Hero(
                tag: 'group_pic_${widget.groupId}',
                child: CircleAvatar(
                  radius: 18,
                  backgroundImage: NetworkImage(widget.groupPic),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GroupInfoScreen(
                      groupId: widget.groupId,
                      groupName: widget.groupName,
                      groupPic: widget.groupPic,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.groupName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Text(
                      'Tap here for group info',
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam_rounded, color: Colors.blueAccent),
            onPressed: () => _handleCallClicked("Video"),
          ),
          IconButton(
            icon: const Icon(Icons.call_rounded, color: Colors.blueAccent),
            onPressed: () => _handleCallClicked("Audio"),
          ),
          if (amIAdmin)
            IconButton(
              icon: Icon(
                isAdminOnly
                    ? Icons.speaker_notes_off_rounded
                    : Icons.campaign_rounded,
                color: isAdminOnly ? Colors.redAccent : Colors.grey,
              ),
              tooltip: "Admin-Only Mode",
              onPressed: () {
                FirestoreMethods().toggleAdminOnlyMode(
                  widget.groupId,
                  !isAdminOnly,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isAdminOnly
                          ? "Anyone can message now"
                          : "Only Admins can message now 🔇",
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          if (pinnedMessage != null && pinnedMessage!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.blue.withAlpha(20),
                border: Border(
                  bottom: BorderSide(color: Colors.grey.withAlpha(50)),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.push_pin_rounded,
                    color: Colors.orangeAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      pinnedMessage!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.black87,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  if (amIAdmin)
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.grey,
                      ),
                      onPressed: () => FirestoreMethods().pinGroupMessage(
                        widget.groupId,
                        "",
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _groupMessagesStream, // 🌟 THE FIX: మెమరీలో ఉన్న స్ట్రీమ్
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.blueAccent),
                  );
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                  return const Center(
                    child: Text(
                      '👋 Welcome to Group Chat!\nSay hi to everyone.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  );

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
                    String reactionEmoji = data['reaction'] ?? '';
                    String fileName = data['fileName'] ?? 'Document';
                    Map<String, dynamic>? repliedTo = data['repliedTo'];
                    bool isLastMessage = index == 0;

                    bool isImage = messageType == 'image';
                    bool isAudio = messageType == 'audio';
                    bool isDocument = messageType == 'document';
                    bool isLocation = messageType == 'location';
                    bool isEmergency = messageType == 'emergency';
                    bool isPoll = messageType == 'poll';

                    Color bubbleColor = isEmergency
                        ? Colors.redAccent
                        : (isMe
                              ? Colors.blueAccent
                              : (isDark ? Colors.grey[850]! : Colors.white));

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(data['senderId'])
                            .get(),
                        builder: (context, userSnap) {
                          String senderName = "User";
                          if (userSnap.hasData && userSnap.data!.exists)
                            senderName =
                                (userSnap.data!.data()
                                    as Map<String, dynamic>)['username'] ??
                                'User';

                          return GestureDetector(
                            onLongPress: () => _showMessageOptions(
                              doc.id,
                              isMe,
                              isLastMessage,
                              messageText,
                              senderName,
                              messageType,
                            ),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  padding:
                                      (isImage ||
                                          isAudio ||
                                          isDocument ||
                                          isLocation ||
                                          isPoll)
                                      ? EdgeInsets.zero
                                      : const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width *
                                        0.75,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        (isImage ||
                                            isAudio ||
                                            isDocument ||
                                            isLocation ||
                                            isPoll)
                                        ? Colors.transparent
                                        : bubbleColor,
                                    boxShadow:
                                        (isImage ||
                                            isAudio ||
                                            isDocument ||
                                            isLocation ||
                                            isPoll)
                                        ? []
                                        : [
                                            BoxShadow(
                                              color: Colors.black.withAlpha(10),
                                              blurRadius: 2,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(12),
                                      topRight: const Radius.circular(12),
                                      bottomLeft: Radius.circular(
                                        isMe ? 12 : 0,
                                      ),
                                      bottomRight: Radius.circular(
                                        isMe ? 0 : 12,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!isMe && !isPoll)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 4.0,
                                            left: 2,
                                            top: 2,
                                          ),
                                          child: Text(
                                            senderName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                              color: isEmergency
                                                  ? Colors.white
                                                  : (isDark
                                                        ? Colors.blue[300]
                                                        : Colors.blue[700]),
                                            ),
                                          ),
                                        ),
                                      if (repliedTo != null)
                                        _buildReplyQuoteWidget(
                                          repliedTo,
                                          isDark,
                                        ),
                                      if (isImage)
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: CachedNetworkImage(
                                            // 🌟 Cache
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
                                      else if (isAudio)
                                        Card(
                                          color: bubbleColor,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          margin: EdgeInsets.zero,
                                          child: VoicePlayerBubble(
                                            audioUrl: messageText,
                                            isMe: isMe,
                                          ),
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
                                      else if (isPoll)
                                        _buildPollCard(data, doc.id, isDark)
                                      else if (isEmergency)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.warning_amber_rounded,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                messageText,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      else
                                        Text(
                                          messageText,
                                          style: TextStyle(
                                            color: isMe
                                                ? Colors.white
                                                : (isDark
                                                      ? Colors.white
                                                      : Colors.black87),
                                            fontSize: 15,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (reactionEmoji.isNotEmpty)
                                  Positioned(
                                    bottom: 0,
                                    right: isMe ? 20 : null,
                                    left: !isMe ? 20 : null,
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.grey[850]
                                            : Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withAlpha(25),
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
                          );
                        },
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
          if (isAdminOnly && !amIAdmin)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              color: isDark ? Colors.grey[900] : Colors.grey[200],
              alignment: Alignment.center,
              child: const Text(
                "Only admins can send messages",
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.add_circle_outline_rounded,
                        size: 28,
                        color: Colors.grey[600],
                      ),
                      onPressed: _showAttachmentsMenu,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        decoration: InputDecoration(
                          hintText: _isRecording
                              ? 'Recording audio... 🎙️'
                              : 'Message Group...',
                          hintStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: isDark ? Colors.grey[900] : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide(
                              color: Colors.grey.withAlpha(50),
                            ),
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
                            onLongPressStart: (_) => _startGroupRecording(),
                            onLongPressEnd: (_) => _stopGroupRecording(),
                            child: CircleAvatar(
                              radius: 22,
                              backgroundColor: _isRecording
                                  ? Colors.redAccent
                                  : Colors.blueAccent,
                              child: Icon(
                                _isRecording ? Icons.mic : Icons.mic_none,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          )
                        : CircleAvatar(
                            radius: 22,
                            backgroundColor: Colors.blueAccent,
                            child: IconButton(
                              icon: const Icon(
                                Icons.send,
                                color: Colors.white,
                                size: 20,
                              ),
                              onPressed: _sendGroupMsg,
                            ),
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

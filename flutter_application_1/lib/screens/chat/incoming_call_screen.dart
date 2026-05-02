import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/safe_elements.dart';
import 'call_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  final String callId;
  final String callerName;
  final String callerPic;
  final bool isVideoCall;
  final String channelId;
  final bool isGroupCall; // 🌟 కొత్తగా యాడ్ చేశాం

  const IncomingCallScreen({
    super.key,
    required this.callId,
    required this.callerName,
    required this.callerPic,
    required this.isVideoCall,
    required this.channelId,
    this.isGroupCall = false, // 🌟 డిఫాల్ట్ సెట్టింగ్
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  void _acceptCall() async {
    await FirebaseFirestore.instance
        .collection('calls')
        .doc(widget.callId)
        .update({'status': 'accepted'});
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CallScreen(
            channelName: widget.channelId,
            isVideoCall: widget.isVideoCall,
            isGroupCall:
                widget.isGroupCall, // 🌟 THE FIX: ఇక్కడ పాస్ చేస్తున్నాం
          ),
        ),
      );
    }
  }

  void _rejectCall() async {
    await FirebaseFirestore.instance
        .collection('calls')
        .doc(widget.callId)
        .update({'status': 'rejected'});
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Column(
              children: [
                Text(
                  widget.isVideoCall
                      ? "Incoming Video Call..."
                      : "Incoming Voice Call...",
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 18,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 30),
                SafeProfilePic(
                  base64String: widget.callerPic,
                  radius: 70,
                  fallbackText: widget.callerName.isNotEmpty
                      ? widget.callerName[0].toUpperCase()
                      : 'U',
                ),
                const SizedBox(height: 20),
                Text(
                  widget.callerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: _rejectCall,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.call_end,
                          color: Colors.white,
                          size: 35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Decline",
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _acceptCall,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.call,
                          color: Colors.white,
                          size: 35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Accept",
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// lib/screens/calls/call_screen.dart

import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

class CallScreen extends StatefulWidget {
  final String channelId;
  final bool isVideoCall;
  final String targetName;

  const CallScreen({
    super.key,
    required this.channelId,
    required this.isVideoCall,
    required this.targetName,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  // 🌟 అగోరా వెబ్‌సైట్ నుండి వచ్చే మీ App ID ఇక్కడ పెట్టాలి బాస్
  final String appId = "YOUR_AGORA_APP_ID_HERE"; 
  
  int? _remoteUid;
  bool _localUserJoined = false;
  bool _isMuted = false;
  bool _isCameraOff = false;
  late RtcEngine _engine;

  @override
  void initState() {
    super.initState();
    initAgora();
  }

  Future<void> initAgora() async {
    // కెమెరా, మైక్ పర్మిషన్స్ అడగడం
    await [Permission.microphone, Permission.camera].request();

    // ఇంజిన్ క్రియేట్ చేయడం
    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(
      appId: appId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint("Local user ${connection.localUid} joined");
          setState(() {
            _localUserJoined = true;
          });
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint("Remote user $remoteUid joined");
          setState(() {
            _remoteUid = remoteUid;
          });
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          debugPrint("Remote user $remoteUid left channel");
          setState(() {
            _remoteUid = null;
          });
          Navigator.pop(context); // అవతలి వ్యక్తి కట్ చేస్తే స్క్రీన్ క్లోజ్ అవుతుంది
        },
      ),
    );

    if (widget.isVideoCall) {
      await _engine.enableVideo();
      await _engine.startPreview();
    } else {
      await _engine.enableAudio();
    }

    // ఛానల్ లో జాయిన్ అవ్వడం (టెస్టింగ్ కోసం టోకెన్ అవసరం లేదు, లైవ్ కి వెళ్ళినప్పుడు ఫైర్‌బేస్ నుండి టోకెన్ లాగాలి)
    await _engine.joinChannel(
      token: '',
      channelId: widget.channelId,
      uid: 0,
      options: const ChannelMediaOptions(),
    );
  }

  @override
  void dispose() {
    _disposeAgora();
    super.dispose();
  }

  Future<void> _disposeAgora() async {
    await _engine.leaveChannel();
    await _engine.release();
  }

  void _onToggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    _engine.muteLocalAudioStream(_isMuted);
  }

  void _onToggleCamera() {
    if (!widget.isVideoCall) return;
    setState(() {
      _isCameraOff = !_isCameraOff;
    });
    _engine.muteLocalVideoStream(_isCameraOff);
  }

  void _onSwitchCamera() {
    if (!widget.isVideoCall) return;
    _engine.switchCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 📺 వీడియో స్క్రీన్ వ్యూస్
          Center(
            child: widget.isVideoCall ? _videoView() : _audioView(),
          ),
          
          // 📱 కాలింగ్ కంట్రోల్స్ (ముందు వెనుక కెమెరా, మ్యూట్, ఎండ్ కాల్)
          Positioned(
            bottom: 40, left: 0, right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CircleAvatar(
                  radius: 24, backgroundColor: _isMuted ? Colors.red : Colors.white24,
                  child: IconButton(icon: Icon(_isMuted ? Icons.mic_off : Icons.mic, color: Colors.white), onPressed: _onToggleMute),
                ),
                CircleAvatar(
                  radius: 30, backgroundColor: Colors.red,
                  child: IconButton(icon: const Icon(Icons.call_end, color: Colors.white, size: 28), onPressed: () => Navigator.pop(context)),
                ),
                if (widget.isVideoCall) ...[
                  CircleAvatar(
                    radius: 24, backgroundColor: _isCameraOff ? Colors.red : Colors.white24,
                    child: IconButton(icon: Icon(_isCameraOff ? Icons.videocam_off : Icons.videocam, color: Colors.white), onPressed: _onToggleCamera),
                  ),
                  CircleAvatar(
                    radius: 24, backgroundColor: Colors.white24,
                    child: IconButton(icon: const Icon(Icons.switch_camera, color: Colors.white), onPressed: _onSwitchCamera),
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 📹 వీడియో కాల్ లేఅవుట్ డిజైన్
  Widget _videoView() {
    return Stack(
      children: [
        Center(
          child: _remoteUid != null
              ? AgoraVideoView(controller: VideoViewController.remote(rtcEngine: _engine, canvas: VideoCanvas(uid: _remoteUid), connection: RtcConnection(channelId: widget.channelId)))
              : Text("Calling ${widget.targetName}... 📞", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500)),
        ),
        if (_localUserJoined && !_isCameraOff)
          Positioned(
            top: 40, right: 20, width: 110, height: 150,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AgoraVideoView(controller: VideoViewController(rtcEngine: _engine, canvas: const VideoCanvas(uid: 0))),
            ),
          ),
      ],
    );
  }

  // 🔊 ఆడియో కాల్ లేఅవుట్ డిజైన్
  Widget _audioView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 50, backgroundColor: Colors.blueAccent.withValues(alpha: 0.2),
          child: const Icon(Icons.person, size: 60, color: Colors.blueAccent),
        ),
        const SizedBox(height: 25),
        Text(widget.targetName, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Text(_remoteUid != null ? "Connected 🟢" : "Ringing... 🔔", style: const TextStyle(color: Colors.grey, fontSize: 15)),
      ],
    );
  }
}
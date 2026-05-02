import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import '../../services/fcm_sender_service.dart';

class CallScreen extends StatefulWidget {
  final String channelName;
  final bool isVideoCall;
  final bool isGroupCall; // 🌟 యాడ్ చేశాం

  const CallScreen({
    super.key,
    required this.channelName,
    this.isVideoCall = true,
    this.isGroupCall = false,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  // 🌟 మీ ఆగోరా App ID (Testing Mode)
  final String appId = "e6cb84377d584afe8852fb6ed2e20818";
  final String token = "";

  final List<int> _remoteUids = [];
  bool _localUserJoined = false;
  bool _muted = false;
  late RtcEngine _engine;

  StreamSubscription? _callSubscription;
  StreamSubscription? _fcmSubscription;
  Timer? _ringingTimer;

  @override
  void initState() {
    super.initState();
    initAgora();

    _callSubscription = FirebaseFirestore.instance
        .collection('calls')
        .doc(widget.channelName)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists) {
            String status = snapshot.data()?['status'] ?? '';
            if (!widget.isGroupCall &&
                (status == 'ended' ||
                    status == 'declined' ||
                    status == 'rejected')) {
              _closeScreenInstantly();
            }
          }
        });

    _fcmSubscription = FirebaseMessaging.onMessage.listen((
      RemoteMessage message,
    ) {
      if (!widget.isGroupCall && message.data['type'] == 'end_call') {
        _closeScreenInstantly();
      }
    });

    _ringingTimer = Timer(const Duration(seconds: 35), () {
      if (_remoteUids.isEmpty && mounted) {
        _onCallEnd();
      }
    });
  }

  void _closeScreenInstantly() {
    FlutterCallkitIncoming.endAllCalls();
    if (mounted) Navigator.pop(context);
  }

  Future<void> initAgora() async {
    await [Permission.microphone, Permission.camera].request();

    _engine = createAgoraRtcEngine();

    // 🌟 THE FIX 1: Communication బదులు LiveBroadcasting వాడాలి
    await _engine.initialize(
      RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ),
    );
    // 🌟 THE FIX 2: అందరినీ Broadcaster గా సెట్ చేయాలి
    await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onError: (ErrorCodeType err, String msg) {
          debugPrint("❌ Agora Error: $err - $msg");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Agora Error: $msg"),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          setState(() => _localUserJoined = true);
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          setState(() {
            if (!widget.isGroupCall) _remoteUids.clear();
            if (!_remoteUids.contains(remoteUid)) _remoteUids.add(remoteUid);
          });
          _ringingTimer?.cancel();
        },
        onUserOffline:
            (
              RtcConnection connection,
              int remoteUid,
              UserOfflineReasonType reason,
            ) {
              setState(() {
                _remoteUids.remove(remoteUid);
              });
              if (!widget.isGroupCall && _remoteUids.isEmpty) {
                _closeScreenInstantly();
              }
            },
      ),
    );

    if (widget.isVideoCall) {
      await _engine.enableVideo();
      await _engine.startPreview();
    } else {
      await _engine.disableVideo();
    }

    ChannelMediaOptions options = const ChannelMediaOptions(
      autoSubscribeVideo: true,
      autoSubscribeAudio: true,
      publishCameraTrack: true,
      publishMicrophoneTrack: true,
      clientRoleType: ClientRoleType.clientRoleBroadcaster,
    );

    await _engine.joinChannel(
      token: token,
      channelId: widget.channelName,
      uid: 0,
      options: options,
    );
  }

  @override
  void dispose() {
    _callSubscription?.cancel();
    _fcmSubscription?.cancel();
    _ringingTimer?.cancel();
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  void _onToggleMute() {
    setState(() => _muted = !_muted);
    _engine.muteLocalAudioStream(_muted);
  }

  void _onSwitchCamera() => _engine.switchCamera();

  void _onCallEnd() async {
    if (widget.isGroupCall) {
      _closeScreenInstantly();
    } else {
      await FirebaseFirestore.instance
          .collection('calls')
          .doc(widget.channelName)
          .set({'status': 'ended'}, SetOptions(merge: true));
      String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      var callDoc = await FirebaseFirestore.instance
          .collection('calls')
          .doc(widget.channelName)
          .get();
      if (callDoc.exists) {
        String callerId = callDoc.data()?['callerId'] ?? '';
        String receiverId = callDoc.data()?['receiverId'] ?? '';
        String otherUserId = (currentUid == callerId) ? receiverId : callerId;
        FcmSenderService.sendEndCallSignal(
          receiverId: otherUserId,
          channelId: widget.channelName,
        );
      }
      _closeScreenInstantly();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(child: _remoteVideo()),
            if (widget.isVideoCall)
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Container(
                    width: 110,
                    height: 150,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _localUserJoined
                          ? AgoraVideoView(
                              controller: VideoViewController(
                                rtcEngine: _engine,
                                canvas: const VideoCanvas(uid: 0),
                              ),
                            )
                          : const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            _toolbar(),
          ],
        ),
      ),
    );
  }

  Widget _remoteVideo() {
    if (_remoteUids.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.blueAccent),
          const SizedBox(height: 20),
          Text(
            widget.isGroupCall
                ? 'Waiting for others to join ⏳'
                : 'Ringing... Waiting to join ⏳',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
        ],
      );
    }

    if (widget.isVideoCall) {
      if (widget.isGroupCall) {
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _remoteUids.length > 2 ? 2 : 1,
            childAspectRatio: 0.8,
          ),
          itemCount: _remoteUids.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.all(2.0),
              child: AgoraVideoView(
                controller: VideoViewController.remote(
                  rtcEngine: _engine,
                  canvas: VideoCanvas(uid: _remoteUids[index]),
                  connection: RtcConnection(channelId: widget.channelName),
                ),
              ),
            );
          },
        );
      } else {
        return AgoraVideoView(
          controller: VideoViewController.remote(
            rtcEngine: _engine,
            canvas: VideoCanvas(uid: _remoteUids.first),
            connection: RtcConnection(channelId: widget.channelName),
          ),
        );
      }
    } else {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            widget.isGroupCall ? Icons.group : Icons.person,
            size: 120,
            color: Colors.white54,
          ),
          const SizedBox(height: 20),
          Text(
            widget.isGroupCall
                ? "Group Voice Call 📞\n(${_remoteUids.length} Active)"
                : "Voice Call Connected 📞",
            style: const TextStyle(color: Colors.white, fontSize: 20),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }
  }

  Widget _toolbar() {
    return Container(
      alignment: Alignment.bottomCenter,
      padding: const EdgeInsets.only(bottom: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          RawMaterialButton(
            onPressed: _onToggleMute,
            shape: const CircleBorder(),
            elevation: 2.0,
            fillColor: _muted ? Colors.blueAccent : Colors.grey[800],
            padding: const EdgeInsets.all(12.0),
            child: Icon(
              _muted ? Icons.mic_off : Icons.mic,
              color: Colors.white,
              size: 24.0,
            ),
          ),
          const SizedBox(width: 15),
          RawMaterialButton(
            onPressed: _onCallEnd,
            shape: const CircleBorder(),
            elevation: 2.0,
            fillColor: Colors.redAccent,
            padding: const EdgeInsets.all(18.0),
            child: const Icon(Icons.call_end, color: Colors.white, size: 35.0),
          ),
          const SizedBox(width: 15),
          if (widget.isVideoCall)
            RawMaterialButton(
              onPressed: _onSwitchCamera,
              shape: const CircleBorder(),
              elevation: 2.0,
              fillColor: Colors.grey[800],
              padding: const EdgeInsets.all(12.0),
              child: const Icon(
                Icons.flip_camera_ios,
                color: Colors.white,
                size: 24.0,
              ),
            )
          else
            const SizedBox(width: 50),
        ],
      ),
    );
  }
}

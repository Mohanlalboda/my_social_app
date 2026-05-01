import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

class CallScreen extends StatefulWidget {
  final String channelName; // ఇది మన ఫైర్‌బేస్ చాట్ రూమ్ ఐడీ (roomId)
  final bool isVideoCall; // వీడియో కాలా? ఆడియో కాలా?

  const CallScreen({
    super.key,
    required this.channelName,
    this.isVideoCall = true,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  // 🌟 ఇక్కడ మీరు కాపీ చేసిన అగోరా App ID వేయండి (కోటేషన్స్ మధ్యలో)
  final String appId = "e6cb84377d584afe8852fb6ed2e20818";
  final String token = ""; // టెస్టింగ్ మోడ్ అయితే ఇది ఖాళీగా వదిలేయండి

  int? _remoteUid;
  bool _localUserJoined = false;
  bool _muted = false;
  late RtcEngine _engine;

  @override
  void initState() {
    super.initState();
    initAgora();
  }

  Future<void> initAgora() async {
    // 1. పర్మిషన్స్ అడగడం
    await [Permission.microphone, Permission.camera].request();

    // 2. ఆగోరా ఇంజిన్ స్టార్ట్ చేయడం
    _engine = createAgoraRtcEngine();
    await _engine.initialize(
      RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );

    // 3. ఎవరు కాల్ లిఫ్ట్ చేశారు, కట్ చేశారు అని ట్రాక్ చేయడానికి
    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint("Local user ${connection.localUid} joined");
          setState(() => _localUserJoined = true);
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint("Remote user $remoteUid joined");
          setState(() => _remoteUid = remoteUid);
        },
        onUserOffline:
            (
              RtcConnection connection,
              int remoteUid,
              UserOfflineReasonType reason,
            ) {
              debugPrint("Remote user $remoteUid left channel");
              setState(() => _remoteUid = null);
              // అవతలి వాళ్ళు కాల్ కట్ చేస్తే మనం కూడా బ్యాక్ కి వెళ్ళిపోవాలి
              Navigator.pop(context);
            },
      ),
    );

    // 4. వీడియో కాలా లేక ఆడియో కాలా అని చెక్ చేయడం
    if (widget.isVideoCall) {
      await _engine.enableVideo();
      await _engine.startPreview();
    } else {
      await _engine.disableVideo();
    }

    // 5. కాల్ రూమ్ లోకి ఎంటర్ అవ్వడం
    await _engine.joinChannel(
      token: token.isEmpty ? "" : token,
      channelId: widget.channelName,
      uid: 0,
      options: const ChannelMediaOptions(),
    );
  }

  @override
  void dispose() {
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  void _onToggleMute() {
    setState(() => _muted = !_muted);
    _engine.muteLocalAudioStream(_muted);
  }

  void _onSwitchCamera() {
    _engine.switchCamera();
  }

  void _onCallEnd(BuildContext context) {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // అవతలి వాళ్ళ వీడియో
            Center(child: _remoteVideo()),

            // మన చిన్న వీడియో (పైన కుడి మూల)
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

            // కింద బటన్స్ (కట్ చేయడం, మ్యూట్ చేయడం)
            _toolbar(),
          ],
        ),
      ),
    );
  }

  Widget _remoteVideo() {
    if (_remoteUid != null) {
      if (widget.isVideoCall) {
        return AgoraVideoView(
          controller: VideoViewController.remote(
            rtcEngine: _engine,
            canvas: VideoCanvas(uid: _remoteUid),
            connection: RtcConnection(channelId: widget.channelName),
          ),
        );
      } else {
        return const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person, size: 120, color: Colors.white54),
            SizedBox(height: 20),
            Text(
              "Voice Call Connected 📞",
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
            Text("00:00", style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        );
      }
    } else {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.blueAccent),
          SizedBox(height: 20),
          Text(
            'Ringing... Waiting to join ⏳',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 18),
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
          // మ్యూట్ బటన్
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

          // కాల్ కట్ బటన్
          RawMaterialButton(
            onPressed: () => _onCallEnd(context),
            shape: const CircleBorder(),
            elevation: 2.0,
            fillColor: Colors.redAccent,
            padding: const EdgeInsets.all(18.0),
            child: const Icon(Icons.call_end, color: Colors.white, size: 35.0),
          ),
          const SizedBox(width: 15),

          // కెమెరా మార్చే బటన్
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

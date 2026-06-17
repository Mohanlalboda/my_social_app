// lib/widgets/voice_player_bubble.dart

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class VoicePlayerBubble extends StatefulWidget {
  final String audioUrl;
  final bool isMe;

  const VoicePlayerBubble({
    super.key,
    required this.audioUrl,
    required this.isMe,
  });

  @override
  State<VoicePlayerBubble> createState() => _VoicePlayerBubbleState();
}

class _VoicePlayerBubbleState extends State<VoicePlayerBubble> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();

    // ఆడియో ప్లేయర్ ఈవెంట్స్ ఆలకించడం 🎧
    _audioPlayer.onDurationChanged.listen((d) => setState(() => _duration = d));
    _audioPlayer.onPositionChanged.listen((p) => setState(() => _position = p));
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state == PlayerState.playing);
      }
    });
  }

  void _togglePlay() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(UrlSource(widget.audioUrl));
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose(); // మెమరీ సేవ్ చేయడానికి ప్లేయర్ డిస్పోజ్ బాస్
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _isPlaying
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_filled_rounded,
              color: widget.isMe ? Colors.white : Colors.blueAccent,
              size: 36,
            ),
            onPressed: _togglePlay,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: _duration.inMilliseconds > 0
                      ? _position.inMilliseconds / _duration.inMilliseconds
                      : 0.0,
                  backgroundColor: widget.isMe
                      ? Colors.white30
                      : Colors.black12,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    widget.isMe ? Colors.white : Colors.blueAccent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isPlaying
                      ? "${_position.inMinutes}:${(_position.inSeconds % 60).toString().padLeft(2, '0')}"
                      : "Voice Note 🎙️",
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.isMe ? Colors.white70 : Colors.black54,
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

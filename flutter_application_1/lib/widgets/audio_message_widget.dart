import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

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
    _initPlayer();
  }

  // 🌟 ప్లేయర్ సెట్టింగ్స్ ని ఒకే దగ్గర మేనేజ్ చేయడం
  void _initPlayer() {
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
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
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
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      width: MediaQuery.of(context).size.width * 0.6,
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
              size: 35,
              color: widget.isMe
                  ? (isDark ? Colors.greenAccent : Colors.green[800])
                  : (isDark ? Colors.lightBlue : Colors.blue),
            ),
            onPressed: () async {
              try {
                if (_isPlaying) {
                  await _audioPlayer.pause();
                } else {
                  // 🌟 మ్యాజిక్: ఆడియో ప్లే చేసేటప్పుడు UrlSource ని వాడుతున్నాం
                  await _audioPlayer.play(UrlSource(widget.audioUrl));
                }
              } catch (e) {
                debugPrint("Audio Play Error: $e");
              }
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
                        ? (isDark ? Colors.greenAccent[700] : Colors.green[700])
                        : (isDark ? Colors.lightBlue : Colors.blue),
                    inactiveTrackColor: isDark
                        ? Colors.grey[600]
                        : Colors.grey[400],
                    thumbColor: widget.isMe
                        ? (isDark ? Colors.greenAccent : Colors.green[800])
                        : (isDark ? Colors.lightBlue : Colors.blue),
                  ),
                  child: Slider(
                    min: 0,
                    // 🌟 Safety: Duration కనీసం 1 సెకన్ ఉండేలా చూడాలి
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
                      // 🌟 THE FIX: ఆడియో డ్యూరేషన్ ఉంటేనే Seek చేయాలి
                      if (_duration.inSeconds > 0) {
                        try {
                          await _audioPlayer.seek(
                            Duration(seconds: val.toInt()),
                          );
                        } catch (e) {
                          debugPrint("Seek Error: $e");
                        }
                      }
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Text(
                    _formatTime(_position),
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
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

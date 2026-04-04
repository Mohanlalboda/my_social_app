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
    // 🌟 మ్యాజిక్: ఇక్కడ డార్క్ మోడ్/లైట్ మోడ్ కి తగ్గట్టు కలర్స్ మారతాయి
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
              // 🌟 డైనమిక్ కలర్స్ అప్‌డేట్
              color: widget.isMe
                  ? (isDark ? Colors.greenAccent : Colors.green[800])
                  : (isDark ? Colors.lightBlue : Colors.blue),
            ),
            onPressed: () async {
              if (_isPlaying) {
                await _audioPlayer.pause();
              } else {
                await _audioPlayer.play(UrlSource(widget.audioUrl));
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
                    // 🌟 స్లయిడర్ ట్రాక్ కలర్ అప్‌డేట్
                    activeTrackColor: widget.isMe
                        ? (isDark ? Colors.greenAccent[700] : Colors.green[700])
                        : (isDark ? Colors.lightBlue : Colors.blue),
                    inactiveTrackColor: isDark
                        ? Colors.grey[600]
                        : Colors.grey[400],
                    // 🌟 స్లయిడర్ బటన్ (Thumb) కలర్ అప్‌డేట్
                    thumbColor: widget.isMe
                        ? (isDark ? Colors.greenAccent : Colors.green[800])
                        : (isDark ? Colors.lightBlue : Colors.blue),
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
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark
                          ? Colors.grey[400]
                          : Colors.grey[700], // 🌟 టైమ్ కలర్ అప్‌డేట్
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

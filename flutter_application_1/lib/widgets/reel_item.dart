import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class ReelItem extends StatefulWidget {
  final Map<String, dynamic> reelData;
  const ReelItem({super.key, required this.reelData});

  @override
  State<ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isLiked = false; // 🌟 లైక్ యానిమేషన్ కోసం

  @override
  void initState() {
    super.initState();
    _controller =
        VideoPlayerController.networkUrl(Uri.parse(widget.reelData['videoUrl']))
          ..initialize()
              .then((_) {
                setState(() {
                  _isInitialized = true;
                });
                _controller.setLooping(true);
                _controller.play();
              })
              .catchError((e) {
                debugPrint("🚨 Reel Play Error: $e");
              });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 📺 1. ఫుల్ స్క్రీన్ వీడియో ప్లేయర్ (Black borders లేకుండా)
        _isInitialized
            ? GestureDetector(
                onTap: () {
                  setState(() {
                    _controller.value.isPlaying
                        ? _controller.pause()
                        : _controller.play();
                  });
                },
                child: SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit
                        .cover, // 🌟 స్క్రీన్ మొత్తం నిండిపోయేలా చేస్తుంది
                    child: SizedBox(
                      width: _controller.value.size.width,
                      height: _controller.value.size.height,
                      child: VideoPlayer(_controller),
                    ),
                  ),
                ),
              )
            : const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),

        // ⬛ 2. కింది వైపు బ్లాక్ షాడో (టెక్స్ట్ స్పష్టంగా కనిపించడానికి)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: MediaQuery.of(context).size.height * 0.4,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.8),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // 🔘 3. రైట్ సైడ్ బటన్స్ (లైక్, కామెంట్, షేర్)
        Positioned(
          bottom: 20,
          right: 15,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildActionIcon(
                icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                color: _isLiked ? Colors.red : Colors.white,
                label: "1.2k", // తర్వాత డేటాబేస్ నుండి మార్చుకోవచ్చు
                onTap: () => setState(() => _isLiked = !_isLiked),
              ),
              const SizedBox(height: 20),
              _buildActionIcon(
                icon: Icons.chat_bubble_outline,
                color: Colors.white,
                label: "120",
                onTap: () {},
              ),
              const SizedBox(height: 20),
              _buildActionIcon(
                icon: Icons.send_outlined,
                color: Colors.white,
                label: "Share",
                onTap: () {},
              ),
              const SizedBox(height: 20),
              const Icon(Icons.more_vert, color: Colors.white, size: 30),
              const SizedBox(height: 20),
              // మ్యూజిక్ రొటేటింగ్ ఐకాన్
              Container(
                height: 35,
                width: 35,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade800,
                ),
                child: const Icon(
                  Icons.music_note,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ),

        // ✍️ 4. లెఫ్ట్ సైడ్ యూజర్ డీటెయిల్స్ & క్యాప్షన్
        Positioned(
          bottom: 20,
          left: 15,
          right: 80, // కుడి వైపు బటన్స్ కి తగలకుండా
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ప్రొఫైల్ పిక్ + పేరు + ఫాలో బటన్
              Row(
                children: [
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.grey,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.reelData['username'] ?? 'User',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 1.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "Follow",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // క్యాప్షన్
              Text(
                widget.reelData['caption'] ?? '',
                style: const TextStyle(color: Colors.white, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              // ఆడియో పేరు
              const Row(
                children: [
                  Icon(Icons.music_note, color: Colors.white, size: 16),
                  SizedBox(width: 5),
                  Text(
                    "Original Audio",
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // బటన్స్ ఈజీగా క్రియేట్ చేయడానికి ఒక చిన్న విడ్జెట్
  Widget _buildActionIcon({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

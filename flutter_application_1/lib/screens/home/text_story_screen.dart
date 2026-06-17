// lib/screens/home/text_story_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/firestore_methods.dart';

class TextStoryScreen extends StatefulWidget {
  const TextStoryScreen({super.key});

  @override
  State<TextStoryScreen> createState() => _TextStoryScreenState();
}

class _TextStoryScreenState extends State<TextStoryScreen> {
  final TextEditingController _textController = TextEditingController();
  bool _isLoading = false;

  // 🎨 1. బాస్ కోరుకున్న బ్యూటిఫుల్ గ్రేడియంట్ బ్యాక్‌గ్రౌండ్స్ లిస్ట్
  final List<List<Color>> _gradients = [
    [
      const Color(0xFF833AB4),
      const Color(0xFFFD1D1D),
      const Color(0xFFF56040),
    ], // Instagram Classic
    [Colors.purple, Colors.deepPurple, Colors.blue],
    [Colors.teal, Colors.green, Colors.lightGreen],
    [Colors.deepOrange, Colors.orange, Colors.amber],
    [const Color(0xFF00c6ff), const Color(0xFF0072ff)], // Neon Blue
    [Colors.black, Colors.grey[900]!, Colors.black87], // Dark Luxury
  ];
  int _selectedGradientIndex = 0;

  // 🔤 2. స్టోరీ కోసం డిఫరెంట్ ప్రీమియం ఫాంట్స్ లిస్ట్ బాస్
  final List<TextStyle> _fontStyles = [
    GoogleFonts.poppins(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
    GoogleFonts.lobster(fontSize: 28, color: Colors.white),
    GoogleFonts.dancingScript(
      fontSize: 30,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
    GoogleFonts.bungee(fontSize: 22, color: Colors.white),
  ];
  int _selectedFontIndex = 0;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  // 🚀 టెక్స్ట్ స్టోరీని బ్యాకెండ్‌లోకి పంపించే అల్టిమేట్ మెథడ్ బాస్
  void _publishTextStory() async {
    String text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isLoading = true);

    // ఇక్కడ మనం ఎంచుకున్న గ్రేడియంట్ కలర్స్‌ను స్ట్రింగ్ ఫార్మాట్‌లోకి మార్చి పంపుతాం బాస్
    String bgColorsString = _gradients[_selectedGradientIndex]
        .map((c) => c.toARGB32().toRadixString(16))
        .join(',');

    // ఫాంట్ ఇండెక్స్‌ను కూడా టెక్స్ట్‌తో పాటు లేదా విడిగా ట్రాక్ చేయవచ్చు
    String res = await FirestoreMethods().uploadStory(
      null,
      "text",
      "$text|$bgColorsString|$_selectedFontIndex", // టెక్స్ట్, కలర్స్, ఫాంట్‌లను ఒకే స్ట్రింగ్‌గా ప్యాక్ చేసాం బాస్!
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res == "success") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Text status shared successfully! 🎉"),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $res ❌"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 📱 పూర్తి స్క్రీన్ గ్రేడియంట్ బ్యాక్‌గ్రౌండ్ బాస్
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _gradients[_selectedGradientIndex],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 🎛️ టాప్ యాక్షన్ బార్ (Close, Font Switch, Colors Switch)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Row(
                      children: [
                        // 🔤 ఫాంట్ మార్చే బటన్
                        IconButton(
                          icon: const Icon(
                            Icons.font_download_outlined,
                            color: Colors.white,
                            size: 26,
                          ),
                          onPressed: () {
                            setState(() {
                              _selectedFontIndex =
                                  (_selectedFontIndex + 1) % _fontStyles.length;
                            });
                          },
                        ),
                        const SizedBox(width: 10),
                        // 🎨 బ్యాక్‌గ్రౌండ్ మార్చే బటన్
                        IconButton(
                          icon: const Icon(
                            Icons.palette_outlined,
                            color: Colors.white,
                            size: 26,
                          ),
                          onPressed: () {
                            setState(() {
                              _selectedGradientIndex =
                                  (_selectedGradientIndex + 1) %
                                  _gradients.length;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ✍️ సెంటర్ టెక్స్ట్ ఇన్‌పుట్ ఏరియా బాస్
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30.0),
                    child: TextField(
                      controller: _textController,
                      maxLines: null,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.multiline,
                      autofocus: true,
                      cursorColor: Colors.white,
                      style:
                          _fontStyles[_selectedFontIndex], // డైనమిక్ ఫాంట్ స్టైల్ బాస్
                      decoration: const InputDecoration(
                        hintText: 'Type your Tanda status... ✍️',
                        hintStyle: TextStyle(
                          color: Colors.white60,
                          fontSize: 22,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
              ),

              // 🚀 బాటమ్ పబ్లిష్ బటన్
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : FloatingActionButton.extended(
                          backgroundColor: Colors.white,
                          onPressed: _publishTextStory,
                          icon: const Icon(
                            Icons.send_rounded,
                            color: Colors.blueAccent,
                          ),
                          label: const Text(
                            'Share Status',
                            style: TextStyle(
                              color: Colors.blueAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

// 🌟 మీ ఇమేజ్ నుండి తీసుకున్న కొత్త నియాన్ కలర్స్ (Neon Cyberpunk Theme)
const LinearGradient brandGradient = LinearGradient(
  colors: [
    Color(0xFF00E5FF), // Neon Cyan (గ్లోయింగ్ బ్లూ)
    Color(0xFF7A00FF), // Deep Purple (డార్క్ పర్పుల్)
    Color(0xFFFF007F), // Electric Pink (నియాన్ పింక్)
  ],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// 🌟 యాప్ బ్యాక్‌గ్రౌండ్స్ లో ఎక్కడైనా ఈ డార్క్ థీమ్ వాడాలనుకుంటే
const Color brandDarkBackground = Color(0xFF0A0A0C); // రిచ్ డార్క్ కలర్
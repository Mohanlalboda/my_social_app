import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart'; // 🌟 ఫాస్ట్ లోడింగ్ మ్యాజిక్

Uint8List? _safeDecode(String? base64String) {
  if (base64String == null || base64String.trim().isEmpty) return null;
  try {
    String cleanString = base64String;
    if (cleanString.contains(',')) cleanString = cleanString.split(',').last;
    cleanString = cleanString.replaceAll(RegExp(r'\s+'), '');
    return base64Decode(cleanString);
  } catch (e) {
    return null;
  }
}

// 👤 సేఫ్ ప్రొఫైల్ పిక్చర్ (SafeProfilePic)
class SafeProfilePic extends StatelessWidget {
  final String? base64String;
  final double radius;
  final String fallbackText;

  const SafeProfilePic({
    super.key,
    required this.base64String,
    this.radius = 20,
    this.fallbackText = "U",
  });

  @override
  Widget build(BuildContext context) {
    if (base64String == null || base64String!.isEmpty) return _buildFallback();

    // 🌟 నెట్వర్క్ లింక్ (URL) అయితే Cache చేసి ఫాస్ట్ గా లోడ్ చేస్తాం
    if (base64String!.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: base64String!,
        imageBuilder: (context, imageProvider) =>
            CircleAvatar(radius: radius, backgroundImage: imageProvider),
        placeholder: (context, url) =>
            CircleAvatar(radius: radius, backgroundColor: Colors.grey[800]),
        errorWidget: (context, url, error) => _buildFallback(),
      );
    }

    // పాత పద్ధతి (Base64 కోసం)
    Uint8List? bytes = _safeDecode(base64String);
    if (bytes == null || bytes.isEmpty) return _buildFallback();

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[800],
      backgroundImage: MemoryImage(bytes),
      onBackgroundImageError: (e, s) {},
      child: null,
    );
  }

  Widget _buildFallback() {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.blueGrey,
      child: Text(
        fallbackText.isNotEmpty ? fallbackText[0].toUpperCase() : "U",
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }
}

// 🖼️ సేఫ్ పోస్ట్ ఇమేజ్ (SafeImage)
class SafeImage extends StatelessWidget {
  final String? base64String;
  final BoxFit? fit;

  const SafeImage({
    super.key,
    required this.base64String,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (base64String == null || base64String!.isEmpty) return _buildFallback();

    // 🌟 ఇన్‌స్టాగ్రామ్ ఫీల్: ఇమేజ్ నెట్ నుండి వస్తే Cache చేసి స్పీడ్ గా చూపిస్తాం
    if (base64String!.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: base64String!,
        fit: BoxFit.contain,
        // 🌟 PRO ఫీచర్: ఇమేజ్ లోడ్ అయ్యేటప్పుడు జస్ట్ బ్లాక్ స్క్రీన్ కాకుండా ఒక చిన్న స్పిన్నర్ చూపిస్తాం
        placeholder: (context, url) => Container(
          color: Colors.grey[900],
          child: const Center(
            child: SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.blueGrey,
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) => _buildFallback(),
      );
    }

    Uint8List? bytes = _safeDecode(base64String);
    if (bytes == null || bytes.isEmpty) return _buildFallback();

    return Image.memory(
      bytes,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => _buildFallback(),
    );
  }

  Widget _buildFallback() {
    return Container(
      color: Colors.grey[900],
      child: const Center(
        child: Icon(Icons.broken_image, color: Colors.white54, size: 50),
      ),
    );
  }
}

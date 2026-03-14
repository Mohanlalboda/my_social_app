import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class SafeImage extends StatelessWidget {
  final String? base64String;
  final double? height;
  final double? width;
  final BoxFit fit;

  const SafeImage({
    super.key,
    required this.base64String,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (base64String == null || base64String!.trim().isEmpty) {
      return Container(
        height: height ?? 200,
        width: width ?? double.infinity,
        color: Colors.grey[200],
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_not_supported, color: Colors.grey, size: 40),
              SizedBox(height: 5),
              Text(
                "No Image Data",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    try {
      String cleanString = base64String!.replaceAll(RegExp(r'\s+'), '');
      int padding = cleanString.length % 4;
      if (padding != 0) {
        cleanString += '=' * (4 - padding);
      }
      Uint8List bytes = base64Decode(cleanString);

      return Image.memory(
        bytes,
        height: height,
        width: width,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: height ?? 200,
            width: width ?? double.infinity,
            color: Colors.grey[200],
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, color: Colors.grey, size: 40),
                  SizedBox(height: 5),
                  Text(
                    "Image Corrupted",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      return Container(
        height: height ?? 200,
        width: width ?? double.infinity,
        color: Colors.red[50],
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 40),
              SizedBox(height: 5),
              Text(
                "Format Error",
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }
  }
}

class SafeProfilePic extends StatelessWidget {
  final String? base64String;
  final double radius;
  final String fallbackText;

  const SafeProfilePic({
    super.key,
    required this.base64String,
    required this.radius,
    required this.fallbackText,
  });

  @override
  Widget build(BuildContext context) {
    if (base64String == null || base64String!.trim().isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.blueAccent,
        child: Text(
          fallbackText.isNotEmpty ? fallbackText[0].toUpperCase() : "?",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    try {
      String cleanString = base64String!.replaceAll(RegExp(r'\s+'), '');
      int padding = cleanString.length % 4;
      if (padding != 0) {
        cleanString += '=' * (4 - padding);
      }
      Uint8List bytes = base64Decode(cleanString);

      return CircleAvatar(
        radius: radius,
        backgroundImage: MemoryImage(bytes),
        onBackgroundImageError: (e, s) {},
      );
    } catch (e) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey[400],
        child: const Icon(Icons.person, color: Colors.white),
      );
    }
  }
}

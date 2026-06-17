// lib/utils/video_helper.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_compress/video_compress.dart';

// 🎬 రా-వీడియో సైజ్‌ను క్వాలిటీ తగ్గకుండా కంప్రెస్ చేసే అల్టిమేట్ ఇంజన్ బాస్!
Future<File?> compressVideoFile(File videoFile) async {
  try {
    debugPrint("⏳ Compression started for: ${videoFile.path}");
    MediaInfo? mediaInfo = await VideoCompress.compressVideo(
      videoFile.path,
      quality: VideoQuality
          .MediumQuality, // 🌟 క్వాలిటీ మరియు సైజ్ రెండూ పక్కాగా బ్యాలెన్స్ అవుతాయి
      deleteOrigin: false,
    );
    return mediaInfo?.file;
  } catch (e) {
    debugPrint("🚨 Video Compression Error: $e");
    return videoFile; // ఒకవేళ కంప్రెషన్ ఫెయిల్ అయితే ఒరిజినల్ ఫైల్ పంపుతాం బాస్
  }
}

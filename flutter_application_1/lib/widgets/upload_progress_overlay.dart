import 'package:flutter/material.dart';
import '../screens/create/add_post_screen.dart'; // 🌟 UploadManager ఇక్కడే ఉంది కాబట్టి

class GlobalUploadOverlay extends StatelessWidget {
  const GlobalUploadOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: UploadManager().isUploading,
      builder: (context, isUploading, child) {
        if (!isUploading) return const SizedBox.shrink();

        return Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          left: 20,
          right: 20,
          child: Material(
            elevation: 10,
            borderRadius: BorderRadius.circular(15),
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                // 🌟 FIX: withOpacity బదులు withValues(alpha: 0.9) వాడాం
                color: Colors.black.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: ValueListenableBuilder<String>(
                          valueListenable: UploadManager().uploadStatus,
                          builder: (context, status, _) {
                            return Text(
                              status,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ValueListenableBuilder<double>(
                    valueListenable: UploadManager().uploadProgress,
                    builder: (context, progress, _) {
                      return LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey[800],
                        color: Colors.blue,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// lib/screens/home/widgets/add_post_bottom_sheet.dart

import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

import '../../../services/firestore_methods.dart';
import '../../add_post/camera_screen.dart';

class AddPostBottomSheet extends StatelessWidget {
  final VoidCallback onPostUploaded;
  const AddPostBottomSheet({super.key, required this.onPostUploaded});

  void _openUploadFinalizeSheet(BuildContext context, dynamic fileData, String postType) {
    final TextEditingController captionController = TextEditingController();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    String title = postType == 'reel' ? 'New Reel Caption 🎬' : (postType == 'audio' ? 'New Audio Post 🎙️' : 'New Post Caption 📸');
    String hint = postType == 'audio' ? 'Write something about this voice note... #tags' : 'Write what is on your mind... Add #hashtags';

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 16, left: 16, right: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const Divider(),
            const SizedBox(height: 10),
            TextField(
              controller: captionController, maxLines: 4, autofocus: true, style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: hint, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.blueAccent), borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 15),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, minimumSize: const Size(double.infinity, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () async {
                String captionText = captionController.text.trim();
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                scaffoldMessenger.showSnackBar(SnackBar(content: Text(postType == 'audio' ? "Publishing Audio Post... 🎙️⏳" : (postType == 'reel' ? "Publishing Reel... 🎬⏳" : "Publishing Post... 📸⏳"))));

                String res;
                if (postType == 'reel') res = await FirestoreMethods().uploadReel(captionText, fileData as File);
                else if (postType == 'audio') res = await FirestoreMethods().uploadAudioPost(captionText, fileData as File);
                else res = await FirestoreMethods().uploadPost(captionText, fileData as List<File>);

                if (!ctx.mounted) return;
                if (res == "success") {
                  scaffoldMessenger.showSnackBar(const SnackBar(content: Text("Published successfully! 🎉"), backgroundColor: Colors.green));
                  onPostUploaded();
                } else {
                  scaffoldMessenger.showSnackBar(SnackBar(content: Text("Upload Failed: $res ❌"), backgroundColor: Colors.redAccent));
                }
              },
              child: const Text('Publish Feed 🚀', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            const SizedBox(height: 25),
          ],
        ),
      ),
    );
  }

  void _showAudioRecordSheet(BuildContext context) {
    int recordSeconds = 0;
    Timer? recordTimer;
    bool isRecording = false;
    String? recordedFilePath;
    final AudioRecorder audioRecorder = AudioRecorder();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showModalBottomSheet(
      context: context, isDismissible: false,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 20),
                  const Text('Record Audio Post 🎙️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 10),
                  Text(
                    isRecording ? 'Recording: ${recordSeconds}s 🔴' : (recordedFilePath != null ? 'Recording Completed! (${recordSeconds}s) 🎧' : 'Tap Microphone to Start Recording'),
                    style: TextStyle(color: isRecording ? Colors.redAccent : Colors.grey, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 30),
                  GestureDetector(
                    onTap: () async {
                      if (!isRecording) {
                        if (await audioRecorder.hasPermission()) {
                          final Directory tempDir = await getTemporaryDirectory();
                          final String path = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
                          await audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
                          setModalState(() { isRecording = true; recordSeconds = 0; recordedFilePath = null; });
                          recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
                            if (recordSeconds >= 120) {
                              timer.cancel();
                              String? path = await audioRecorder.stop();
                              setModalState(() { isRecording = false; recordedFilePath = path; });
                            } else {
                              setModalState(() => recordSeconds++);
                            }
                          });
                        } else {
                          scaffoldMessenger.showSnackBar(const SnackBar(content: Text("Microphone Permission Required! 🎤")));
                        }
                      } else {
                        recordTimer?.cancel();
                        String? path = await audioRecorder.stop();
                        setModalState(() { isRecording = false; recordedFilePath = path; });
                      }
                    },
                    child: CircleAvatar(
                      radius: 45, backgroundColor: isRecording ? Colors.redAccent.withAlpha(50) : (recordedFilePath != null ? Colors.blue.withAlpha(50) : Colors.green.withAlpha(50)),
                      child: CircleAvatar(
                        radius: 35, backgroundColor: isRecording ? Colors.redAccent : (recordedFilePath != null ? Colors.blue : Colors.green),
                        child: Icon(isRecording ? Icons.stop_rounded : (recordedFilePath != null ? Icons.check_rounded : Icons.mic_rounded), size: 36, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 35),
                  if (recordedFilePath != null && !isRecording)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(onPressed: () { recordTimer?.cancel(); Navigator.pop(ctx); }, child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                          icon: const Icon(Icons.edit_note_rounded, color: Colors.white),
                          label: const Text('Write Caption 📝', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            _openUploadFinalizeSheet(context, File(recordedFilePath!), 'audio');
                          },
                        ),
                      ],
                    ),
                  const SizedBox(height: 15),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() => audioRecorder.dispose());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 10),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(10))),
        const SizedBox(height: 15),
        const Text('Create New Feed 🚀', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.camera_alt_outlined, color: Colors.blueAccent, size: 26),
          title: const Text('Camera (Photo / Video)', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Capture a moment instantly'),
          onTap: () async {
            Navigator.pop(context);
            final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const CameraScreen(isForStory: false)));
            if (result != null && result is Map) {
              File file = result['file'];
              bool isVideo = result['type'] == 'video';
              if (!context.mounted) return;
              _openUploadFinalizeSheet(context, isVideo ? file : [file], isVideo ? 'reel' : 'image');
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.image_outlined, color: Colors.green, size: 26),
          title: const Text('Create a Post 📸', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Share beautiful photos on home feed'),
          onTap: () async {
            final pickedFiles = await ImagePicker().pickMultiImage(imageQuality: 75);
            if (pickedFiles.isNotEmpty) {
              if (!context.mounted) return;
              Navigator.pop(context);
              List<File> files = pickedFiles.map((x) => File(x.path)).toList();
              _openUploadFinalizeSheet(context, files, 'image');
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.movie_creation_outlined, color: Colors.pinkAccent, size: 26),
          title: const Text('Create a Reel 🎬', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Share immersive auto-play video clips'),
          onTap: () async {
            final pickedFile = await ImagePicker().pickVideo(source: ImageSource.gallery);
            if (pickedFile != null) {
              if (!context.mounted) return;
              Navigator.pop(context);
              _openUploadFinalizeSheet(context, File(pickedFile.path), 'reel');
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.mic, color: Colors.orangeAccent, size: 26),
          title: const Text('Audio Post 🎙️', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Record a voice note for your feed'),
          onTap: () {
            Navigator.pop(context);
            _showAudioRecordSheet(context);
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
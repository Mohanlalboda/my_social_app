// lib/screens/home/widgets/add_story_bottom_sheet.dart

import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

import '../../../services/firestore_methods.dart';
import '../text_story_screen.dart';

class AddStoryBottomSheet extends StatelessWidget {
  final String myVillage;
  const AddStoryBottomSheet({super.key, required this.myVillage});

  void _showAudioRecordSheet(BuildContext context, {required String privacy}) {
    int recordSeconds = 0;
    Timer? recordTimer;
    bool isRecording = false;
    String? recordedFilePath;
    final AudioRecorder audioRecorder = AudioRecorder();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Record Voice Story 🎙️',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isRecording
                        ? 'Recording: ${recordSeconds}s / 30s 🔴'
                        : (recordedFilePath != null
                              ? 'Recording Completed! (${recordSeconds}s) 🎧'
                              : 'Tap Microphone to Start Recording'),
                    style: TextStyle(
                      color: isRecording ? Colors.redAccent : Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 30),
                  GestureDetector(
                    onTap: () async {
                      if (!isRecording) {
                        if (await audioRecorder.hasPermission()) {
                          final Directory tempDir =
                              await getTemporaryDirectory();
                          final String path =
                              '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
                          await audioRecorder.start(
                            const RecordConfig(encoder: AudioEncoder.aacLc),
                            path: path,
                          );
                          setModalState(() {
                            isRecording = true;
                            recordSeconds = 0;
                            recordedFilePath = null;
                          });
                          recordTimer = Timer.periodic(
                            const Duration(seconds: 1),
                            (timer) async {
                              if (recordSeconds >= 30) {
                                timer.cancel();
                                String? path = await audioRecorder.stop();
                                setModalState(() {
                                  isRecording = false;
                                  recordedFilePath = path;
                                });
                              } else {
                                setModalState(() => recordSeconds++);
                              }
                            },
                          );
                        } else {
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Microphone Permission Required! 🎤",
                              ),
                            ),
                          );
                        }
                      } else {
                        recordTimer?.cancel();
                        String? path = await audioRecorder.stop();
                        setModalState(() {
                          isRecording = false;
                          recordedFilePath = path;
                        });
                      }
                    },
                    child: CircleAvatar(
                      radius: 45,
                      backgroundColor: isRecording
                          ? Colors.redAccent.withAlpha(50)
                          : (recordedFilePath != null
                                ? Colors.blue.withAlpha(50)
                                : Colors.green.withAlpha(50)),
                      child: CircleAvatar(
                        radius: 35,
                        backgroundColor: isRecording
                            ? Colors.redAccent
                            : (recordedFilePath != null
                                  ? Colors.blue
                                  : Colors.green),
                        child: Icon(
                          isRecording
                              ? Icons.stop_rounded
                              : (recordedFilePath != null
                                    ? Icons.check_rounded
                                    : Icons.mic_rounded),
                          size: 36,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 35),
                  if (recordedFilePath != null && !isRecording)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          onPressed: () {
                            recordTimer?.cancel();
                            Navigator.pop(ctx);
                          },
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(
                            Icons.cloud_upload_rounded,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Share to Story 🚀',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () async {
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                content: Text("Uploading Voice Story... ⏳🎙️"),
                              ),
                            );
                            String res = await FirestoreMethods().uploadStory(
                              File(recordedFilePath!),
                              "voice",
                              "Voice Note (${recordSeconds}s)",
                              privacy: privacy,
                            );
                            if (!ctx.mounted) return;
                            if (res == "success")
                              scaffoldMessenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Voice story shared successfully! 🎉",
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
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

  void _openStoryFinalizeSheet(
    BuildContext context,
    List<XFile> pickedFiles,
    String privacy,
  ) {
    final TextEditingController captionController = TextEditingController();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          top: 16,
          left: 16,
          right: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'New Story ✨',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(pickedFiles.first.path),
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey[800],
                      child: const Icon(
                        Icons.movie_creation,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: TextField(
                    controller: captionController,
                    maxLines: 3,
                    autofocus: true,
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Add a caption...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
            if (pickedFiles.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 75),
                child: Text(
                  "+ ${pickedFiles.length - 1} more items",
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            const SizedBox(height: 15),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                String captionText = captionController.text.trim();
                Navigator.pop(ctx);
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      "Uploading ${pickedFiles.length} Stories... ⏳🚀",
                    ),
                  ),
                );

                int successCount = 0;
                for (var file in pickedFiles) {
                  String path = file.path.toLowerCase();
                  String type =
                      (path.endsWith('.mp4') ||
                          path.endsWith('.mov') ||
                          path.endsWith('.avi'))
                      ? "video"
                      : "image";
                  String res = await FirestoreMethods().uploadStory(
                    File(file.path),
                    type,
                    captionText,
                    privacy: privacy,
                  );
                  if (res == "success") successCount++;
                }

                if (successCount > 0 && ctx.mounted)
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        "$successCount Stories shared successfully! 🎉",
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
              },
              child: const Text(
                'Share Story 🚀',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(height: 25),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String selectedPrivacy = 'everyone';
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    String displayVillage = myVillage.trim().isEmpty ? "My Village" : myVillage;

    return StatefulBuilder(
      builder: (context, setModalState) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 15),
            const Text(
              'Share to MyBanjara Story ✨',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 15),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.withAlpha(40),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () =>
                          setModalState(() => selectedPrivacy = 'everyone'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: selectedPrivacy == 'everyone'
                              ? Colors.blueAccent
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '🌍 Everyone',
                            style: TextStyle(
                              color: selectedPrivacy == 'everyone'
                                  ? Colors.white
                                  : Colors.grey[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setModalState(() => selectedPrivacy = 'village');
                        if (myVillage.isEmpty)
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Warning: Village is empty in your profile! 🏕️",
                              ),
                            ),
                          );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: selectedPrivacy == 'village'
                              ? Colors.green
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '🏕️ $displayVillage',
                            style: TextStyle(
                              color: selectedPrivacy == 'village'
                                  ? Colors.white
                                  : Colors.grey[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            const Divider(),
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: Colors.purpleAccent,
                size: 26,
              ),
              title: const Text(
                'Photos & Videos Story 📸🎬',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                selectedPrivacy == 'everyone'
                    ? 'Share with everyone'
                    : 'Share strictly with $displayVillage people',
              ),
              onTap: () async {
                final List<XFile> pickedFiles = await ImagePicker()
                    .pickMultipleMedia();
                if (pickedFiles.isNotEmpty) {
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  _openStoryFinalizeSheet(
                    context,
                    pickedFiles,
                    selectedPrivacy,
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.text_fields_rounded,
                color: Colors.orangeAccent,
                size: 26,
              ),
              title: const Text(
                'Text Status 🎨',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Write updates with colorful backgrounds'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TextStoryScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.mic_none_rounded,
                color: Colors.green,
                size: 26,
              ),
              title: const Text(
                'Audio Story 🎙️',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Record audio status for your Tanda'),
              onTap: () {
                Navigator.pop(context);
                _showAudioRecordSheet(context, privacy: selectedPrivacy);
              },
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}

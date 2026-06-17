// lib/widgets/banjara_notes_bar.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_methods.dart';
import 'package:cached_network_image/cached_network_image.dart';

class BanjaraNotesBar extends StatefulWidget {
  const BanjaraNotesBar({super.key});

  @override
  State<BanjaraNotesBar> createState() => _BanjaraNotesBarState();
}

class _BanjaraNotesBarState extends State<BanjaraNotesBar> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  final TextEditingController _noteController = TextEditingController();

  // 📝 నోట్ రాయడానికి లేదా డిలీట్ చేయడానికి పాపప్ డైలాగ్ బాక్స్
  void _showNoteDialog(String? currentNote) {
    _noteController.text = currentNote ?? '';
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Share a thought... 📝',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: TextField(
            controller: _noteController,
            maxLength:
                60, // గరిష్టంగా 60 అక్షరాలు మాత్రమే ఇన్‌స్టాగ్రామ్ లాగే బాస్
            maxLines: 2,
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              hintText: "What's on your mind?",
              hintStyle: const TextStyle(color: Colors.grey),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: isDark ? Colors.purpleAccent : Colors.blueAccent,
                ),
              ),
            ),
          ),
          actions: [
            if (currentNote != null && currentNote.isNotEmpty)
              TextButton(
                onPressed: () async {
                  // 1. నోట్ సేవ్ చేద్దాం
                  await FirestoreMethods().saveBubbleNote(_noteController.text);

                  // 🌟 THE FIX: ఇక్కడ కేవలం 'mounted' బదులు 'context.mounted' అని వాడాలి
                  if (!context.mounted) return;

                  // 2. ఇప్పుడు సేఫ్ గా నావిగేట్ అవ్వొచ్చు
                  debugPrint("Note saved: ${_noteController.text}");
                  Navigator.pop(context);
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                if (_noteController.text.trim().isNotEmpty) {
                  await FirestoreMethods().saveBubbleNote(
                    _noteController.text.trim(),
                  );
                }
              },
              child: const Text(
                'Share',
                style: TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final last24Hours = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(hours: 24)),
    );

    return Container(
      height: 120,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          // 👉 1. మన సొంత నోట్ బబుల్ ఐటెమ్ (Your Note)
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(currentUid)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const SizedBox();
              }
              var myData = snapshot.data!.data() as Map<String, dynamic>;
              String myPic = myData['profilePic'] ?? '';
              String myNote = myData['userNote'] ?? '';
              var myNoteTime = myData['noteTimestamp'];

              // ఒకవేళ నోట్ పెట్టి 24 గంటలు దాటిపోతే దాన్ని స్క్రీన్‌పై చూపించదు బాస్
              bool isExpired =
                  myNoteTime == null ||
                  (myNoteTime as Timestamp).compareTo(last24Hours) < 0;
              String displayNote = isExpired ? '' : myNote;

              return GestureDetector(
                onTap: () => _showNoteDialog(displayNote),
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: 20,
                    right: 16,
                  ), // 🌟 THE FIX: పైన గ్యాప్ ఇచ్చాం
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.topCenter,
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.grey[300],
                            backgroundImage: CachedNetworkImageProvider(
                              myPic.isNotEmpty
                                  ? myPic
                                  : 'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png',
                            ),
                          ),
                          // చిన్న ప్లస్ ఐకాన్ లేదా నోట్ బబుల్ క్లౌడ్ ఓవర్లే 💬
                          displayNote.isNotEmpty
                              ? Positioned(
                                  top: -15,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    constraints: const BoxConstraints(
                                      maxWidth: 80,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.grey[850]
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.1,
                                          ),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      displayNote,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                  ),
                                )
                              : const Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: CircleAvatar(
                                    radius: 9,
                                    backgroundColor: Colors.blueAccent,
                                    child: Icon(
                                      Icons.add,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Your Note',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // 👉 2. ఇతరులు పెట్టిన లైవ్ నోట్స్ లిస్ట్ (Other Users Notes Stream)
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where(
                  'noteTimestamp',
                  isGreaterThan: last24Hours,
                ) // గత 24 గంటల్లో పెట్టినవి మాత్రమే ఫిల్టర్ ⏱️
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();

              // మన UID కాకుండా మిగతా యూజర్లను మాత్రమే ఫిల్టర్ చేస్తున్నాం బాస్
              var docs = snapshot.data!.docs
                  .where((doc) => doc.id != currentUid)
                  .toList();
              if (docs.isEmpty) return const SizedBox();

              return Row(
                children: docs.map((doc) {
                  var userData = doc.data() as Map<String, dynamic>;
                  String username = userData['username'] ?? 'User';
                  String profilePic = userData['profilePic'] ?? '';
                  String userNote = userData['userNote'] ?? '';

                  return Padding(
                    padding: const EdgeInsets.only(
                      top: 20,
                      right: 16,
                    ), // 🌟 THE FIX: పైన గ్యాప్ ఇచ్చాం
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.topCenter,
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: Colors.grey[300],
                              backgroundImage: CachedNetworkImageProvider(
                                profilePic
                                        .isNotEmpty // (లేదా myPic.isNotEmpty)
                                    ? profilePic
                                    : 'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png',
                              ),
                            ),
                            Positioned(
                              top: -15,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                constraints: const BoxConstraints(maxWidth: 80),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.grey[850]
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.1,
                                      ),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  userNote,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SConstraints(
                          width: 65,
                          child: Text(
                            username,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// టెక్స్ట్ విడ్త్ కంట్రోల్ కొరకు చిన్న హెల్పర్ క్లాస్ బాస్
class SConstraints extends StatelessWidget {
  final double width;
  final Widget child;
  const SConstraints({super.key, required this.width, required this.child});
  @override
  Widget build(BuildContext context) => SizedBox(width: width, child: child);
}

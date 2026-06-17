// lib/screens/profile/family_tree_screen.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class FamilyTreeScreen extends StatefulWidget {
  final String userId;
  const FamilyTreeScreen({super.key, required this.userId});

  @override
  State<FamilyTreeScreen> createState() => _FamilyTreeScreenState();
}

class _FamilyTreeScreenState extends State<FamilyTreeScreen> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, Map<String, dynamic>> _familyNodes = {};
  bool _isLoading = true;

  final double _canvasSize = 5000.0;
  final double _nodeWidth = 140.0;
  final double _nodeHeight = 160.0;

  late TransformationController _transformationController;

  @override
  void initState() {
    super.initState();
    double initialTranslation = (_canvasSize / 2) - 200;
    _transformationController = TransformationController(
      Matrix4.translationValues(-initialTranslation, -initialTranslation, 0.0),
    );
    _loadFamilyTree();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  // 🌳 1. ఫైర్‌బేస్ నుండి వంశవృక్షం డేటా లోడ్ చేయడం
  Future<void> _loadFamilyTree() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      var snap = await _firestore
          .collection('users')
          .doc(widget.userId)
          .collection('family_tree')
          .get();

      Map<String, Map<String, dynamic>> tempNodes = {};
      for (var doc in snap.docs) {
        var data = doc.data();
        data['docId'] = doc.id;
        String key = "${data['x']}_${data['y']}";
        tempNodes[key] = data;
      }

      if (tempNodes.isEmpty || !tempNodes.containsKey("0_0")) {
        var userDoc = await _firestore
            .collection('users')
            .doc(widget.userId)
            .get();
        if (userDoc.exists) {
          var userData = userDoc.data() as Map<String, dynamic>;
          String name = userData['username'] ?? "Me";
          String pic =
              userData['profilePic'] ?? userData['profilePicture'] ?? "";

          var initialNode = {
            'name': name,
            'profilePic': pic,
            'relation': 'Root (నేను)',
            'x': 0,
            'y': 0,
            'isAppUser': true,
            'appUid': widget.userId,
          };

          await _firestore
              .collection('users')
              .doc(widget.userId)
              .collection('family_tree')
              .doc('root_me')
              .set(initialNode);
          tempNodes["0_0"] = initialNode;
        }
      }

      if (mounted) {
        setState(() {
          _familyNodes = tempNodes;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading family tree: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ➕ 2. కొత్త ఫ్యామిలీ మెంబర్ ని యాడ్ చేసే డైలాగ్ బాక్స్
  void _showAddMemberDialog(int x, int y) {
    final nameController = TextEditingController();
    String relationType = "Father";
    bool isSearchMode = true;

    String searchQuery = "";
    List<DocumentSnapshot> searchResults = [];
    Map<String, dynamic>? selectedSearchUser;

    File? manualImage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "🌳 Add Family Member",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<String>(
                  value: relationType,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                      value: "Father",
                      child: Text("Father (నాన్న)"),
                    ),
                    DropdownMenuItem(
                      value: "Mother",
                      child: Text("Mother (అమ్మ)"),
                    ),
                    DropdownMenuItem(
                      value: "Brother",
                      child: Text("Brother (అన్న/తమ్ముడు)"),
                    ),
                    DropdownMenuItem(
                      value: "Sister",
                      child: Text("Sister (అక్క/చెల్లి)"),
                    ),
                    DropdownMenuItem(
                      value: "Spouse",
                      child: Text("Spouse (భార్య/భర్త)"),
                    ),
                    DropdownMenuItem(
                      value: "Child",
                      child: Text("Child (కొడుకు/కూతురు)"),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => relationType = val);
                  },
                ),
                const SizedBox(height: 15),

                Wrap(
                  spacing: 10.0,
                  runSpacing: 8.0,
                  alignment: WrapAlignment.center,
                  children: [
                    ChoiceChip(
                      label: const Text(
                        "Search App User 🔍",
                        style: TextStyle(fontSize: 12),
                      ),
                      selected: isSearchMode,
                      onSelected: (val) =>
                          setModalState(() => isSearchMode = true),
                    ),
                    ChoiceChip(
                      label: const Text(
                        "Manual Entry 📝",
                        style: TextStyle(fontSize: 12),
                      ),
                      selected: !isSearchMode,
                      onSelected: (val) =>
                          setModalState(() => isSearchMode = false),
                    ),
                  ],
                ),
                const Divider(height: 25),

                if (isSearchMode) ...[
                  TextField(
                    decoration: const InputDecoration(
                      hintText: "Enter username...",
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) async {
                      searchQuery = val.trim().toLowerCase();
                      if (searchQuery.isNotEmpty) {
                        var usersSnap = await _firestore
                            .collection('users')
                            .get();
                        var filtered = usersSnap.docs.where((doc) {
                          String uname = (doc.data()['username'] ?? "")
                              .toString()
                              .toLowerCase();
                          return uname.contains(searchQuery) &&
                              doc.id != widget.userId;
                        }).toList();
                        setModalState(() => searchResults = filtered);
                      } else {
                        setModalState(() => searchResults = []);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  if (selectedSearchUser != null)
                    Card(
                      color: Colors.blue.shade50,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: NetworkImage(
                            selectedSearchUser!['profilePic'] ??
                                selectedSearchUser!['profilePicture'] ??
                                '',
                          ),
                        ),
                        title: Text(
                          selectedSearchUser!['username'] ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () =>
                              setModalState(() => selectedSearchUser = null),
                        ),
                      ),
                    ),
                  SizedBox(
                    height: searchResults.isEmpty ? 0 : 150,
                    child: ListView.builder(
                      itemCount: searchResults.length,
                      itemBuilder: (context, i) {
                        var uData =
                            searchResults[i].data() as Map<String, dynamic>;
                        uData['uid'] = searchResults[i].id;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: NetworkImage(
                              uData['profilePic'] ??
                                  uData['profilePicture'] ??
                                  '',
                            ),
                          ),
                          title: Text(uData['username'] ?? ''),
                          onTap: () {
                            setModalState(() {
                              selectedSearchUser = uData;
                              searchResults = [];
                            });
                          },
                        );
                      },
                    ),
                  ),
                ] else ...[
                  GestureDetector(
                    onTap: () async {
                      final pickedFile = await ImagePicker().pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 50,
                      );
                      if (pickedFile != null)
                        setModalState(
                          () => manualImage = File(pickedFile.path),
                        );
                    },
                    child: CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: manualImage != null
                          ? FileImage(manualImage!)
                          : null,
                      child: manualImage == null
                          ? const Icon(
                              Icons.add_a_photo,
                              size: 28,
                              color: Colors.grey,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: "Full Name (పేరు)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
              ),
              onPressed: () async {
                String finalName = "";
                String finalPic = "";
                String appUid = "";
                bool isAppUser = false;

                if (isSearchMode) {
                  if (selectedSearchUser == null) return;
                  finalName = selectedSearchUser!['username'] ?? "User";
                  finalPic =
                      selectedSearchUser!['profilePic'] ??
                      selectedSearchUser!['profilePicture'] ??
                      "";
                  appUid = selectedSearchUser!['uid'] ?? "";
                  isAppUser = true;
                } else {
                  finalName = nameController.text.trim();
                  if (finalName.isEmpty) return;

                  if (manualImage != null) {
                    try {
                      String imgId = const Uuid().v1();
                      var snap = await FirebaseStorage.instance
                          .ref()
                          .child('family_tree_pics')
                          .child(imgId)
                          .putFile(manualImage!);
                      finalPic = await snap.ref.getDownloadURL();
                    } catch (e) {
                      debugPrint("Storage Upload Fail: $e");
                    }
                  }
                }

                Navigator.pop(ctx);

                var newNode = {
                  'name': finalName,
                  'profilePic': finalPic,
                  'relation': relationType,
                  'x': x,
                  'y': y,
                  'isAppUser': isAppUser,
                  'appUid': appUid,
                };

                String docId = const Uuid().v1();
                await _firestore
                    .collection('users')
                    .doc(widget.userId)
                    .collection('family_tree')
                    .doc(docId)
                    .set(newNode);
                _loadFamilyTree();
              },
              child: const Text("ADD", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // 🌟 3. NEW: మెంబర్ వివరాలు చూపించి, ఎడిట్/డిలీట్ చేసే ఆప్షన్ (Bottom Sheet Popup)
  void _showMemberOptionsBottomSheet(Map<String, dynamic> node) {
    String docId = node['docId'] ?? '';
    String name = node['name'] ?? '';
    String relation = node['relation'] ?? '';
    String pic = node['profilePic'] ?? '';
    int x = node['x'] ?? 0;
    int y = node['y'] ?? 0;
    bool isRoot =
        (x == 0 &&
        y == 0); // నేను (Main User) కార్డ్ అయితే డిలీట్ ఆప్షన్ ఇవ్వకూడదు

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(20),
          color: isDark ? Colors.grey[900] : Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              CircleAvatar(
                radius: 35,
                backgroundImage: pic.isNotEmpty
                    ? NetworkImage(pic)
                    : const NetworkImage(
                        'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png',
                      ),
              ),
              const SizedBox(height: 10),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                relation,
                style: const TextStyle(
                  color: Colors.blueAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Divider(height: 30),

              // 📝 ఎడిట్ ఆప్షన్
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.orange),
                title: const Text(
                  "Edit Details",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditMemberDialog(node);
                },
              ),

              // 🗑️ డిలీట్ ఆప్షన్ (రూట్ కార్డ్ కాకపోతేనే వస్తుంది)
              if (!isRoot)
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text(
                    "Delete from Tree",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    _confirmDeleteMember(docId, name);
                  },
                ),
              const SizedBox(height: 15),
            ],
          ),
        );
      },
    );
  }

  // 📝 4. NEW: మెంబర్ వివరాలను ఎడిట్ చేసే డైలాగ్ బాక్స్
  void _showEditMemberDialog(Map<String, dynamic> node) {
    final nameController = TextEditingController(text: node['name']);
    String relationType = node['relation'];
    String currentPic = node['profilePic'] ?? '';
    bool isAppUser = node['isAppUser'] ?? false;
    File? newManualImage;

    // ఒకవేళ డ్రాప్‌డౌన్ లిస్ట్‌లో లేని రిలేషన్ ఉంటే (ఉదాహరణకు Root), డీఫాల్ట్‌గా Father పెడతాం
    List<String> allowedRelations = [
      "Father",
      "Mother",
      "Brother",
      "Sister",
      "Spouse",
      "Child",
    ];
    if (!allowedRelations.contains(relationType)) {
      relationType = "Father";
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "📝 Edit Member Details",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isAppUser) ...[
                  GestureDetector(
                    onTap: () async {
                      final pickedFile = await ImagePicker().pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 50,
                      );
                      if (pickedFile != null)
                        setModalState(
                          () => newManualImage = File(pickedFile.path),
                        );
                    },
                    child: CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: newManualImage != null
                          ? FileImage(newManualImage!)
                          : (currentPic.isNotEmpty
                                ? NetworkImage(currentPic) as ImageProvider
                                : null),
                      child: (newManualImage == null && currentPic.isEmpty)
                          ? const Icon(
                              Icons.add_a_photo,
                              size: 28,
                              color: Colors.grey,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: "Full Name",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 15),
                ],

                if (node['x'] != 0 ||
                    node['y'] !=
                        0) // Root కార్డ్ కాకపోతేనే రిలేషన్ మార్చనిస్తాం
                  DropdownButton<String>(
                    value: relationType,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: "Father",
                        child: Text("Father (నాన్న)"),
                      ),
                      DropdownMenuItem(
                        value: "Mother",
                        child: Text("Mother (అమ్మ)"),
                      ),
                      DropdownMenuItem(
                        value: "Brother",
                        child: Text("Brother (అన్న/తమ్ముడు)"),
                      ),
                      DropdownMenuItem(
                        value: "Sister",
                        child: Text("Sister (అక్క/చెల్లి)"),
                      ),
                      DropdownMenuItem(
                        value: "Spouse",
                        child: Text("Spouse (భార్య/భర్త)"),
                      ),
                      DropdownMenuItem(
                        value: "Child",
                        child: Text("Child (కొడుకు/కూతురు)"),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => relationType = val);
                    },
                  ),
                if (isAppUser)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      "📌 Note: యాప్ యూజర్ల పేరు, ఫోటోలను మనం మార్చలేము బాస్.",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
              ),
              onPressed: () async {
                setState(() => _isLoading = true);
                Navigator.pop(ctx);

                String updatedName = isAppUser
                    ? node['name']
                    : nameController.text.trim();
                String updatedPic = currentPic;

                if (newManualImage != null && !isAppUser) {
                  try {
                    String imgId = const Uuid().v1();
                    var snap = await FirebaseStorage.instance
                        .ref()
                        .child('family_tree_pics')
                        .child(imgId)
                        .putFile(newManualImage!);
                    updatedPic = await snap.ref.getDownloadURL();
                  } catch (e) {
                    debugPrint("Upload Error: $e");
                  }
                }

                await _firestore
                    .collection('users')
                    .doc(widget.userId)
                    .collection('family_tree')
                    .doc(node['docId'])
                    .update({
                      'name': updatedName,
                      'profilePic': updatedPic,
                      'relation': (node['x'] == 0 && node['y'] == 0)
                          ? node['relation']
                          : relationType,
                    });

                _loadFamilyTree();
              },
              child: const Text("SAVE", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // 🗑️ 5. NEW: డిలీట్ కన్ఫర్మేషన్ పాపప్
  Future<void> _confirmDeleteMember(String docId, String name) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Member?"),
        content: Text(
          "Are you sure you want to remove '$name' from your Family Tree?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firestore
          .collection('users')
          .doc(widget.userId)
          .collection('family_tree')
          .doc(docId)
          .delete();
      _loadFamilyTree();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("🗑️ Member removed successfully!")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[100],
      appBar: AppBar(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        title: const Text(
          "వంశ వృక్షం (Family Tree)",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            )
          : InteractiveViewer(
              transformationController: _transformationController,
              constrained: false,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.2,
              maxScale: 2.0,
              child: SizedBox(
                width: _canvasSize,
                height: _canvasSize,
                child: Stack(
                  children: [
                    CustomPaint(
                      size: Size(_canvasSize, _canvasSize),
                      painter: FamilyTreePainter(
                        familyNodes: _familyNodes,
                        canvasSize: _canvasSize,
                        nodeWidth: _nodeWidth,
                        nodeHeight: _nodeHeight,
                      ),
                    ),
                    ..._buildTreeNodes(),
                  ],
                ),
              ),
            ),
    );
  }

  List<Widget> _buildTreeNodes() {
    List<Widget> widgets = [];
    double centerOffset = _canvasSize / 2;

    _familyNodes.forEach((key, node) {
      int x = node['x'];
      int y = node['y'];

      double leftPosition = centerOffset + (x * 220) - (_nodeWidth / 2);
      double topPosition = centerOffset + (y * 240) - (_nodeHeight / 2);

      widgets.add(
        Positioned(
          left: leftPosition,
          top: topPosition,
          width: _nodeWidth,
          height: _nodeHeight,
          child: Column(
            children: [
              GestureDetector(
                // 🌟 THE FIX: నోడ్ కార్డు మీద ట్యాప్ చేయగానే ఆప్షన్స్ (Edit/Delete) బాటమ్ షీట్ ఓపెన్ అవుతుంది!
                onTap: () => _showMemberOptionsBottomSheet(node),
                child: Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: BorderSide(
                      color: node['x'] == 0 && node['y'] == 0
                          ? Colors.blue
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[900]
                      : Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 26,
                          // 🌟 Family Tree ఇమేజ్ నోడ్ లో:
                          backgroundImage: CachedNetworkImageProvider(
                           node['profilePic'] ??
                                'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png',
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          node['name'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          node['relation'],
                          style: const TextStyle(
                            color: Colors.blueAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      _buildDirectionalPlusButton(
        widgets,
        x,
        y - 1,
        leftPosition + (_nodeWidth / 2) - 15,
        topPosition - 25,
      ); // UP
      _buildDirectionalPlusButton(
        widgets,
        x,
        y + 1,
        leftPosition + (_nodeWidth / 2) - 15,
        topPosition + _nodeHeight - 45,
      ); // DOWN
      _buildDirectionalPlusButton(
        widgets,
        x - 1,
        y,
        leftPosition - 25,
        topPosition + (_nodeHeight / 2) - 40,
      ); // LEFT
      _buildDirectionalPlusButton(
        widgets,
        x + 1,
        y,
        leftPosition + _nodeWidth - 5,
        topPosition + (_nodeHeight / 2) - 40,
      ); // RIGHT
    });

    return widgets;
  }

  void _buildDirectionalPlusButton(
    List<Widget> list,
    int targetX,
    int targetY,
    double left,
    double top,
  ) {
    String targetKey = "${targetX}_$targetY";
    if (!_familyNodes.containsKey(targetKey)) {
      list.add(
        Positioned(
          left: left,
          top: top,
          child: GestureDetector(
            onTap: () => _showAddMemberDialog(targetX, targetY),
            child: const CircleAvatar(
              radius: 14,
              backgroundColor: Colors.blueAccent,
              child: Icon(Icons.add, size: 16, color: Colors.white),
            ),
          ),
        ),
      );
    }
  }
}

class FamilyTreePainter extends CustomPainter {
  final Map<String, Map<String, dynamic>> familyNodes;
  final double canvasSize;
  final double nodeWidth;
  final double nodeHeight;

  FamilyTreePainter({
    required this.familyNodes,
    required this.canvasSize,
    required this.nodeWidth,
    required this.nodeHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blueAccent.withValues(alpha: 0.4)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    double centerOffset = canvasSize / 2;

    familyNodes.forEach((key, node) {
      int x = node['x'];
      int y = node['y'];

      double currentX = centerOffset + (x * 220);
      double currentY = centerOffset + (y * 240);

      String parentKey = "${x}_${y - 1}";
      if (familyNodes.containsKey(parentKey)) {
        double parentX = centerOffset + (x * 220);
        double parentY = centerOffset + ((y - 1) * 240) + (nodeHeight / 2) - 30;
        canvas.drawLine(
          Offset(currentX, currentY - (nodeHeight / 2)),
          Offset(parentX, parentY),
          paint,
        );
      }

      String leftKey = "${x - 1}_$y";
      if (familyNodes.containsKey(leftKey)) {
        double leftX = centerOffset + ((x - 1) * 220) + (nodeWidth / 2);
        double leftY = centerOffset + (y * 240) - 30;
        canvas.drawLine(
          Offset(currentX - (nodeWidth / 2), currentY - 30),
          Offset(leftX, leftY),
          paint,
        );
      }
    });
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

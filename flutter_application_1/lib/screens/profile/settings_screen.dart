// lib/screens/profile/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'edit_profile_screen.dart';
import '../../services/firestore_methods.dart';
import '../../services/fcm_sender_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final String _currentUid = FirebaseAuth.instance.currentUser!.uid;
  bool _isPrivateAccount = false;
  bool _notificationsMuted = false;

  void _resetPassword(String email) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Password reset link sent to your email! 📧'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _showDeleteAccountDialog() {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Delete Account? ⚠️',
          style: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Are you sure you want to permanently delete your account? All your posts, reels, and data will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(_currentUid)
                    .delete();
                await FirebaseAuth.instance.currentUser!.delete();
              } catch (e) {
                if (!mounted) return;
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Please re-login and try again to delete account.',
                    ),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            child: const Text(
              'Delete Permanently',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0.5,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          'Settings & Privacy',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: textColor,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          var userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          _isPrivateAccount = userData['isPrivate'] ?? false;

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 10),
            children: [
              _buildSectionHeader('Account', Colors.blueAccent),
              ListTile(
                leading: const Icon(Icons.person_outline_rounded, size: 28),
                title: const Text(
                  'Edit Profile',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Change name, bio, village, and photo',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Colors.grey,
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditProfileScreen(userData: userData),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.bookmark_border_rounded, size: 28),
                title: const Text(
                  'Saved Collections',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Colors.grey,
                ),
                onTap: () {
                  // 🌟 THE FIX: "saved" అనే ఆర్గ్యుమెంట్‌ని పంపిస్తుంది. అప్పుడు ప్రొఫైల్ పేజీ ట్యాబ్ మారుతుంది.
                  Navigator.pop(context, 'saved');
                },
              ),
              ListTile(
                leading: const Icon(Icons.lock_reset_rounded, size: 28),
                title: const Text(
                  'Change Password',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Colors.grey,
                ),
                onTap: () => _resetPassword(userData['email'] ?? ''),
              ),
              const Divider(height: 30),

              _buildSectionHeader('Privacy & Security', Colors.green),
              SwitchListTile(
                activeThumbColor: Colors.blueAccent,
                secondary: const Icon(Icons.lock_outline_rounded, size: 28),
                title: const Text(
                  'Private Account',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Show a lock icon 🔒 next to your name',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                value: _isPrivateAccount,
                onChanged: (val) async {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(_currentUid)
                      .update({'isPrivate': val});
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.block_flipped,
                  size: 28,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  'Blocked Users',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Colors.grey,
                ),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No blocked users found! 🛑')),
                  );
                },
              ),
              const Divider(height: 30),

              _buildSectionHeader('App Preferences', Colors.orangeAccent),
              ListTile(
                leading: const Icon(Icons.dark_mode_outlined, size: 28),
                title: const Text(
                  'Theme (Dark / Light)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  isDark ? 'Dark Mode Active' : 'Light Mode Active',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Colors.grey,
                ),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Use System Settings to change Theme! 🌗'),
                    ),
                  );
                },
              ),
              SwitchListTile(
                activeThumbColor: Colors.blueAccent,
                secondary: const Icon(
                  Icons.notifications_off_outlined,
                  size: 28,
                ),
                title: const Text(
                  'Mute Push Notifications',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                value: _notificationsMuted,
                onChanged: (val) {
                  setState(() => _notificationsMuted = val);
                },
              ),
              const Divider(height: 30),

              _buildSectionHeader('About & Legal', Colors.purpleAccent),
              ListTile(
                leading: const Icon(Icons.help_outline_rounded, size: 28),
                title: const Text(
                  'Help Center & Guidelines',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.policy_outlined, size: 28),
                title: const Text(
                  'Privacy Policy',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: const Icon(
                  Icons.open_in_new_rounded,
                  size: 16,
                  color: Colors.blueAccent,
                ),
                onTap: () async {
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  final Uri url = Uri.parse(
                    'https://docs.google.com/document/d/e/2PACX-1vQTNVeG8-x5T-XcD3hyvzE4ph0vD655He5oSj-30OIodXieFKeyWQRjuVn2tw2WAZtuWjwN6CpPCjsd/pub',
                  );
                  if (!await launchUrl(
                    url,
                    mode: LaunchMode.externalApplication,
                  )) {
                    if (!mounted) return;
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(content: Text('Could not open link!')),
                    );
                  }
                },
              ),
              const Padding(
                padding: EdgeInsets.only(top: 20, bottom: 20),
                child: Center(
                  child: Text(
                    'MyBanjara App v1.0.0\nMade with ❤️',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const Divider(height: 10),

              _buildSectionHeader('Sign In & Security', Colors.redAccent),
              ListTile(
                leading: const Icon(
                  Icons.delete_forever_rounded,
                  size: 28,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  'Delete Account',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                ),
                onTap: _showDeleteAccountDialog,
              ),
              ListTile(
                leading: const Icon(
                  Icons.logout_rounded,
                  size: 28,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  'Log Out',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                ),
                onTap: () async {
                  await FirestoreMethods().updateActiveStatus(false);
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                },
              ),
              const SizedBox(height: 20),
              // 🌟 FCM టెస్ట్ బటన్ (ఇది టెస్టింగ్ అయ్యాక తీసేయొచ్చు)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    // 1. బటన్ నొక్కగానే ఒక చిన్న మెసేజ్ చూపిస్తాం
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Notification Sent! యాప్ ని మినిమైజ్ చేయండి... ⏳",
                        ),
                        duration: Duration(seconds: 3),
                      ),
                    );

                    // 2. మీ ఐడీకి మీరే నోటిఫికేషన్ పంపుకుంటున్నారు
                    String currentUid = FirebaseAuth.instance.currentUser!.uid;
                    await FcmSenderService.sendNotification(
                      receiverId: currentUid,
                      title: "టెస్టింగ్ బాస్! 🚀",
                      body: "FCM పక్కాగా పనిచేస్తుంది!",
                    );
                  },
                  child: const Text(
                    "Test FCM Notification 🔔",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 10, top: 5),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: iconColor,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

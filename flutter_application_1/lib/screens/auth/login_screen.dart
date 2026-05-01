import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'sign_up_screen.dart';
import '../../utils/constants.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    String identifier = _identifierController.text.trim();
    String password = _passwordController.text.trim();

    if (identifier.isEmpty || password.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      String loginEmail = identifier;

      // మొబైల్ నంబర్ లేదా యూజర్ నేమ్ లాజిక్
      if (!identifier.contains('@')) {
        // నంబర్ మాత్రమే ఉంటే ఫోన్ నంబర్ అనుకుంటాం
        bool isPhone = RegExp(r'^\+?[0-9]+$').hasMatch(identifier);

        var querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where(isPhone ? 'phone' : 'username', isEqualTo: identifier)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          loginEmail = querySnapshot.docs.first.data()['email'];
        } else {
          throw Exception(
            "No account found with this ${isPhone ? 'mobile number' : 'username'}. Please sign up.",
          );
        }
      }

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: loginEmail,
        password: password,
      );
    } catch (e) {
      if (!mounted) return;
      String errorMsg = e.toString();

      if (errorMsg.contains('invalid-credential') ||
          errorMsg.contains('user-not-found') ||
          errorMsg.contains('wrong-password')) {
        errorMsg = "Invalid details or Password. Please try again.";
      } else if (errorMsg.contains('Exception:')) {
        errorMsg = errorMsg.replaceAll('Exception: ', '');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🌟 ఫర్గాట్ పాస్‌వర్డ్ (Forgot Password) - Username / Phone / Email లాజిక్
  Future<void> _showForgotPasswordDialog() async {
    TextEditingController resetController = TextEditingController(
      text: _identifierController.text,
    );
    bool isResetting = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[900]
                  : Colors.white,
              title: const Text("Reset Password"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Enter your Username, Email, or Phone number. We will find your account and send a password reset link to your registered email.",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: resetController,
                    decoration: InputDecoration(
                      hintText: "Username / Email / Phone",
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[800]
                          : Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                isResetting
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () async {
                          String identifier = resetController.text.trim();
                          if (identifier.isEmpty) return;

                          setStateDialog(() => isResetting = true);

                          try {
                            String resetEmail = identifier;

                            // స్మార్ట్ లాజిక్: ఈమెయిల్ కాకపోతే డేటాబేస్ లో వెతుకుతాం
                            if (!identifier.contains('@')) {
                              // కేవలం నంబర్స్ ఉంటే ఫోన్ అని, లేకపోతే యూజర్ నేమ్ అని డిసైడ్ చేస్తాం
                              bool isPhone = RegExp(
                                r'^\+?[0-9]+$',
                              ).hasMatch(identifier);

                              var snap = await FirebaseFirestore.instance
                                  .collection('users')
                                  .where(
                                    isPhone ? 'phone' : 'username',
                                    isEqualTo: identifier,
                                  )
                                  .limit(1)
                                  .get();

                              if (snap.docs.isNotEmpty) {
                                resetEmail = snap.docs.first.data()['email'];
                              } else {
                                throw Exception(
                                  "No account found with this ${isPhone ? 'number' : 'username'}.",
                                );
                              }
                            }

                            // ఫైర్‌బేస్ ద్వారా ఆ ఈమెయిల్‌కి పాస్‌వర్డ్ రీసెట్ లింక్ పంపుతాం
                            await FirebaseAuth.instance.sendPasswordResetEmail(
                              email: resetEmail,
                            );

                            if (!context.mounted) return;
                            Navigator.pop(context); // డైలాగ్ క్లోజ్ చేస్తాం

                            // సక్సెస్ మెసేజ్ చూపిస్తాం
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "Success! Password reset link has been sent to: $resetEmail",
                                ),
                                backgroundColor: Colors.green,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          } catch (e) {
                            String errorMsg = e.toString().replaceAll(
                              'Exception: ',
                              '',
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(errorMsg),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          } finally {
                            if (context.mounted) {
                              setStateDialog(() => isResetting = false);
                            }
                          }
                        },
                        child: const Text(
                          "Send Link",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => brandGradient.createShader(
                      Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                    ),
                    child: Text(
                      "MyBanjara",
                      style: GoogleFonts.lobster(
                        fontSize: 55,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 50),

                  // 🌟 Username, Email or Mobile Field
                  TextField(
                    controller: _identifierController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: "Username, Email or Mobile",
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: isDark ? Colors.grey[900] : Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(
                        Icons.person_outline,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // 🌟 Password Field
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: "Password",
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: isDark ? Colors.grey[900] : Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),

                  // 🌟 Forgot Password Button
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _showForgotPasswordDialog,
                      child: const Text(
                        "Forgot Password?",
                        style: TextStyle(
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // 🌟 Login Button
                  GestureDetector(
                    onTap: _isLoading ? null : _login,
                    child: Container(
                      width: double.infinity,
                      height: 55,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: brandGradient,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFFD1D1D,
                            ).withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 25,
                              width: 25,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              "Log In",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 25),

                  // 🌟 Sign Up Navigation
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SignUpScreen(),
                          ),
                        ),
                        child: ShaderMask(
                          shaderCallback: (bounds) =>
                              brandGradient.createShader(
                                Rect.fromLTWH(
                                  0,
                                  0,
                                  bounds.width,
                                  bounds.height,
                                ),
                              ),
                          child: const Text(
                            "Sign Up",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

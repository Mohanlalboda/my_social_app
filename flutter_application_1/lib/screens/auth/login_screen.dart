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

      // 🌟 MAGIC LOGIC: యూజర్ '@' సింబల్ ఎంటర్ చేయకపోతే, అది మొబైల్ నంబర్ అని భావించి డేటాబేస్ లో వెతుకుతాం
      if (!identifier.contains('@')) {
        var querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('phone', isEqualTo: identifier)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          // నంబర్ కి లింక్ అయిన ఈమెయిల్ దొరికింది!
          loginEmail = querySnapshot.docs.first.data()['email'];
        } else {
          throw Exception(
            "No account found with this mobile number. Please sign up.",
          );
        }
      }

      // ఫైనల్ గా ఆ ఈమెయిల్ ఐడీ తో లాగిన్ అవుతున్నాం
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: loginEmail,
        password: password,
      );
    } catch (e) {
      if (!mounted) return;
      // ఫైర్‌బేస్ ఎర్రర్స్ ని సింపుల్ గా చూపించడానికి
      String errorMsg = e.toString();

      if (errorMsg.contains('invalid-credential') ||
          errorMsg.contains('user-not-found') ||
          errorMsg.contains('wrong-password')) {
        errorMsg = "Invalid Email/Phone or Password. Please try again.";
      } else if (errorMsg.contains('Exception:')) {
        // మనం పైన రాసిన కస్టమ్ ఎర్రర్ మెసేజ్ ని ఫార్మాట్ చేయడానికి
        errorMsg = errorMsg.replaceAll('Exception: ', '');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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

                  // 🌟 Email or Mobile Field
                  TextField(
                    controller: _identifierController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: "Email or Mobile Number",
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
                  const SizedBox(height: 30),

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
                            color: const Color(0xFFFD1D1D).withValues(
                              alpha: 0.3,
                            ), // పాత వెర్షన్స్ లో క్రాష్ అవ్వకుండా withOpacity వాడాం
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

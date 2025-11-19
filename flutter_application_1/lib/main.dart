import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _ensureFirebaseInitialized();
  runApp(const MyApp());
}

Future<void> _ensureFirebaseInitialized() async {
  if (Firebase.apps.isNotEmpty) {
    return;
  }

  try {
    await Firebase.initializeApp();
  } catch (error) {
    debugPrint('Firebase init failed: $error');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WireX Portable POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E2444)),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Controllers สำหรับรับค่าจาก Input
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  // สถานะการโหลด
  bool _isLoading = false;
  
  // ภาษาที่เลือก (Mockup UI)
  String _selectedLanguage = 'TH';
  final List<String> _languages = ['TH', 'EN', 'LO', '中文', '한국어'];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ฟังก์ชัน Login
  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError("กรุณากรอกข้อมูลให้ครบถ้วน");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // เรียกใช้ Firebase Auth
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // ถ้า Login สำเร็จ ให้ไปหน้า Dashboard (คุณต้องมีหน้านี้รองรับ)
      if (mounted) {
         // Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => DashboardPage()));
         _showSuccess("เข้าสู่ระบบสำเร็จ!");
         print("Login Success: User ${FirebaseAuth.instance.currentUser?.uid}");
      }

    } on FirebaseAuthException catch (e) {
      // แสดงข้อความที่ตรงกับสาเหตุให้มากที่สุด พร้อม log เพื่อ debug เพิ่มเติม
      String message = "เกิดข้อผิดพลาด";
      switch (e.code) {
        case 'user-not-found':
          message = "ไม่พบผู้ใช้งานนี้";
          break;
        case 'wrong-password':
          message = "รหัสผ่านไม่ถูกต้อง";
          break;
        case 'invalid-email':
          message = "รูปแบบอีเมลไม่ถูกต้อง";
          break;
        case 'network-request-failed':
          message = "ไม่สามารถเชื่อมต่อเครือข่ายได้ โปรดตรวจสอบอินเทอร์เน็ต";
          break;
        case 'too-many-requests':
          message = "มีการพยายามเข้าสู่ระบบบ่อยเกินไป โปรดลองใหม่ภายหลัง";
          break;
        default:
          message = e.message ?? message;
      }
      debugPrint('Login failed (${e.code}): ${e.message}');
      _showError(message);
    } catch (error, stackTrace) {
      debugPrint('Login failed (unknown): $error\n$stackTrace');
      _showError("เกิดข้อผิดพลาด: ${error.toString()}");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
  
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    // สี Theme ตามรูปภาพ
    const Color darkBlue = Color(0xFF1E2444); 
    const Color inputBg = Color(0xFFF3F4F6);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                
                // --- Logo Section ---
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Placeholder โลโก้ (สี่เหลี่ยมมนๆ ตามรูป)
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: darkBlue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.qr_code, color: Colors.white, size: 30),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        "WireX Portable POS",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: darkBlue,
                          fontFamily: 'Serif', // ลองใช้ฟอนต์แบบมีเชิงให้เหมือนรูป
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 60),

                // --- Username Input ---
                const Text(
                  "Username", // ใน Firebase ปกติใช้ Email แต่ UI เขียน Username
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: darkBlue,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    hintText: "Username",
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    filled: true,
                    fillColor: inputBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),

                const SizedBox(height: 24),

                // --- Password Input ---
                const Text(
                  "Password",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: darkBlue,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: "........",
                    hintStyle: TextStyle(color: Colors.grey[400], letterSpacing: 2),
                    filled: true,
                    fillColor: inputBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),

                const SizedBox(height: 24),

                // --- Language Selector ---
                const Text(
                  "เลือกภาษา",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: darkBlue,
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _languages.map((lang) {
                      final isSelected = _selectedLanguage == lang;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedLanguage = lang;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? darkBlue : inputBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              lang,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.grey[600],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 60),

                // --- Login Button ---
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: darkBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "เข้าสู่ระบบ",
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 24),

                // --- Forgot Password ---
                Center(
                  child: GestureDetector(
                    onTap: () {
                      // Handle forgot password
                      print("Forgot Password tapped");
                    },
                    child: const Text(
                      "ลืมรหัสผ่าน?",
                      style: TextStyle(
                        color: darkBlue,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
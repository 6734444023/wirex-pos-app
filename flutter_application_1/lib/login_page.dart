import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_page.dart';
import 'l10n/app_translations.dart';
import 'providers/language_provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isNavigating = false;
  // String _selectedLanguage = 'TH'; // Moved to LanguageProvider
  final List<String> _languages = ['TH', 'EN', 'LO', '中文', '한국어'];

  bool _obscureText = true;
  bool _rememberMe = false;
  String? _savedEmail;
  String? _savedPassword;

  String tr(String key) {
    final lang = Provider.of<LanguageProvider>(context, listen: false).selectedLanguage;
    return AppTranslations.get(lang, key);
  }

  @override
  void initState() {
    super.initState();
    _loadSavedUser();
  }

  Future<void> _loadSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedEmail = prefs.getString('saved_email');
      _savedPassword = prefs.getString('saved_password');
      if (_savedEmail != null && _savedPassword != null) {
        _rememberMe = true;
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<bool> _checkWifi() async {
    final List<ConnectivityResult> connectivityResult = await (Connectivity().checkConnectivity());
    if (!connectivityResult.contains(ConnectivityResult.wifi)) {
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(tr('alert')),
            content: Text(tr('no_wifi')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(tr('ok')),
              ),
            ],
          ),
        );
      }
      return false;
    }
    return true;
  }

  Future<void> _handleLogin({String? email, String? password}) async {
    final hasWifi = await _checkWifi();
    if (!hasWifi) return;

    final inputEmail = email ?? _emailController.text.trim();
    final inputPassword = password ?? _passwordController.text.trim();

    if (inputEmail.isEmpty || inputPassword.isEmpty) {
      _showError(tr('fill_all'));
      return;
    }

    setState(() {
      _isLoading = true;
      _isNavigating = false;
    });

    try {
      final normalizedInputEmail = inputEmail.toLowerCase();

      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: inputEmail,
        password: inputPassword,
      );

      final user = userCredential.user;
      if (user == null) {
        _showError(tr('auth_failed'));
        return;
      }

      // Save or Clear User
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setString('saved_email', inputEmail);
        await prefs.setString('saved_password', inputPassword);
      } else {
        // Only clear if we are doing a manual login (implied by using controllers, but here we use args)
        // If we are logging in via saved user, _rememberMe should be true anyway.
        // If user unchecked remember me, we clear.
        await prefs.remove('saved_email');
        await prefs.remove('saved_password');
      }

      final userEmail = (user.email ?? '').toLowerCase();
      var hasAccess = normalizedInputEmail == 'admin@gmail.com' ||
          userEmail == 'admin@gmail.com';

      if (!hasAccess) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data();
          // ตรวจสอบว่า isPaid เป็น true หรือไม่ (ไม่สนใจ role)
          final isPaid = userData?['isPaid'] == true;
          hasAccess = isPaid;

          if (!hasAccess) {
            debugPrint('User ${user.uid} isPaid is false or missing.');
          }
        } else {
          // ถ้าไม่มีข้อมูลใน Database ให้เข้าไม่ได้ (หรือแล้วแต่ Policy แต่ตามโจทย์คือต้องมีข้อมูลและ isPaid=true)
          hasAccess = false;
          debugPrint('User ${user.uid} has no Firestore doc.');
        }
      }

      debugPrint('Login access for ${user.uid}: $hasAccess');

      if (!hasAccess) {
        await FirebaseAuth.instance.signOut();
        _showError(tr('access_denied'));
        return;
      }

      _navigateToDashboard();
    } on FirebaseAuthException catch (e) {
      String message = tr('error');
      if (e.code == 'user-not-found') {
        message = tr('user_not_found');
      } else if (e.code == 'wrong-password') {
        message = tr('wrong_password');
      } else if (e.code == 'invalid-email') {
        message = tr('invalid_email');
      }
      _showError(message);
    } catch (error, stackTrace) {
      debugPrint('Login failed: $error\n$stackTrace');
      _showError('${tr('error')}: $error');
    } finally {
      if (mounted && !_isNavigating) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToDashboard() {
    if (mounted) {
      _isNavigating = true;
      _showSuccess(tr('login_success'));
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardPage()),
      );
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
    final languageProvider = Provider.of<LanguageProvider>(context);
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
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: darkBlue,
                          borderRadius: BorderRadius.zero,
                          image: const DecorationImage(
                            image: NetworkImage(
                              'https://firebasestorage.googleapis.com/v0/b/wirexmenu-2fd27.firebasestorage.app/o/logo%2FmessageImage_1763726179957.jpg?alt=media',
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'WireX Smart POS',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: darkBlue,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 60),
                if (_savedEmail != null) ...[
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () => _handleLogin(email: _savedEmail, password: _savedPassword),
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: darkBlue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.person, size: 60, color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _savedEmail!,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: darkBlue,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _savedEmail = null;
                            });
                          },
                          child: Text(tr('login_with_other')),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Text(
                    tr('username'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: darkBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      hintText: tr('username'),
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
                  Text(
                    tr('password'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: darkBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscureText,
                    decoration: InputDecoration(
                      hintText: '........',
                      hintStyle: TextStyle(color: Colors.grey[400], letterSpacing: 2),
                      filled: true,
                      fillColor: inputBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureText ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureText = !_obscureText;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        activeColor: darkBlue,
                        onChanged: (value) {
                          setState(() {
                            _rememberMe = value ?? false;
                          });
                        },
                      ),
                      Text(
                        tr('remember_me'),
                        style: const TextStyle(color: darkBlue),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
                Text(
                  tr('select_language'),
                  style: const TextStyle(
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
                      final isSelected = languageProvider.selectedLanguage == lang;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: GestureDetector(
                          onTap: () {
                            languageProvider.setLanguage(lang);
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
                if (_savedEmail == null) ...[
                  const SizedBox(height: 60),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : () => _handleLogin(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: darkBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              tr('login'),
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Center(
                  child: GestureDetector(
                    onTap: () {
                      debugPrint('Forgot Password tapped');
                    },
                    child: Text(
                      tr('forgot_password'),
                      style: const TextStyle(
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

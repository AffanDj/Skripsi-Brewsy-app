import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dashboard_page.dart';
import 'register_page.dart';

const Color primaryColor = Color(0xFF01479E);
const Color secondaryColor = Color(0xFFFF6F00);
const Color backgroundColor = Color(0xFFF5F7FA);

class LoginPageScreen extends StatefulWidget {
  @override
  _LoginPageScreenState createState() => _LoginPageScreenState();
}

class _LoginPageScreenState extends State<LoginPageScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterSecureStorage storage = FlutterSecureStorage();

  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _checkRememberedUser();
  }

  Future<void> _checkRememberedUser() async {
    String? email = await storage.read(key: 'email');
    String? password = await storage.read(key: 'password');

    if (email != null && password != null) {
      setState(() {
        _emailController.text = email;
        _passwordController.text = password;
        _rememberMe = true;
      });
    }
  }

  void _loginUser() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Email dan password tidak boleh kosong.');
      return;
    }

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;

      if (user != null && user.emailVerified) {
        if (_rememberMe) {
          await storage.write(key: 'email', value: email);
          await storage.write(key: 'password', value: password);
        } else {
          await storage.deleteAll();
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => DashboardPage()),
        );
      } else {
        _showMessage(
          'Email belum diverifikasi. Silakan periksa email Anda.',
          color: secondaryColor,
        );
        await _auth.signOut();
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'Pengguna tidak ditemukan.';
          break;
        case 'wrong-password':
          errorMessage = 'Password salah.';
          break;
        case 'invalid-email':
          errorMessage = 'Format email tidak valid.';
          break;
        default:
          errorMessage = 'Login gagal: ${e.message}';
      }
      _showMessage(errorMessage);
    }
  }

  void _showMessage(String message, {Color color = Colors.redAccent}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final TextEditingController _forgotEmailController = TextEditingController();
        return AlertDialog(
          title: Text('Reset Password'),
          content: TextField(
            controller: _forgotEmailController,
            decoration: InputDecoration(hintText: 'Masukkan email Anda'),
          ),
          actions: [
            TextButton(
              child: Text('BATAL'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('KIRIM'),
              onPressed: () async {
                try {
                  await _auth.sendPasswordResetEmail(
                      email: _forgotEmailController.text.trim());
                  Navigator.of(context).pop();
                  _showMessage('Link reset password telah dikirim ke email Anda.', color: Colors.green);
                } catch (e) {
                  _showMessage('Gagal mengirim email: ${e.toString()}');
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              SizedBox(
                height: 500,
                child: Image.asset('assets/BrewsyLogo.png'),
              ),
              SizedBox(height: 20),
              TextField(
                controller: _emailController,
                decoration: _inputDecoration('Email'),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) {
                  // Move focus to password field when pressing enter on email
                  FocusScope.of(context).nextFocus();
                },
              ),
              SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: _inputDecoration('Password'),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  // Trigger login when pressing enter on password field
                  _loginUser();
                },
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Checkbox(
                    value: _rememberMe,
                    onChanged: (value) {
                      setState(() {
                        _rememberMe = value ?? false;
                      });
                    },
                  ),
                  Text('Ingat saya', style: TextStyle(color: primaryColor)),
                  Spacer(),
                  TextButton(
                    onPressed: _showForgotPasswordDialog,
                    child: Text('Lupa Password?', style: TextStyle(color: secondaryColor)),
                  ),
                ],
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _loginUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('LANJUT',
                      style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ),
              SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => RegisterPage()),
                ),
                child: Text('Belum punya akun? Daftar',
                    style: TextStyle(color: secondaryColor)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: primaryColor),
      filled: true,
      fillColor: primaryColor.withOpacity(0.1),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: secondaryColor, width: 2),
      ),
    );
  }
}
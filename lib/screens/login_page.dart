import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dashboard_page.dart';
import 'register_page.dart';

class LoginPageScreen extends StatefulWidget {
  @override
  _LoginPageScreenState createState() => _LoginPageScreenState();
}

class _LoginPageScreenState extends State<LoginPageScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Fungsi untuk login pengguna
  void _loginUser() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    // Validasi email
    if (email.isEmpty || !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Email tidak valid.'),
          backgroundColor: Colors.red,
        ),
      );
      return; // Hentikan eksekusi jika email tidak valid
    }

    // Validasi password
    if (password.isEmpty || password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password harus memiliki minimal 6 karakter.'),
          backgroundColor: Colors.red,
        ),
      );
      return; // Hentikan eksekusi jika password tidak valid
    }

    try {
      // Login pengguna menggunakan Firebase Authentication
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Ambil pengguna yang sedang login
      User? user = userCredential.user;

      if (user != null) {
        if (user.emailVerified) {
          // Email sudah diverifikasi, arahkan ke DashboardPage
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => DashboardPage()),
          );
        } else {
          // Email belum diverifikasi
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Email Anda belum diverifikasi. Silakan cek email Anda untuk memverifikasi.'),
              backgroundColor: Colors.orange,
            ),
          );

          // Logout pengguna untuk mencegah akses
          await _auth.signOut();
        }
      }
    } catch (e) {
      String errorMessage;
      // Menangani kesalahan spesifik dari Firebase Authentication
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'user-not-found':
            errorMessage = 'Pengguna tidak ditemukan.';
            break;
          case 'wrong-password':
            errorMessage = 'Password salah.';
            break;
          case 'invalid-email':
            errorMessage = 'Email tidak valid.';
            break;
          default:
            errorMessage = 'Login gagal: ${e.message}';
        }
      } else {
        errorMessage = 'Terjadi kesalahan. Silakan coba lagi.';
      }

      // Tampilkan pesan error melalui SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo aplikasi
              Flexible(
                child: Container(
                  child: Image.asset(
                    'assets/BrewsyLogo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              SizedBox(height: 10),




              SizedBox(height: 20),

              // TextField untuk email
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.blue[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              SizedBox(height: 20),

              // TextField untuk password
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.blue[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              SizedBox(height: 20),

              // Tautan "Daftar" dan "Lupa Password"
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      // Aksi untuk navigasi ke halaman pendaftaran
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => RegisterPage()),
                      );
                    },
                    child: Text(
                      'Daftar',
                      style: TextStyle(color: Colors.blueAccent),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      // Aksi untuk lupa password
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Fitur lupa password belum tersedia.'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    },
                    child: Text(
                      'Lupa password ?',
                      style: TextStyle(color: Colors.blueAccent),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 20),

              // Tombol Login
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                  onPressed: _loginUser, // Panggil fungsi login
                  child: Text(
                    'LANJUT',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),

              SizedBox(height: 20.0),
            ],
          ),
        ),
      ),
    );
  }
}

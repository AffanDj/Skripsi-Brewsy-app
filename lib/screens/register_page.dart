import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final _formKey = GlobalKey<FormState>();

  void _registerUser() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Membuat akun baru dengan email dan password
        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // Mengirim email verifikasi
        User? user = userCredential.user;
        if (user != null && !user.emailVerified) {
          await user.sendEmailVerification();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Link aktivasi telah dikirim ke email Anda. Silakan cek email untuk verifikasi.'),
            ),
          );
        }

        // Navigasi ke halaman login (opsional, tergantung alur aplikasi Anda)
        Navigator.pop(context);
      } catch (e) {
        print(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pendaftaran gagal: ${e.toString()}'),
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Daftar Akun"),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Email tidak boleh kosong";
                  }
                  if (!RegExp(r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(value)) {
                    return "Format email tidak valid";
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Password tidak boleh kosong";
                  }
                  if (value.length < 6) {
                    return "Password harus terdiri dari minimal 6 karakter";
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: _registerUser,
                  child: Text("Daftar"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:brewsy_app/screens/add_payment_page.dart';
import 'package:brewsy_app/screens/add_product_page.dart';
import 'package:brewsy_app/screens/payment_page.dart';
import 'package:brewsy_app/screens/transaction_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'screens/login_page.dart';
import 'screens/dashboard_page.dart'; // Dashboard Page
import 'package:intl/date_symbol_data_local.dart';
import 'screens/product_page.dart';// Product Page
import 'screens/category_page.dart'; //Category Page
import 'screens/add_category_page.dart';
import 'screens/new_order.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'screens/register_page.dart';
import 'firebase_options.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
    // Inisialisasi Firebase
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform, // Pilih konfigurasi platform secara otomatis
      );
      print("Firebase Initialized Successfully");
    } catch (e) {
      print("Error initializing Firebase: $e");
    }

    runApp(BrewsyApp());
}


class BrewsyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BrewsyApp',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => LoginPageScreen(), // Halaman login
        'register': (context) => RegisterPage(),
        '/dashboard': (context) => DashboardPage(), // Halaman Dashboard
        '/product': (context) => ProductPage(), // Halaman Product
        '/category': (context) => CategoryPage(), // Halaman Category
        '/payment': (context) => PaymentPage(),
        '/transaction': (context) => TransactionPage(),
        '/addProduct': (context) => AddProductPage(),
        '/addCategory': (context) => AddCategoryPage(),
        '/addPayment' : (context) => AddPaymentPage(),
        '/newOrder' : (context) => NewOrderPage(),
      },
    );
  }
}

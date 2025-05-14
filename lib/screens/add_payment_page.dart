import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddPaymentPage extends StatefulWidget {
  @override
  _AddPaymentPageState createState() => _AddPaymentPageState();
}

class _AddPaymentPageState extends State<AddPaymentPage> {
  int _selectedIndex = 5; // Default selected index is 'Product'
  TextEditingController _namePaymentController = TextEditingController();

  void _addPaymentToFirestore() async {
    String paymentName = _namePaymentController.text.trim();

    if (paymentName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Nama Payment Tidak Boleh Kosong!")),
      );
      return;
    }

    try {
      CollectionReference payment =
      FirebaseFirestore.instance.collection('paymentType');

      DocumentReference newPayment = await payment.add({
        'paymentId': payment
            .doc()
            .id,
        'paymentName': paymentName,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Payment berhasil ditambahkan!")),
      );

      _namePaymentController.clear();

      Navigator.of(context).pushReplacementNamed('/payment');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal Menambahkan Payment: $e")),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: Text('Add Payment', style: TextStyle(color: Colors.grey[700])),
        backgroundColor: Colors.grey[300],
        elevation: 0,
      ),
      body: Row(
        children: [
          // Main Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 20),
                  // Form untuk menambah produk
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Add New Payment',
                                  style: TextStyle(fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),

                            Divider(),

                            // Form fields untuk input produk baru
                            TextField(
                              controller: _namePaymentController,
                              decoration: InputDecoration(
                                  labelText: 'Nama Payment'),
                            ),
                            SizedBox(height: 50),

                            // Tombol Add Item
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E9ACF),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10.0),
                                  ),
                                ),
                                onPressed: _addPaymentToFirestore,
                                  //Function setelah button clik add button
                                child: Text(
                                  'Add Payment',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),

                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
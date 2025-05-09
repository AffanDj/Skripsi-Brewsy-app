import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddCategoryPage extends StatefulWidget {
  @override
  _AddCategoryPageState createState() => _AddCategoryPageState();
}

class _AddCategoryPageState extends State<AddCategoryPage> {
  int _selectedIndex = 4;
  TextEditingController _nameCategoryController = TextEditingController();

  void _addCategoryToFirestore() async {
    String categoryName = _nameCategoryController.text.trim();

    if (categoryName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Nama kategori tidak boleh kosong!")),
      );
      return;
    }

    try {
      // Tambahkan data ke Firestore
      CollectionReference categories =
      FirebaseFirestore.instance.collection('category');

      DocumentReference newCategory = await categories.add({
        'categoryId': categories.doc().id, // ID otomatis
        'categoryName': categoryName, // Nama kategori dari input
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Kategori berhasil ditambahkan!")),
      );

      // Reset input field
      _nameCategoryController.clear();

      // Navigasi kembali ke halaman /category
      Navigator.of(context).pushReplacementNamed('/category');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal menambahkan kategori: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: Text('Add Category', style: TextStyle(color: Colors.grey[700])),
        backgroundColor: Colors.grey[300],
        elevation: 0,
      ),
      body: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 20),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add New Category',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Divider(),
                            TextField(
                              controller: _nameCategoryController,
                              decoration: InputDecoration(labelText: 'Nama Category'),
                            ),
                            SizedBox(height: 50),
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
                                onPressed: _addCategoryToFirestore, // Panggil fungsi
                                child: Text(
                                  'Add Category',
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

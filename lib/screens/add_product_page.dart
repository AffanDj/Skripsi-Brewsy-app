import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

class AddProductPage extends StatefulWidget {
  @override
  _AddProductPageState createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  File? _productImage;
  Uint8List? _webImage; // Untuk gambar di web
  final ImagePicker _picker = ImagePicker();

  TextEditingController _nameProductController = TextEditingController();
  TextEditingController _codeProductController = TextEditingController();
  TextEditingController _priceProductController = TextEditingController();

  String? _selectedCategory;
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _fetchCategories(); // Fetch categories on page load
  }

  // Fetch categories from Firestore
  Future<void> _fetchCategories() async {
    try {
      QuerySnapshot snapshot =
      await FirebaseFirestore.instance.collection('category').get();
      setState(() {
        _categories =
            snapshot.docs.map((doc) => doc['categoryName'].toString()).toList();
      });
    } catch (e) {
      print('Error fetching categories: $e');
    }
  }

  // Fungsi untuk memilih foto
  Future<void> _pickImage() async {
    try {
      if (kIsWeb) {
        // Logika untuk web
        final ImagePicker picker = ImagePicker();
        final XFile? pickedImage = await picker.pickImage(source: ImageSource.gallery);
        if (pickedImage != null) {
          final Uint8List imageBytes = await pickedImage.readAsBytes();
          setState(() {
            _webImage = imageBytes;
          });
        }
      } else {
        // Logika untuk Android/iOS
        final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
        if (pickedFile != null) {
          setState(() {
            _productImage = File(pickedFile.path);
          });
        }
      }
    } catch (e) {
      print("Error picking image: $e");
    }
  }

  // Upload foto ke Firebase Storage dan dapatkan URL
  Future<String> _uploadPhoto(String codeProduct) async {
    final String filePath = "products/$codeProduct.jpg";
    final Reference storageRef = FirebaseStorage.instance.ref().child(filePath);

    if (kIsWeb && _webImage != null) {
      // Upload dari web
      final UploadTask uploadTask = storageRef.putData(_webImage!);
      final TaskSnapshot taskSnapshot = await uploadTask;
      return await taskSnapshot.ref.getDownloadURL();
    } else if (_productImage != null) {
      // Upload dari Android/iOS
      final UploadTask uploadTask = storageRef.putFile(_productImage!);
      final TaskSnapshot taskSnapshot = await uploadTask;
      return await taskSnapshot.ref.getDownloadURL();
    } else {
      throw Exception("No image selected");
    }
  }

  // Simpan data produk ke Firestore
  Future<void> _saveProduct(String photoUrl) async {
    try {
      await FirebaseFirestore.instance.collection('item').doc().set({
        'category': _selectedCategory,
        'code': _codeProductController.text.trim(),
        'image_url': photoUrl,
        'name': _nameProductController.text.trim(),
        'price': double.parse(_priceProductController.text.trim()),
        'totalRevenue': 0, // Default value
        'totalSales': 0, // Default value
      });
      print("Product added successfully!");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Product added successfully!'),
      ));
    } catch (e) {
      print("Error saving product: $e");
    }
  }

  // Fungsi untuk handle submit
  Future<void> _handleSubmit() async {
    try {
      if (_nameProductController.text.trim().isEmpty ||
          _codeProductController.text.trim().isEmpty ||
          _priceProductController.text.trim().isEmpty ||
          _selectedCategory == null ||
          (_productImage == null && _webImage == null)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Please complete all fields and upload an image!'),
        ));
        return;
      }

      // Upload foto dan dapatkan URL
      final String photoUrl =
      await _uploadPhoto(_codeProductController.text.trim());

      // Simpan data produk
      await _saveProduct(photoUrl);
    } catch (e) {
      print("Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
      ));
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: Text('Add Product', style: TextStyle(color: Colors.grey[700])),
        backgroundColor: Colors.grey[300],
        elevation: 0,
      ),
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 100,
            color: Colors.grey[100],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [],
            ),
          ),

          // Main Content
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
                              'Add New Product',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Divider(),
                            // Form fields
                            TextField(
                              controller: _nameProductController,
                              decoration:
                              InputDecoration(labelText: 'Nama Item'),
                            ),
                            SizedBox(height: 5),
                            TextField(
                              controller: _codeProductController,
                              decoration:
                              InputDecoration(labelText: 'Kode Item'),
                            ),
                            SizedBox(height: 5),
                            DropdownButtonFormField<String>(
                              value: _selectedCategory,
                              decoration: InputDecoration(labelText: 'Kategori'),
                              items: _categories.map((category) {
                                return DropdownMenuItem(
                                  value: category,
                                  child: Text(category),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedCategory = value;
                                });
                              },
                            ),
                            SizedBox(height: 5),
                            TextField(
                              controller: _priceProductController,
                              decoration: InputDecoration(labelText: 'Harga'),
                              keyboardType: TextInputType.number,
                            ),
                            SizedBox(height: 20),
                            Text(
                              'Upload Foto',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 10),
                            GestureDetector(
                              onTap: _pickImage,
                              child: Container(
                                width: double.infinity,
                                height: 80,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: kIsWeb && _webImage != null
                                    ? Image.memory(
                                  _webImage!,
                                  fit: BoxFit.cover,
                                )
                                    : _productImage != null
                                    ? Image.file(
                                  _productImage!,
                                  fit: BoxFit.cover,
                                )
                                    : Center(
                                  child: Icon(
                                    Icons.add_a_photo,
                                    color: Colors.grey,
                                    size: 40,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 20),
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
                                onPressed: _handleSubmit,
                                child: Text(
                                  'Add Item',
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

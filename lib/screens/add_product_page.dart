import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

const Color primaryColor = Color(0xFF01479E); // Dark Blue
const Color secondaryColor = Color(0xFFFF6F00); // Orange
const Color backgroundColor = Color(0xFFF5F7FA); // Light background

class AddProductPage extends StatefulWidget {
  @override
  _AddProductPageState createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  File? _productImage;
  Uint8List? _webImage; // For web image bytes
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _nameProductController = TextEditingController();
  final TextEditingController _codeProductController = TextEditingController();
  final TextEditingController _priceProductController = TextEditingController();

  String? _selectedCategory;
  List<String> _categories = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    try {
      QuerySnapshot snapshot =
      await FirebaseFirestore.instance.collection('category').get();
      setState(() {
        _categories =
            snapshot.docs.map((doc) => doc['categoryName'].toString()).toList();
      });
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load categories'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      if (kIsWeb) {
        final XFile? pickedImage =
        await _picker.pickImage(source: ImageSource.gallery);
        if (pickedImage != null) {
          final Uint8List imageBytes = await pickedImage.readAsBytes();
          setState(() {
            _webImage = imageBytes;
            _productImage = null;
          });
        }
      } else {
        final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.gallery);
        if (pickedFile != null) {
          setState(() {
            _productImage = File(pickedFile.path);
            _webImage = null;
          });
        }
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<String> _uploadPhoto(String codeProduct) async {
    final String filePath = "products/$codeProduct.jpg";
    final Reference storageRef =
    FirebaseStorage.instance.ref().child(filePath);

    if (kIsWeb && _webImage != null) {
      final UploadTask uploadTask = storageRef.putData(_webImage!);
      final TaskSnapshot taskSnapshot = await uploadTask;
      return await taskSnapshot.ref.getDownloadURL();
    } else if (_productImage != null) {
      final UploadTask uploadTask = storageRef.putFile(_productImage!);
      final TaskSnapshot taskSnapshot = await uploadTask;
      return await taskSnapshot.ref.getDownloadURL();
    } else {
      throw Exception("No image selected");
    }
  }

  Future<void> _saveProduct(String photoUrl) async {
    try {
      await FirebaseFirestore.instance.collection('item').doc().set({
        'category': _selectedCategory,
        'code': _codeProductController.text.trim(),
        'image_url': photoUrl,
        'name': _nameProductController.text.trim(),
        'price': double.parse(_priceProductController.text.trim()),
        'totalRevenue': 0,
        'totalSales': 0,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Product added successfully!'),
            backgroundColor: secondaryColor,
          ),
        );
      }
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint("Error saving product: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save product'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _handleSubmit() async {
    if (_nameProductController.text.trim().isEmpty ||
        _codeProductController.text.trim().isEmpty ||
        _priceProductController.text.trim().isEmpty ||
        _selectedCategory == null ||
        (_productImage == null && _webImage == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please complete all fields and upload an image!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final String photoUrl =
      await _uploadPhoto(_codeProductController.text.trim());
      await _saveProduct(photoUrl);
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildSidebarButton({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    final selectedColor = secondaryColor;
    final unselectedColor = primaryColor.withOpacity(0.7);

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 110,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? secondaryColor.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected
              ? [
            BoxShadow(
              color: secondaryColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: selected ? selectedColor : unselectedColor, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? selectedColor : unselectedColor,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _onSidebarButtonTapped(int index) {
    switch (index) {
      case 0:
        Navigator.of(context).pushNamed('/newOrder');
        break;
      case 1:
        Navigator.of(context).pushNamed('/dashboard');
        break;
      case 2:
        Navigator.of(context).pushNamed('/product');
        break;
      case 3:
        Navigator.of(context).pushNamed('/transaction');
        break;
      case 4:
        Navigator.of(context).pushNamed('/category');
        break;
      case 5:
        Navigator.of(context).pushNamed('/payment');
        break;
      case 6:
        Navigator.of(context).pushNamed('/');
        break;
    }
  }

  @override
  void dispose() {
    _nameProductController.dispose();
    _codeProductController.dispose();
    _priceProductController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryColor),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
      ),
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 110,
            color: backgroundColor,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSidebarButton(
                  icon: Icons.add_shopping_cart_outlined,
                  label: 'New Order',
                  selected: false,
                  onPressed: () => _onSidebarButtonTapped(0),
                ),
                const SizedBox(height: 18),
                _buildSidebarButton(
                  icon: Icons.show_chart_outlined,
                  label: 'Dashboard',
                  selected: false,
                  onPressed: () => _onSidebarButtonTapped(1),
                ),
                const SizedBox(height: 18),
                _buildSidebarButton(
                  icon: Icons.inventory_2_outlined,
                  label: 'Product',
                  selected: true,
                  onPressed: () => _onSidebarButtonTapped(2),
                ),
                const SizedBox(height: 18),
                _buildSidebarButton(
                  icon: Icons.swap_horiz_outlined,
                  label: 'Transaction',
                  selected: false,
                  onPressed: () => _onSidebarButtonTapped(3),
                ),
                const SizedBox(height: 18),
                _buildSidebarButton(
                  icon: Icons.label_outline,
                  label: 'Category',
                  selected: false,
                  onPressed: () => _onSidebarButtonTapped(4),
                ),
                const SizedBox(height: 18),
                _buildSidebarButton(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Payment',
                  selected: false,
                  onPressed: () => _onSidebarButtonTapped(5),
                ),
                const SizedBox(height: 18),
                _buildSidebarButton(
                  icon: Icons.exit_to_app,
                  label: 'Logout',
                  selected: false,
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: backgroundColor,
                        title: Text('Konfirmasi Logout', style: TextStyle(color: primaryColor)),
                        content: Text('Apakah Anda yakin ingin keluar?', style: TextStyle(color: primaryColor)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text('Tidak', style: TextStyle(color: primaryColor)),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              Navigator.of(context).pushNamed('/');
                            },
                            child: Text('Ya', style: TextStyle(color: primaryColor)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Main Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Name
                              TextField(
                                controller: _nameProductController,
                                decoration: InputDecoration(
                                  labelText: 'Nama Item',
                                  labelStyle: TextStyle(color: primaryColor),
                                  filled: true,
                                  fillColor: Colors.white,
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: secondaryColor, width: 2),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: primaryColor.withOpacity(0.3)),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                ),
                                style: TextStyle(color: primaryColor, fontSize: 16),
                              ),
                              const SizedBox(height: 16),
                              // Code
                              TextField(
                                controller: _codeProductController,
                                decoration: InputDecoration(
                                  labelText: 'Kode Item',
                                  labelStyle: TextStyle(color: primaryColor),
                                  filled: true,
                                  fillColor: Colors.white,
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: secondaryColor, width: 2),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: primaryColor.withOpacity(0.3)),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                ),
                                style: TextStyle(color: primaryColor, fontSize: 16),
                              ),
                              const SizedBox(height: 16),
                              // Category Dropdown
                              InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Kategori',
                                  labelStyle: TextStyle(color: primaryColor),
                                  filled: true,
                                  fillColor: Colors.white,
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: secondaryColor, width: 2),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: primaryColor.withOpacity(0.3)),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedCategory,
                                    isExpanded: true,
                                    iconEnabledColor: primaryColor,
                                    hint: Text(
                                      'Pilih Kategori',
                                      style: TextStyle(color: primaryColor.withOpacity(0.5)),
                                    ),
                                    items: _categories.map((category) {
                                      return DropdownMenuItem<String>(
                                        value: category,
                                        child: Text(
                                          category,
                                          style: TextStyle(color: primaryColor),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedCategory = value;
                                      });
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Price
                              TextField(
                                controller: _priceProductController,
                                decoration: InputDecoration(
                                  labelText: 'Harga',
                                  labelStyle: TextStyle(color: primaryColor),
                                  filled: true,
                                  fillColor: Colors.white,
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: secondaryColor, width: 2),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: primaryColor.withOpacity(0.3)),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                ),
                                keyboardType: TextInputType.number,
                                style: TextStyle(color: primaryColor, fontSize: 16),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Upload Foto',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: _pickImage,
                                child: Container(
                                  width: double.infinity,
                                  height: 210,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: primaryColor.withOpacity(0.3)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 8,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                    color: Colors.white,
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: kIsWeb && _webImage != null
                                      ? Image.memory(_webImage!, fit: BoxFit.cover)
                                      : _productImage != null
                                      ? Image.file(_productImage!, fit: BoxFit.cover)
                                      : Center(
                                    child: Icon(
                                      Icons.add_a_photo,
                                      color: primaryColor.withOpacity(0.5),
                                      size: 48,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: secondaryColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 4,
                                  ),
                                  onPressed: _isLoading ? null : _handleSubmit,
                                  child: _isLoading
                                      ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 3,
                                    ),
                                  )
                                      : Text(
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

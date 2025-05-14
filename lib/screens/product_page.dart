import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/sidebar_button.dart';
import '../widgets/summary_box.dart';
import '../widgets/search_bar.dart';
import '../widgets/formatted_date.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ProductPage extends StatefulWidget {
  @override
  _ProductPageState createState() => _ProductPageState();
}

class ProductDataTableSource extends DataTableSource {
  final List<QueryDocumentSnapshot> data;
  final Function(QueryDocumentSnapshot) showEditDialog; // Callback tanpa context

  ProductDataTableSource(this.data, {required this.showEditDialog});

  @override
  DataRow? getRow(int index) {
    if (index >= data.length) return null;

    final item = data[index].data() as Map<String, dynamic>;

    final name = item['name']?.toString() ?? 'N/A';
    final price = item['price']?.toString() ?? 'N/A';
    final category = item['category']?.toString() ?? 'N/A';

    return DataRow(cells: [
      DataCell(
        Center(child: Text(name)),
        onTap: () {
          showEditDialog(data[index]); // Panggil showEditDialog tanpa context
        },
      ),
      DataCell(Center(child:Text(price)),
        onTap: () {
          showEditDialog(data[index]); // Panggil showEditDialog tanpa context
        },
      ),
      DataCell(Center(child: Text(category)),
        onTap: () {
          showEditDialog(data[index]); // Panggil showEditDialog tanpa context
        },
      ),
    ]);
  }


  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => data.length;

  @override
  int get selectedRowCount => 0;
}


class _ProductPageState extends State<ProductPage> {
  int _selectedIndex = 2; // Default selected index
  TextEditingController _searchController = TextEditingController();
  List<QueryDocumentSnapshot> filteredData = [];
  List<QueryDocumentSnapshot> originalData = [];
  double totalRevenue = 0.0;
  int totalOrders = 0;





  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterData); // Tambahkan listener
    _fetchData();
  }

  Future<void> _fetchData() async {
    // Ambil data dari Firestore dan hitung totalRevenue dan totalOrders
    QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('transactionDetails').get();

    // Reset total pendapatan dan jumlah order
    totalRevenue = 0.0;
    totalOrders = 0;

    for (var doc in snapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      int quantity = (data['quantity'] as num).toInt(); // Pastikan quantity selalu integer
      double price = (data['price'] as num).toDouble(); // Pastikan price selalu double
      double revenue = quantity * price;

      totalOrders += quantity; // Tambahkan jumlah order
      totalRevenue += revenue; // Tambahkan total pendapatan
    }

    // Memperbarui state untuk menampilkan nilai baru
    setState(() {});
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterData); // Hapus listener
    _searchController.dispose();
    super.dispose();
  }




  void _filterData() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredData = originalData.where((doc) {
        final item = doc.data() as Map<String, dynamic>;
        final name = item['name']?.toString().toLowerCase() ?? '';
        return name.contains(query);
      }).toList();
    });
  }


  void _onSidebarButtonTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 1:
        Navigator.of(context).pushNamed('/dashboard');
        break;
      case 2:
        Navigator.of(context).pushNamed('/product');
        break;
      case 4:
        Navigator.of(context).pushNamed('/category');
        break;
      case 5:
        Navigator.of(context).pushNamed('/payment');
        break;
      case 3:
        Navigator.of(context).pushNamed('/transaction');
        break;
      case 6:
        Navigator.of(context).pushNamed('/');
        break;
      case 0:
        Navigator.of(context).pushNamed('/newOrder');
        break;
    }
  }

  void _showEditDialog(QueryDocumentSnapshot productDoc) async {
    final product = productDoc.data() as Map<String, dynamic>;
    final productNameController = TextEditingController(text: product['name']);
    final productPriceController = TextEditingController(text: product['price'].toString());
    final productCategoryController = TextEditingController(text: product['category']);
    String? productImageUrl = product['image_url'];


    File? _image;
    Uint8List? _webImage; // Untuk gambar di web
    final ImagePicker _picker = ImagePicker();

    Future<void> _openGallery() async {
      try {
        // Fungsi hanya untuk Android/iOS
        if (Platform.isAndroid || Platform.isIOS) {
          final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
          if (pickedFile != null) {
            setState(() {
              _image = File(pickedFile.path);
            });
          }
        } else {
          // Abaikan platform lain seperti Web
          print("Platform ini tidak mendukung galeri.");
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Galeri hanya didukung di Android/iOS."),
          ));
        }
      } catch (e) {
        print("Error membuka galeri: $e");
      }
    }


    Future<void> _openCamera() async {
      try {
        if (kIsWeb) {
          // Web does not support direct camera access
          print("Camera access is not supported on the web.");
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Camera access is not supported on the web."),
          ));
        } else {
          // For mobile (Android/iOS)
          final XFile? pickedFile = await _picker.pickImage(source: ImageSource.camera);
          if (pickedFile != null) {
            setState(() {
              _image = File(pickedFile.path);
            });
          }
        }
      } catch (e) {
        print("Error opening camera: $e");
      }
    }




    Future<String?> _uploadImage(String codeProduct) async {
      try {
        // Tentukan path untuk menyimpan gambar di Firebase Storage
        final String filePath = "products/$codeProduct.jpg";
        final Reference storageRef = FirebaseStorage.instance.ref().child(filePath);

        // Jika aplikasi dijalankan di web
        if (kIsWeb && _webImage != null) {
          final UploadTask uploadTask = storageRef.putData(_webImage!);
          final TaskSnapshot taskSnapshot = await uploadTask;
          return await taskSnapshot.ref.getDownloadURL(); // Ambil URL gambar
        }
        // Jika aplikasi dijalankan di mobile (Android/iOS)
        else if (_image != null) {
          final UploadTask uploadTask = storageRef.putFile(_image!);
          final TaskSnapshot taskSnapshot = await uploadTask;
          return await taskSnapshot.ref.getDownloadURL(); // Ambil URL gambar
        } else {
          throw Exception("No image selected for upload"); // Jika tidak ada gambar yang dipilih
        }
      } catch (e) {
        print("Error uploading image: $e");
        return null;
      }
    }




    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Product'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: productNameController,
                  decoration: InputDecoration(labelText: 'Product Name'),
                ),
                TextField(
                  controller: productPriceController,
                  decoration: InputDecoration(labelText: 'Product Price'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: productCategoryController,
                  decoration: InputDecoration(labelText: 'Product Category'),
                ),
                SizedBox(height: 10),
                _image != null
                    ? Image.file(_image!, width: 100, height: 100, fit: BoxFit.cover)
                    : productImageUrl != null && productImageUrl.isNotEmpty
                    ? Image.network(productImageUrl, width: 100, height: 100, fit: BoxFit.cover)
                    : Text('No Image Available'),
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _openGallery,
                      child: Text('Gallery'),
                    ),
                    ElevatedButton(
                      onPressed: _openCamera,
                      child: Text('Camera'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                try {
                  String? downloadUrl = productImageUrl;

                  // Jika ada gambar baru, upload gambar
                  if (_image != null || _webImage != null) {
                    downloadUrl = await _uploadImage(product['code']);
                  }

                  // Update data produk di Firestore
                  await FirebaseFirestore.instance.collection('item').doc(productDoc.id).update({
                    'name': productNameController.text,
                    'price': int.parse(productPriceController.text),
                    'category': productCategoryController.text,
                    'image_url': downloadUrl,
                  });

                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Product updated successfully')),
                  );
                } catch (error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update product: $error')),
                  );
                }
              },
              child: Text('Save'),
            ),

            // Tombol untuk menghapus produk
            TextButton(
              onPressed: () {
                deleteProduct(productDoc.id); // Panggil fungsi deleteProduct
                Navigator.of(context).pop();
              },
              child: Text('Delete'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
        );
      },
    );
  }

  void deleteProduct(String productId) {
    FirebaseFirestore.instance.collection('item').doc(productId).delete().then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Product deleted successfully')),
      );
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete product: $error')),
      );
    });
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Konfirmasi Logout'),
          content: Text('Apakah Anda yakin ingin keluar?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Menutup dialog
              },
              child: Text('Tidak'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Menutup dialog
                Navigator.of(context).pushNamed('/'); // Navigasi ke halaman login atau halaman utama
              },
              child: Text('Ya'),
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Product Page', style: TextStyle(color: Colors.grey[700])),
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
              children: [
                SizedBox(height: 15.0),
                SidebarButton(
                  icon: Icons.shopping_bag,
                  label: 'New Order',
                  selected: _selectedIndex == 0,
                  onPressed: () => _onSidebarButtonTapped(0),
                ),
                SizedBox(height: 15.0),
                SidebarButton(
                  icon: Icons.dashboard,
                  label: 'Dashboard',
                  selected: _selectedIndex == 1,
                  onPressed: () => _onSidebarButtonTapped(1),
                ),
                SizedBox(height: 15.0),
                SidebarButton(
                  icon: Icons.coffee,
                  label: 'Product',
                  selected: _selectedIndex == 2,
                  onPressed: () => _onSidebarButtonTapped(2),
                ),
                SizedBox(height: 15.0),
                SidebarButton(
                  icon: Icons.percent,
                  label: 'Transaction',
                  selected: _selectedIndex == 3,
                  onPressed: () => _onSidebarButtonTapped(3),
                ),
                SizedBox(height: 15.0),
                SidebarButton(
                  icon: Icons.category,
                  label: 'Category',
                  selected: _selectedIndex == 4,
                  onPressed: () => _onSidebarButtonTapped(4),
                ),
                SizedBox(height: 15.0),
                SidebarButton(
                  icon: Icons.payment,
                  label: 'Payment',
                  selected: _selectedIndex == 5,
                  onPressed: () => _onSidebarButtonTapped(5),
                ),

                SidebarButton(
                  icon: Icons.logout,
                  label: 'Logout',
                  selected: _selectedIndex == 6,
                  onPressed: () => _showLogoutDialog(context),
                ),
              ],
            ),
          ),
          // Main Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  getFormattedDate(), // Date and Time Row
                  SizedBox(height: 20),
                  // Summary Boxes
                  Row(
                    children: [
                      SummaryBox(
                          label: 'Pendapatan',
                          value: 'Rp ${NumberFormat('#,##0.00', 'id_ID').format(totalRevenue)}',
                          subtitle: 'Total Pendapatan'),
                      SizedBox(width: 20),
                      SummaryBox(label: 'Jumlah Order',
                          value: totalOrders.toString(),
                          subtitle: ' Total Order'),
                    ],
                  ),
                  SizedBox(height: 20),

                  // Ordered Items Table
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title, Search Bar, and Add Button
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Product Page',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                CustomSearchBar(
                                  controller: _searchController,
                                  searchLabel: 'Search Product',
                                ),
                                IconButton(
                                  icon: Icon(Icons.add),
                                  onPressed: () {
                                    Navigator.of(context).pushNamed('/addProduct');
                                  },
                                ),
                              ],
                            ),
                            Divider(),
                            Expanded(
                              child: StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance.collection('item').snapshots(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return Center(child: CircularProgressIndicator());
                                  }
                                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                    return Center(child: Text('No data available'));
                                  }
                                  if(originalData.isEmpty) {
                                    originalData = snapshot.data!.docs;
                                    filteredData = List.from(originalData);
                                  }

                                  final source = ProductDataTableSource(filteredData, showEditDialog: _showEditDialog);

                                  return PaginatedDataTable(
                                      header: Text('Product Page'),
                                      rowsPerPage: 2, // Jumlah baris per halaman
                                      columnSpacing: 80,
                                      headingRowHeight: 50,
                                    columns: [
                                      DataColumn(
                                        label: Container(
                                          width: 150, // Lebar kolom tetap
                                          child: Center(child: Text('Nama Item')),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Container(
                                          width: 100, // Lebar kolom tetap
                                          child: Center(child: Text('Harga')),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Container(
                                          width: 100, // Lebar kolom tetap
                                          child: Center(child: Text('Category')),
                                        ),
                                      ),
                                    ],
                                      source: source,

                                  );
                                },
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

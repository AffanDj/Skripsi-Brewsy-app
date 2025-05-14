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

// Define your app's primary color theme based on the logo colors
const Color primaryColor = Color(0xFF01479E); // Dark Blue
const Color secondaryColor = Color(0xFFFF6F00); // Orange
const Color backgroundColor = Color(0xFFF5F7FA); // Light background

class ProductPage extends StatefulWidget {
  @override
  _ProductPageState createState() => _ProductPageState();
}

class ProductDataTableSource extends DataTableSource {
  final List<QueryDocumentSnapshot> data;
  final Function(QueryDocumentSnapshot) showEditDialog;

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
        Center(
            child: Text(name,
                style: TextStyle(
                    fontSize: 20,
                    color: primaryColor,
                    fontWeight: FontWeight.w600))),
        onTap: () {
          showEditDialog(data[index]);
        },
      ),
      DataCell(
        Center(
            child: Text(price,
                style: TextStyle(
                    fontSize: 20,
                    color: primaryColor.withOpacity(0.85),
                    fontWeight: FontWeight.w500))),
        onTap: () {
          showEditDialog(data[index]);
        },
      ),
      DataCell(
        Center(
            child: Text(category,
                style: TextStyle(
                    fontSize: 20,
                    color: primaryColor.withOpacity(0.7),
                    fontWeight: FontWeight.w500))),
        onTap: () {
          showEditDialog(data[index]);
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
    _searchController.addListener(_filterData);
    _fetchData();
  }

  Future<void> _fetchData() async {
    QuerySnapshot snapshot =
    await FirebaseFirestore.instance.collection('transactionDetails').get();

    double revenueSum = 0.0;
    int ordersSum = 0;

    for (var doc in snapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      int quantity = (data['quantity'] as num).toInt();
      double price = (data['price'] as num).toDouble();
      double revenue = quantity * price;

      ordersSum += quantity;
      revenueSum += revenue;
    }

    setState(() {
      totalRevenue = revenueSum;
      totalOrders = ordersSum;
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterData);
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

  void _showEditDialog(QueryDocumentSnapshot productDoc) async {
    final product = productDoc.data() as Map<String, dynamic>;
    final productNameController = TextEditingController(text: product['name']);
    final productPriceController =
    TextEditingController(text: product['price'].toString());
    final productCategoryController =
    TextEditingController(text: product['category']);
    String? productImageUrl = product['image_url'];

    File? _image;
    Uint8List? _webImage;
    final ImagePicker _picker = ImagePicker();

    Future<void> _openGallery() async {
      try {
        if (Platform.isAndroid || Platform.isIOS) {
          final XFile? pickedFile =
          await _picker.pickImage(source: ImageSource.gallery);
          if (pickedFile != null) {
            setState(() {
              _image = File(pickedFile.path);
            });
          }
        } else if (kIsWeb) {
          final XFile? pickedFile =
          await _picker.pickImage(source: ImageSource.gallery);
          if (pickedFile != null) {
            _webImage = await pickedFile.readAsBytes();
            setState(() {});
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Gallery only supported on Android/iOS/Web."),
          ));
        }
      } catch (e) {
        print("Error opening gallery: $e");
      }
    }

    Future<void> _openCamera() async {
      try {
        if (kIsWeb) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Camera access is not supported on the web."),
          ));
        } else {
          final XFile? pickedFile =
          await _picker.pickImage(source: ImageSource.camera);
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
        final String filePath = "products/$codeProduct.jpg";
        final Reference storageRef =
        FirebaseStorage.instance.ref().child(filePath);

        if (kIsWeb && _webImage != null) {
          final UploadTask uploadTask = storageRef.putData(_webImage!);
          final TaskSnapshot taskSnapshot = await uploadTask;
          return await taskSnapshot.ref.getDownloadURL();
        } else if (_image != null) {
          final UploadTask uploadTask = storageRef.putFile(_image!);
          final TaskSnapshot taskSnapshot = await uploadTask;
          return await taskSnapshot.ref.getDownloadURL();
        } else {
          throw Exception("No image selected for upload");
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
          backgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Edit Product',
              style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 24)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Image preview with rounded corners and shadow
                Container(
                  width: 300,
                  height: 210,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
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
                  child: _image != null
                      ? Image.file(_image!, fit: BoxFit.cover)
                      : (productImageUrl != null && productImageUrl.isNotEmpty)
                      ? Image.network(productImageUrl, fit: BoxFit.cover)
                      : Center(
                    child: Text('No Image',
                        style: TextStyle(
                            color: primaryColor.withOpacity(0.5),
                            fontSize: 16,
                            fontWeight: FontWeight.w500)),
                  ),
                ),
                const SizedBox(height: 26),
                // Buttons for image selection with icons and color
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: secondaryColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        elevation: 4,
                      ),
                      onPressed: _openGallery,
                      icon: Icon(Icons.photo_library, color: Colors.white),
                      label: Text('Gallery',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 200),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: secondaryColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        elevation: 4,
                      ),
                      onPressed: _openCamera,
                      icon: Icon(Icons.camera_alt, color: Colors.white),
                      label: Text('Camera',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Form fields with filled style and rounded borders
                TextField(
                  controller: productNameController,
                  decoration: InputDecoration(
                    labelText: 'Product Name',
                    labelStyle: TextStyle(color: primaryColor),
                    filled: true,
                    fillColor: Colors.white,
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: secondaryColor, width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                      BorderSide(color: primaryColor.withOpacity(0.3)),
                    ),
                    contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  style: TextStyle(color: primaryColor, fontSize: 16),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: productPriceController,
                  decoration: InputDecoration(
                    labelText: 'Product Price',
                    labelStyle: TextStyle(color: primaryColor),
                    filled: true,
                    fillColor: Colors.white,
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: secondaryColor, width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                      BorderSide(color: primaryColor.withOpacity(0.3)),
                    ),
                    contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: primaryColor, fontSize: 16),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: productCategoryController,
                  decoration: InputDecoration(
                    labelText: 'Product Category',
                    labelStyle: TextStyle(color: primaryColor),
                    filled: true,
                    fillColor: Colors.white,
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: secondaryColor, width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                      BorderSide(color: primaryColor.withOpacity(0.3)),
                    ),
                    contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  style: TextStyle(color: primaryColor, fontSize: 16),
                ),
              ],
            ),
          ),
          actionsPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 25),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () {
                deleteProduct(productDoc.id);
                Navigator.of(context).pop();
              },
              child: Text('Delete',
                  style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: secondaryColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                elevation: 4,
              ),
              onPressed: () async {
                try {
                  String? downloadUrl = productImageUrl;

                  if (_image != null || _webImage != null) {
                    downloadUrl = await _uploadImage(product['code']);
                  }

                  await FirebaseFirestore.instance
                      .collection('item')
                      .doc(productDoc.id)
                      .update({
                    'name': productNameController.text,
                    'price': int.parse(productPriceController.text),
                    'category': productCategoryController.text,
                    'image_url': downloadUrl,
                  });

                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Product updated successfully'),
                        backgroundColor: secondaryColor),
                  );
                } catch (error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Failed to update product: $error'),
                        backgroundColor: Colors.redAccent),
                  );
                }
              },
              child: Text('Save',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ),
          ],
        );
      },
    );
  }

  void deleteProduct(String productId) {
    FirebaseFirestore.instance.collection('item').doc(productId).delete().then(
          (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Product deleted successfully'),
              backgroundColor: secondaryColor),
        );
      },
    ).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to delete product: $error'),
            backgroundColor: Colors.redAccent),
      );
    });
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: backgroundColor,
          title: Text('Konfirmasi Logout', style: TextStyle(color: primaryColor)),
          content:
          Text('Apakah Anda yakin ingin keluar?', style: TextStyle(color: primaryColor)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
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
        );
      },
    );
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

  Widget _getFormattedDate() {
    final now = DateTime.now();
    final formattedDate = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(now);
    final formattedTime = DateFormat('HH:mm').format(now);
    return Text(
      '$formattedDate - $formattedTime',
      style: TextStyle(
        fontSize: 16,
        color: primaryColor,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildSummaryBox({
    required String label,
    required String value,
    required String subtitle,
    required Color borderColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: borderColor, width: 6)),
          boxShadow: [
            BoxShadow(
              color: borderColor.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: primaryColor.withOpacity(0.7))),
            const SizedBox(height: 10),
            Text(value,
                style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: primaryColor)),
            const SizedBox(height: 6),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: primaryColor.withOpacity(0.4))),
          ],
        ),
      ),
    );
  }

  Widget _buildRoundedSearchBar() {
    return Container(
      width: 250,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30), // Rounded corners
        border: Border.all(color: primaryColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.1),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: primaryColor),
        decoration: InputDecoration(
          hintText: 'Search Product',
          hintStyle: TextStyle(color: primaryColor.withOpacity(0.5)),
          prefixIcon: Icon(Icons.search, color: primaryColor.withOpacity(0.7)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 110,
            color: backgroundColor,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 15),
                _buildSidebarButton(
                  icon: Icons.add_shopping_cart_outlined,
                  label: 'New Order',
                  selected: _selectedIndex == 0,
                  onPressed: () => _onSidebarButtonTapped(0),
                ),
                const SizedBox(height: 18),
                _buildSidebarButton(
                  icon: Icons.show_chart_outlined,
                  label: 'Dashboard',
                  selected: _selectedIndex == 1,
                  onPressed: () => _onSidebarButtonTapped(1),
                ),
                const SizedBox(height: 18),
                _buildSidebarButton(
                  icon: Icons.inventory_2_outlined,
                  label: 'Product',
                  selected: _selectedIndex == 2,
                  onPressed: () => _onSidebarButtonTapped(2),
                ),
                const SizedBox(height: 18),
                _buildSidebarButton(
                  icon: Icons.swap_horiz_outlined,
                  label: 'Transaction',
                  selected: _selectedIndex == 3,
                  onPressed: () => _onSidebarButtonTapped(3),
                ),
                const SizedBox(height: 18),
                _buildSidebarButton(
                  icon: Icons.label_outline,
                  label: 'Category',
                  selected: _selectedIndex == 4,
                  onPressed: () => _onSidebarButtonTapped(4),
                ),
                const SizedBox(height: 18),
                _buildSidebarButton(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Payment',
                  selected: _selectedIndex == 5,
                  onPressed: () => _onSidebarButtonTapped(5),
                ),
                const SizedBox(height: 18),
                _buildSidebarButton(
                  icon: Icons.exit_to_app,
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
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _getFormattedDate(),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _buildSummaryBox(
                        label: 'Pendapatan',
                        value:
                        'Rp ${NumberFormat('#,##0.00', 'id_ID').format(totalRevenue)}',
                        subtitle: 'Total Pendapatan',
                        borderColor: secondaryColor,
                      ),
                      const SizedBox(width: 20),
                      _buildSummaryBox(
                        label: 'Jumlah Order',
                        value: totalOrders.toString(),
                        subtitle: 'Total Order',
                        borderColor: primaryColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title, Rounded Search Bar, and Add Button
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Product Page',
                                  style: TextStyle(
                                      fontSize: 25,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor),
                                ),
                                Row(
                                  children: [
                                    _buildRoundedSearchBar(),
                                    const SizedBox(width: 12),
                                    IconButton(
                                      icon: Icon(Icons.add, color: secondaryColor),
                                      onPressed: () {
                                        Navigator.of(context)
                                            .pushNamed('/addProduct');
                                      },
                                      tooltip: 'Add Product',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Divider(color: primaryColor.withOpacity(0.3)),
                            Expanded(
                              child: StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('item')
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return Center(
                                        child: CircularProgressIndicator(
                                            color: primaryColor));
                                  }
                                  if (!snapshot.hasData ||
                                      snapshot.data!.docs.isEmpty) {
                                    return Center(
                                        child: Text('No data available',
                                            style: TextStyle(
                                                color:
                                                primaryColor.withOpacity(0.4),
                                                fontSize: 16)));
                                  }
                                  if (originalData.isEmpty) {
                                    originalData = snapshot.data!.docs;
                                    filteredData = List.from(originalData);
                                  }

                                  final source = ProductDataTableSource(
                                    filteredData,
                                    showEditDialog: _showEditDialog,
                                  );

                                  return PaginatedDataTable(
                                    header: Text('Product List',
                                        style: TextStyle(
                                            color: primaryColor,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 25)),
                                    rowsPerPage: 6,
                                    columnSpacing: 60,
                                    headingRowHeight: 56,
                                    dataRowHeight: 56,
                                    columns: [
                                      DataColumn(
                                        label: SizedBox(
                                          width: 260,
                                          child: Center(
                                            child: Text('Nama Item',
                                                style: TextStyle(
                                                    fontSize: 22,
                                                    color: primaryColor,
                                                    fontWeight: FontWeight.w600)),
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: SizedBox(
                                          width: 210,
                                          child: Center(
                                            child: Text('Harga',
                                                style: TextStyle(
                                                    fontSize: 22,
                                                    color: primaryColor,
                                                    fontWeight:
                                                    FontWeight.w600)),
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: SizedBox(
                                          width: 210,
                                          child: Center(
                                            child: Text('Category',
                                                style: TextStyle(
                                                    fontSize: 22,
                                                    color: primaryColor,
                                                    fontWeight:
                                                    FontWeight.w600)),
                                          ),
                                        ),
                                      ),
                                    ],
                                    source: source,
                                    showCheckboxColumn: false,
                                    horizontalMargin: 24,
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
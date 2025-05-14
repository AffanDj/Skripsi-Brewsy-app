import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/sidebar_button.dart';
import '../widgets/summary_box.dart';
import '../widgets/search_bar.dart'; // Import SearchBar
import '../widgets/formatted_date.dart';


class CategoryPage extends StatefulWidget {
  @override
  _CategoryPageState createState() => _CategoryPageState();
}

class CategoryDataTableSource extends DataTableSource {
  final List<QueryDocumentSnapshot> data;
  final Function(QueryDocumentSnapshot) showEditDialog; // Callback tanpa context

  CategoryDataTableSource(this.data, this.showEditDialog);

  @override
  DataRow? getRow(int index) {
    if (index >= data.length) return null;

    final category = data[index].data() as Map<String, dynamic>;
    final categoryName = category['categoryName']?.toString() ?? 'N/A';

    return DataRow(
      cells: [
        DataCell(
          Text(categoryName),
          onTap: () {
            showEditDialog(data[index]); // Panggil showEditDialog tanpa context
          },
        ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => data.length;

  @override
  int get selectedRowCount => 0;
}

class _CategoryPageState extends State<CategoryPage> {
  int _selectedIndex = 4;
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
    _searchController.removeListener(_filterData);
    _searchController.dispose();
    super.dispose();
  }

  void _filterData() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredData = originalData.where((doc) {
        final category = doc.data() as Map<String, dynamic>;
        final name = category['categoryName']?.toString().toLowerCase() ?? '';
        return name.contains(query);
      }).toList();
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

  void _onSidebarButtonTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 1) {
      Navigator.of(context).pushNamed('/dashboard');
    }
    if (index == 2) {
      Navigator.of(context).pushNamed('/product');
    }
    if (index == 4) {
      Navigator.of(context).pushNamed('/category');
    }
    if (index == 5) {
      Navigator.of(context).pushNamed('/payment');
    }
    if (index == 3) {
      Navigator.of(context).pushNamed('/transaction');
    }
    if (index == 6) {
      Navigator.of(context).pushNamed('/');
    }
    if (index == 0) {
      Navigator.of(context).pushNamed('/newOrder');
    }
  }

  // Menambahkan metode _showEditDialog
  void _showEditDialog(QueryDocumentSnapshot categoryDoc) {
    final category = categoryDoc.data() as Map<String, dynamic>;
    final categoryNameController = TextEditingController(text: category['categoryName']);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Category'),
          content: TextField(
            controller: categoryNameController,
            decoration: InputDecoration(labelText: 'Category Name'),
          ),
          actions: [
            // Tombol untuk menyimpan perubahan
            TextButton(
              onPressed: () {
                FirebaseFirestore.instance.collection('category').doc(categoryDoc.id).update({
                  'categoryName': categoryNameController.text,
                }).then((_) {
                  Navigator.of(context).pop();
                });
              },
              child: Text('Save'),
            ),
            // Tombol untuk membatalkan perubahan
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            // Tombol untuk menghapus kategori
            TextButton(
              onPressed: () {
                deleteCategory(categoryDoc.id); // Panggil fungsi deleteCategory
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

// Fungsi untuk menghapus kategori dari Firestore
  void deleteCategory(String categoryId) {
    FirebaseFirestore.instance.collection('category').doc(categoryId).delete().then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Category deleted successfully')),
      );
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete category: $error')),
      );
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        automaticallyImplyLeading: false, // Menonaktifkan tombol bac
        title: Text('Category Page', style: TextStyle(color: Colors.grey[700])),
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
                SizedBox(height: 15.0),
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
                  // Date and Time Row
                  getFormattedDate(),
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
                            // Menambahkan Row untuk judul, search bar dan tombol +
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Teks 'Product Page'
                                Text(
                                  'Category Page',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                CustomSearchBar(
                                  controller: _searchController,
                                  searchLabel: 'Search Category',
                                ),
                                IconButton(
                                  icon: Icon(Icons.add),
                                  onPressed: () {
                                    Navigator.of(context).pushNamed('/addCategory');
                                  },
                                ),
                              ],
                            ),
                            Divider(),
                            Expanded(
                              child: StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance.collection('category').snapshots(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return Center(child: CircularProgressIndicator());
                                  }
                                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                    return Center(child: Text('No data available'));
                                  }
                                  if (originalData.isEmpty) {
                                    originalData = snapshot.data!.docs;
                                    filteredData = List.from(originalData);
                                  }

                                  final source = CategoryDataTableSource(filteredData, _showEditDialog);

                                  return PaginatedDataTable(
                                    rowsPerPage: 2,
                                    columnSpacing: 20,
                                    headingRowHeight: 50,
                                    columns: [
                                      DataColumn(
                                        label: Container(
                                          width: 500,
                                          child: Text('Nama Category', textAlign: TextAlign.center),
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


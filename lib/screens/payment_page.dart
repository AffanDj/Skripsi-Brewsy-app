import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/sidebar_button.dart';
import '../widgets/summary_box.dart';
import '../widgets/search_bar.dart';// Import SearchBar
import '../widgets/formatted_date.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class PaymentPage extends StatefulWidget {
  @override
  _PaymentPageState createState() => _PaymentPageState();
}

class PaymentDataTableSource extends DataTableSource {
  final List<QueryDocumentSnapshot> data;
  final Function(QueryDocumentSnapshot) showEditDialog;

  PaymentDataTableSource(this.data, this.showEditDialog);

  @override
  DataRow? getRow(int index) {
    if (index >= data.length) return null;

    final paymentType = data[index].data() as Map<String, dynamic>;

    final paymentName = paymentType['paymentName']?.toString() ?? 'N/A';

    return DataRow(cells: [
      DataCell(Text(paymentName),
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

class _PaymentPageState extends State<PaymentPage> {
  int _selectedIndex = 5;  // Default index select =  'Payment'
  TextEditingController _searchController = TextEditingController(); // Controller untuk search bar
  List<QueryDocumentSnapshot> filteredData = [];
  List<QueryDocumentSnapshot> originalData = [];
  double totalRevenue = 0.0;
  int totalOrders = 0;

  @override
  void initState(){
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
  void dispose(){
    _searchController.removeListener(_filterData);
    _searchController.dispose();
    super.dispose();
  }

  void _filterData(){
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredData = originalData.where((doc){
        final paymentType = doc.data() as Map<String, dynamic>;
        final paymentName = paymentType['paymentName']?.toString().toLowerCase() ?? '';
        return paymentName.contains(query);
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
    } // navigasi Dashboard

    if (index == 2) {
      Navigator.of(context).pushNamed('/product');
    } // navigasi product

    if (index == 4) {
      Navigator.of(context).pushNamed('/category');
    } // navigasi category

    if (index == 5) {
      Navigator.of(context).pushNamed('/payment');
    } // navigasi payment

    if (index == 3) {
      Navigator.of(context).pushNamed('/transaction');
    } // navigasi transaction

    if(index == 6){
      Navigator.of(context).pushNamed('/');
    }

    if (index == 0 ){
      Navigator.of(context).pushNamed('/newOrder');
    }
  }

  void _showEditDialog(QueryDocumentSnapshot paymentDoc){
    final payment = paymentDoc.data() as Map<String, dynamic>;
    final paymentNameController = TextEditingController(text: payment['paymentName']);


    showDialog(
      context: context,
      builder: (context){
        return AlertDialog(
          title: Text('Edit Payment'),
          content: TextField(
            controller: paymentNameController,
            decoration:InputDecoration(labelText: 'Payment Name'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                FirebaseFirestore.instance.collection('paymentType').doc(paymentDoc.id).update({
                  'paymentName' : paymentNameController.text,
                }).then((_){
                  Navigator.of(context).pop();
                });
              },
              child: Text('Save'),
            ),
            TextButton(
              onPressed: (){
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: (){
                deletePayment(paymentDoc.id);
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

    void deletePayment (String paymentId){
        FirebaseFirestore.instance.collection('paymentType').doc(paymentId).delete().then((_){
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Payment deleted successfully')),
          );
        }).catchError((error){
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed To delete Payment: $error')),
            );
        });
    }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Payment Page', style: TextStyle(color: Colors.grey[700])),
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
                                  'Payment Page',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),


                                CustomSearchBar(
                                  controller: _searchController,
                                  searchLabel: 'Search Payment',
                                ),

                                // Tombol +
                                IconButton(
                                  icon: Icon(Icons.add),
                                  onPressed: () {
                                    Navigator.of(context).pushNamed('/addPayment');
                                  },
                                ),
                              ],
                            ),

                            Divider(),
                            Expanded(
                              child: StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance.collection('paymentType').snapshots(),
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

                                  final source = PaymentDataTableSource(
                                      filteredData,
                                      _showEditDialog);

                                  return PaginatedDataTable(
                                    rowsPerPage: 2, // Jumlah baris per halaman
                                    columnSpacing: 40,
                                    headingRowHeight: 50,
                                    columns: [
                                      DataColumn(
                                        label: Container(
                                          width: 500,
                                          child: Text('Nama Payment', textAlign: TextAlign.center),
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

  DataRow dataRow(String itemName) {
    return DataRow(cells: [
      DataCell(Text(itemName)),
    ]);
  }
}

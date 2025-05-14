import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/sidebar_button.dart';
import '../widgets/summary_box.dart';
import '../widgets/search_bar.dart'; // Import SearchBar
import '../widgets/formatted_date.dart';

class TransactionPage extends StatefulWidget {
  @override
  _TransactionPageState createState() => _TransactionPageState();
}

class TransactionDataTableSource extends DataTableSource {
  final List<QueryDocumentSnapshot> data;
  final Function(String) showTransactionDetail;

  TransactionDataTableSource(this.data, {required this.showTransactionDetail});

  @override
  @override
  DataRow? getRow(int index) {
    if (index >= data.length) return null;

    final item = data[index].data() as Map<String, dynamic>;

    return DataRow(cells: [
      DataCell(Text(item['customerName'] ?? 'Unknown Customer')),
      DataCell(Text(DateFormat('dd/MM/yyyy').format(item['createdAt']?.toDate() ?? DateTime.now()))),
      DataCell(Text('Rp ${item['amount'] ?? 0}')),
      DataCell(Text(item['tableNumber'] ?? 'N/A')),
      DataCell(Text(item['status'] ?? 'Unknown Status')),
    ], onSelectChanged: (selected) {
      if (selected ?? false) {
        showTransactionDetail(item['orderId']);
      }
    });
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => data.length;

  @override
  int get selectedRowCount => 0;
}

class _TransactionPageState extends State<TransactionPage> {
  int _selectedIndex = 3;  // Default selected index is 'Transaction'
  TextEditingController _searchController = TextEditingController(); // Controller for search bar
  FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;  // To indicate loading more data
  DocumentSnapshot? _lastDocument;  // Store the last document for pagination
  List<QueryDocumentSnapshot> _orders = [];  // List to store the fetched orders
  List<QueryDocumentSnapshot> _filteredOrders = []; // List for filtered orders
  double totalRevenue = 0.0;
  int totalOrders = 0;
  DateTime? _selectedDate;
  bool _noDataFound = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterOrders); // Add listener for search
    _fetchOrders(); // Fetch initial orders
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
    _searchController.removeListener(_filterOrders); // Remove listener
    _searchController.dispose();
    super.dispose();
  }

  // Function to fetch the orders based on search query and pagination
  Future<void> _fetchOrders({bool isSearch = false}) async {
    if (_isLoading) return; // Prevent fetching while already loading
    setState(() {
      _isLoading = true;
    });

    Query query = _firestore.collection('orders').orderBy('createdAt').limit(10);

    // If there's a search query, add a where clause
    if (_searchController.text.isNotEmpty) {
      query = query.where('customerName', isGreaterThanOrEqualTo: _searchController.text)
          .where('customerName', isLessThanOrEqualTo: _searchController.text + '\uf8ff');
    }

    // Jika ada tanggal yang dipilih, tambahkan filter berdasarkan createdAt
    if (_selectedDate != null) {
      DateTime startOfDay = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
      DateTime endOfDay = startOfDay.add(Duration(days: 1)).subtract(Duration(seconds: 1));

      query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay));
    }

    // If there's a last document, use it for pagination
    if (_lastDocument != null && !isSearch) {
      query = query.startAfterDocument(_lastDocument!);
    }

    try {
      QuerySnapshot querySnapshot = await query.get();
      _lastDocument = querySnapshot.docs.isEmpty ? null : querySnapshot.docs.last;

      setState(() {
        if (isSearch) {
          _orders.clear(); // Reset data lama saat pencarian baru
        }
        _orders.addAll(querySnapshot.docs);
        _filteredOrders = List.from(_orders); // Inisialisasi filtered orders
      });

      // Jika tidak ada data yang ditemukan, set state kosong
      if (_filteredOrders.isEmpty) {
        setState(() {
          _noDataFound = true;
        });
      } else {
        setState(() {
          _noDataFound = false;
        });
      }

    } catch (e) {
      print('Error fetching orders: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }

  }

  void _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchOrders(isSearch: true); // Fetch ulang berdasarkan tanggal
    }
  }




  void _filterOrders() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      _filteredOrders = _orders.where((doc) {
        final item = doc.data() as Map<String, dynamic>;

        // Get customer name and order date
        final customerName = item['customerName']?.toString().toLowerCase() ?? '';
        final createdAt = item['createdAt']?.toDate(); // Convert Timestamp to DateTime

        // Filter by customer name
        final matchesName = customerName.contains(query);

        // Check if the query is a valid date
        DateTime? queryDate;
        try {
          queryDate = DateFormat('yyyy-MM-dd').parseStrict(query);
        } catch (_) {
          queryDate = null; // Not a valid date
        }

        // Filter by date if the query is a valid date
        final matchesDate = queryDate != null &&
            createdAt != null && // Ensure createdAt is not null
            createdAt.isAfter(queryDate.subtract(Duration(seconds: 1))) &&
            createdAt.isBefore(queryDate.add(Duration(days: 1)));

        // Return true if it matches either name or date
        return matchesName || matchesDate;
      }).toList();

      // Jika tidak ada data yang cocok dengan filter
      if (_filteredOrders.isEmpty) {
        // Tampilkan pesan bahwa tidak ada data yang cocok
        print('No data found for the selected date or search query.');
      }
    });
  }

  void _updateOrderStatus(String orderId, String newStatus) async {
    try {
      // Mencari dokumen berdasarkan field 'orderId'
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('orderId', isEqualTo: orderId)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        // Jika dokumen ditemukan, ambil dokumen pertama
        DocumentSnapshot document = querySnapshot.docs.first;

        // Memperbarui status
        await document.reference.update({
          'status': newStatus,
        });

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status updated to $newStatus')));
      } else {
        print('No document found with orderId: $orderId');
      }
    } catch (e) {
      print('Error updating status: $e');
    }
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


// Function to show transaction details when clicked
  void _showTransactionDetail(String orderId) async {
    QuerySnapshot detailSnapshot = await FirebaseFirestore.instance
        .collection('transactionDetails')
        .where('orderId', isEqualTo: orderId)
        .get();

    if (detailSnapshot.docs.isEmpty) {
      print('No details found for orderId: $orderId');
    } else {
      detailSnapshot.docs.forEach((doc) {
        print('Found document: ${doc.id}, data: ${doc.data()}');
      });
    }

    List<Map<String, dynamic>> details = detailSnapshot.docs
        .map((doc) => doc.data() as Map<String, dynamic>)
        .toList();

    String selectedStatus = 'in-progress'; // Default status

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Transaction Detail'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...details.map((detail) {
                    return Text(
                        'Product: ${detail['productName']}, Qty: ${detail['quantity']}');
                  }).toList(),
                  SizedBox(height: 20),
                  Text('Select Status:'),
                  DropdownButton<String>(
                    value: selectedStatus,
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedStatus = newValue!;
                      });
                    },
                    items: <String>['in-progress', 'delivered', 'canceled']
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                _updateOrderStatus(orderId, selectedStatus); // Update status
                Navigator.pop(context);
              },
              child: Text('Update Status'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
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
        title: Text('Transaction Page', style: TextStyle(color: Colors.grey[700])),
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
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title, Search Bar
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Transaction Page',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                Row(
                                  children: [
                                CustomSearchBar(
                                  controller: _searchController,
                                  searchLabel: 'Search Transaction',
                                ),
                                  IconButton(
                                      icon: Icon(Icons.calendar_today),
                                      onPressed: () => _selectDate(context),
                                  ),
                              ],
                                ),
                            ],
                            ),
                            Divider(),
                            Expanded(
                              child: StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance.collection('orders').snapshots(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return Center(child: CircularProgressIndicator());
                                  }
                                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                    return Center(child: Text('No data available'));
                                  }
                                  if (_orders.isEmpty) {
                                    _orders = snapshot.data!.docs;
                                    _filteredOrders = List.from(_orders);
                                  }

                                  final source = TransactionDataTableSource(_filteredOrders, showTransactionDetail: _showTransactionDetail);

                                  return PaginatedDataTable(
                                    header: Text('Transaction Page'),
                                    rowsPerPage: 2, // Jumlah baris per halaman
                                    columnSpacing: 35,
                                    headingRowHeight: 50,
                                    showCheckboxColumn: false,
                                    columns: [
                                      DataColumn(label: Text('Nama Customer')),
                                      DataColumn(label: Text('Tanggal Order')),
                                      DataColumn(label: Text('Total Harga')),
                                      DataColumn(label: Text('No Meja')),
                                      DataColumn(label: Text('Status')), // Menambahkan kolom status
                                    ],
                                    source: TransactionDataTableSource(_filteredOrders, showTransactionDetail: _showTransactionDetail),
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

    if (index == 6) {
      Navigator.of(context).pushNamed('/');
    }

    if (index == 0) {
      Navigator.of(context).pushNamed('/newOrder');
    }
  }
}
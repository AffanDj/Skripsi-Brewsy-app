import 'package:cloud_functions/cloud_functions.dart'; // Import Firebase Cloud Functions
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/sidebar_button.dart';
import '../widgets/summary_box.dart';
import '../widgets/formatted_date.dart';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'dart:html' as html;
import 'dart:convert';

class DashboardPage extends StatefulWidget {
  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 1;
  double totalRevenue = 0.0;
  int totalOrders = 0;
  DateTime? _selectedDate;
  FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, Map<String, dynamic>> aggregatedData = {};

  @override
  void initState() {
    _selectedDate = DateTime( DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    super.initState();
    _fetchData();
    debugPrint('date: $_selectedDate');
  }

  Future<void> _fetchData() async {
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('transactionDetails')
        .get();

    totalRevenue = 0.0;
    totalOrders = 0;
    aggregatedData.clear(); // tambahkan ini

    for (var doc in snapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      String itemName = data['name'] ?? 'Unknown';
      int quantity = (data['quantity'] as num).toInt();
      double price = (data['price'] as num).toDouble();
      double revenue = quantity * price;

      totalOrders += quantity;
      totalRevenue += revenue;

      if (aggregatedData.containsKey(itemName)) {
        aggregatedData[itemName]!['quantity'] += quantity;
        aggregatedData[itemName]!['revenue'] += revenue;
      } else {
        aggregatedData[itemName] = {
          'quantity': quantity,
          'price': price,
          'revenue': revenue,
        };
      }
    }

    setState(() {});
  }

  // Future<void> _sendCsvByEmail(String csvData) async {
  //   final String formattedDate = DateFormat('yyyyMMdd').format(DateTime.now());
  //   try {
  //     // Ambil email pengguna yang sedang login
  //     String? userEmail = FirebaseAuth.instance.currentUser?.email;
  //
  //     if (userEmail != null) {
  //       final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('sendCsvToEmail');
  //       await callable.call({
  //         'email': userEmail,
  //         'csvData': csvData,
  //         'name' : formattedDate,
  //       });
  //
  //       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('CSV berhasil dikirim ke email Anda!')));
  //     } else {
  //       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pengguna belum login!')));
  //     }
  //   } catch (e) {
  //     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Terjadi kesalahan saat mengirim email')));
  //   }
  // }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
    debugPrint('tanggalnya: $_selectedDate');
  }

  Future<void> _downloadCsvFile(String csvData) async {
    try {
      if (kIsWeb) {
        // ✅ Web: download lewat AnchorElement
        final String formattedDate = DateFormat('yyyyMMdd').format(DateTime.now());
        final bytes = utf8.encode(csvData);
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', 'laporan_$formattedDate.csv')
          ..click();
        html.Url.revokeObjectUrl(url);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File CSV berhasil diunduh (Web)')),
        );
        return;
      }

      // ✅ Android/iOS
      Directory? directory;

      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory();
        String newPath = "";
        List<String> folders = directory!.path.split("/");

        for (int i = 1; i < folders.length; i++) {
          String folder = folders[i];
          if (folder != "Android") {
            newPath += "/$folder";
          } else {
            break;
          }
        }
        newPath = "$newPath/Download";
        directory = Directory(newPath);
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      }

      if (!(await directory!.exists())) {
        await directory.create(recursive: true);
      }

      final String formattedDate = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final String filePath = '${directory.path}/laporan_$formattedDate.csv';

      final File file = File(filePath);
      await file.writeAsString(csvData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File CSV berhasil disimpan di: $filePath')),
      );
    } catch (e) {
      print('Error saat menyimpan file CSV: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan file CSV')),
      );
    }
  }

  Future<void> _exportToCSV() async {
    if (_selectedDate == null) return;

    DateTime startOfDay = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
    DateTime endOfDay = startOfDay.add(Duration(days: 1)).subtract(Duration(seconds: 1));

    // Step 1: Ambil orderID dari orders
    QuerySnapshot orderSnapshot = await FirebaseFirestore.instance
        .collection('orders')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .get();

    List<String> orderIDs = orderSnapshot.docs.map((doc) => (doc.data() as Map<String, dynamic>)['orderId']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();

    if (orderIDs.isEmpty) {
      debugPrint('Tidak ada orders untuk tanggal tersebut.');
      return;
    }

    List<QueryDocumentSnapshot> allTransactionDocs = [];

    for (int i = 0; i < orderIDs.length; i += 10) {
      final batchIds = orderIDs.sublist(i, (i + 10 > orderIDs.length) ? orderIDs.length : i + 10);
      QuerySnapshot transactionSnapshot = await FirebaseFirestore.instance
          .collection('transactionDetails')
          .where('orderId', whereIn: batchIds)
          .get();

      allTransactionDocs.addAll(transactionSnapshot.docs);
    }

    Map<String, Map<String, dynamic>> aggregatedData = {};

    for (var doc in allTransactionDocs) {
      var data = doc.data() as Map<String, dynamic>;
      String itemName = data['productName'] ?? 'Unknown';
      int quantity = (data['quantity'] as num).toInt();
      double price = (data['price'] as num).toDouble();
      double revenue = quantity * price;

      if (aggregatedData.containsKey(itemName)) {
        aggregatedData[itemName]!['quantity'] += quantity;
        aggregatedData[itemName]!['revenue'] += revenue;
      } else {
        aggregatedData[itemName] = {
          'quantity': quantity,
          'price': price,
          'revenue': revenue,
        };
      }
    }

    // Step 3: Convert to CSV
    List<List<String>> csvData = [
      ['Nama Item', 'Jumlah Order', 'Harga', 'Pendapatan'],
      ...aggregatedData.entries.map((entry) => [
        entry.key,
        entry.value['quantity'].toString(),
        'Rp ${NumberFormat('#,##0.00', 'id_ID').format(entry.value['price'])}',
        'Rp ${NumberFormat('#,##0.00', 'id_ID').format(entry.value['revenue'])}',
      ]),
    ];

    debugPrint('Download CSV Data: $csvData');

    String generateCsvData(List<List<String>> data) {
      return data.map((row) => row.map((cell) => '"$cell"').join(';')).join('\n');
    }
    String csvString = generateCsvData(csvData);
    await _downloadCsvFile(csvString);
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

    // Navigasi berdasarkan index
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Dashboard Page', style: TextStyle(color: Colors.grey[700])),
        backgroundColor: Colors.grey[300],
        elevation: 0,
      ),
      body: Row(
        children: [
          // Sidebar code remains the same...
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
                      SummaryBox(label: 'Pendapatan', value: 'Rp ${NumberFormat('#,##0.00', 'id_ID').format(totalRevenue)}', subtitle: 'Total Pendapatan'),
                      SizedBox(width: 20),
                      SummaryBox(label: 'Jumlah Order', value: totalOrders.toString(), subtitle: ' Total Order'),
                    ],
                  ),
                  SizedBox(height: 20),
                  // Table and other widgets...
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('transactionDetails').snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(child: Text('No data available'));
                        }


                        // Menghitung jumlah dan pendapatan
                        Map<String, Map<String, dynamic>> aggregatedData = {};

                        for (var doc in snapshot.data!.docs) {
                          var data = doc.data() as Map<String, dynamic>;
                          String productName = data['productName'];
                          int quantity = (data['quantity'] as num).toInt();
                          double price = (data['price'] as num).toDouble();
                          double revenue = quantity * price;


                          if (!aggregatedData.containsKey(productName)) {
                            aggregatedData[productName] = {
                              'quantity': 0,
                              'price': price,
                              'revenue': 0.0,
                            };
                          }

                          aggregatedData[productName]!['quantity'] += quantity;
                          aggregatedData[productName]!['revenue'] += revenue;
                        }

                        // Membuat baris data untuk tabel
                        List<DataRow> rows = aggregatedData.entries.map((entry) {
                          String itemName = entry.key;
                          int totalQuantity = entry.value['quantity'];
                          double itemPrice = entry.value['price'];
                          double totalRevenue = entry.value['revenue'];

                          return DataRow(cells: [
                            DataCell(Text(itemName)), // Teks di tengah
                            DataCell(Center(child: Text(totalQuantity.toString()))), // Teks di tengah
                            DataCell(Center(child: Text('Rp ${NumberFormat('#,##0.00', 'id_ID').format(itemPrice)}'))), // Teks di tengah
                            DataCell(Text('Rp ${NumberFormat('#,##0.00', 'id_ID').format(totalRevenue)}')), // Teks di tengah
                          ]);
                        }).toList();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            PaginatedDataTable(
                              header: Text('Ordered Items'),
                              columnSpacing: 20,
                              headingRowHeight: 50,
                              columns: [
                                DataColumn(
                                  label: Container(
                                    width: 150,
                                    child: Center(child: Text('Nama Item')),
                                  ),
                                ),
                                DataColumn(
                                  label: Container(
                                    width: 100,
                                    child: Center(child: Text('Jumlah Order')),
                                  ),
                                ),
                                DataColumn(
                                  label: Container(
                                    width: 100,
                                    child: Center(child: Text('Harga')),
                                  ),
                                ),
                                DataColumn(
                                  label: Container(
                                    width: 100,
                                    child: Center(child: Text('Pendapatan')),
                                  ),
                                ),
                              ],
                              source: MyDataTableSource(rows),
                              rowsPerPage: 3,
                              showCheckboxColumn: false,
                            ),
                            SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                SizedBox(
                                  width: 180,
                                  child: TextFormField(
                                    readOnly: true,
                                    onTap: () => _selectDate(context),
                                    decoration: InputDecoration(
                                      labelText: 'Date',
                                      suffixIcon: Icon(Icons.calendar_today),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      isDense: true,
                                    ),
                                    controller: TextEditingController(
                                      text: _selectedDate != null ? DateFormat('MM/dd/yyyy').format(_selectedDate!) : '',
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                ElevatedButton.icon(
                                  onPressed: _exportToCSV,
                                  icon: Icon(Icons.download),
                                  label: Text('Download to CSV'),
                                ),
                              ],
                            ),
                          ],
                        );

                      },
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

class MyDataTableSource extends DataTableSource {
  final List<DataRow> _dataRows;

  MyDataTableSource(this._dataRows);

  @override
  DataRow getRow(int index) {
    return _dataRows[index];
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => _dataRows.length;

  @override
  int get selectedRowCount => 0;
}


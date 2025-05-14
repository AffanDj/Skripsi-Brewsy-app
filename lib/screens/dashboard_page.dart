import 'package:cloud_functions/cloud_functions.dart';
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
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:html' as html;
import 'dart:convert';

// Define your app's primary color theme based on the logo colors
const Color primaryColor = Color(0xFF01479E); // Dark Blue
const Color secondaryColor = Color(0xFFFF6F00); // Orange
const Color backgroundColor = Color(0xFFF5F7FA); // Light background

class DashboardPage extends StatefulWidget {
  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 1; // Default selected index is 'Dashboard'
  double totalRevenue = 0.0;
  int totalOrders = 0;
  DateTime? _selectedDate;
  FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, Map<String, dynamic>> aggregatedData = {};

  @override
  void initState() {
    _selectedDate = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    super.initState();
    _fetchData();
    debugPrint('date: $_selectedDate');
  }

  Future<void> _fetchData() async {
    QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('transactionDetails').get();

    double revenueSum = 0.0;
    int ordersSum = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      int quantity = (data['quantity'] as num).toInt();
      double price = (data['price'] as num).toDouble();
      revenueSum += quantity * price;
      ordersSum += quantity;
    }

    setState(() {
      totalRevenue = revenueSum;
      totalOrders = ordersSum;
    });
  }

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

  Future<void> downloadCsvFile(String csvData) async {
    try {
      if (kIsWeb) {
        // ✅ Web: download lewat AnchorElement
        final String formattedDate = DateFormat('yyyyMMdd').format(DateTime.now());
        final bytes = utf8.encode(csvData);
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', 'laporan$formattedDate.csv')
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
    await downloadCsvFile(csvString);
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: backgroundColor,
        title: Text('Konfirmasi Logout', style: TextStyle(color: primaryColor)),
        content: Text('Apakah Anda yakin ingin keluar?', style: TextStyle(color: primaryColor)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Tidak', style: TextStyle(color: primaryColor)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushNamed('/');
            },
            child: Text('Ya', style: TextStyle(color: primaryColor)),
          ),
        ],
      ),
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
        _showLogoutDialog(context);
        break;
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
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primaryColor.withOpacity(0.7))),
            const SizedBox(height: 10),
            Text(value, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: primaryColor)),
            const SizedBox(height: 6),
            Text(subtitle, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: primaryColor.withOpacity(0.4))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 110,
            color: backgroundColor,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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
                  icon: Icons.inventory_2_outlined ,
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
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      _buildSummaryBox(
                        label: 'Pendapatan',
                        value: 'Rp ${NumberFormat('#,##0.00', 'id_ID').format(totalRevenue)}',
                        subtitle: 'Total Pendapatan',
                        borderColor: secondaryColor,
                      ),
                      const SizedBox(width: 24),
                      _buildSummaryBox(
                        label: 'Jumlah Order',
                        value: totalOrders.toString(),
                        subtitle: 'Total Order',
                        borderColor: primaryColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('transactionDetails').snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: primaryColor,
                            ),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(
                            child: Text(
                              'No data available',
                              style: TextStyle(
                                color: primaryColor.withOpacity(0.4),
                                fontSize: 16,
                              ),
                            ),
                          );
                        }

                        final aggregatedData = <String, Map<String, dynamic>>{};

                        for (var doc in snapshot.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          final productName = data['productName'] as String;
                          final quantity = (data['quantity'] as num).toInt();
                          final price = (data['price'] as num).toDouble();
                          final revenue = quantity * price;

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

                        final rows = aggregatedData.entries.map((entry) {
                          final itemName = entry.key;
                          final totalQuantity = entry.value['quantity'] as int;
                          final itemPrice = entry.value['price'] as double;
                          final totalRevenue = entry.value['revenue'] as double;

                          return DataRow(cells: [
                            DataCell(Text(itemName,
                                style: TextStyle(
                                    fontSize: 20,
                                    color: primaryColor,
                                    fontWeight: FontWeight.w600))),
                            DataCell(Center(
                                child: Text(totalQuantity.toString(),
                                    style: TextStyle(
                                        fontSize: 20, color: primaryColor)))),
                            DataCell(Center(
                                child: Text(
                                  'Rp ${NumberFormat('#,##0.00', 'id_ID').format(itemPrice)}',
                                  style: TextStyle(fontSize: 20, color: primaryColor),
                                ))),
                            DataCell(Center(
                                child: Text(
                                  'Rp ${NumberFormat('#,##0.00', 'id_ID').format(totalRevenue)}',
                                  style: TextStyle(
                                      fontSize: 20,
                                      color: secondaryColor,
                                      fontWeight: FontWeight.bold),
                                ))),
                          ]);
                        }).toList();

                        return PaginatedDataTable(
                          header: Text('Ordered Items',
                              style: TextStyle(
                                  color: primaryColor , fontWeight: FontWeight.w700, fontSize: 25)),
                          columnSpacing: 24,
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
                                  child: Text('Jumlah Order',
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
                                          fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ),
                            DataColumn(
                              label: SizedBox(
                                width: 210,
                                child: Center(
                                  child: Text('Pendapatan',
                                      style: TextStyle(
                                          fontSize: 22,
                                          color: primaryColor,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ),
                          ],
                          source: _MyDataTableSource(rows),
                          rowsPerPage: 9,
                          showCheckboxColumn: false,
                          horizontalMargin: 24,
                        );
                      },
                    ),
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MyDataTableSource extends DataTableSource {
  final List<DataRow> _rows;

  _MyDataTableSource(this._rows);

  @override
  DataRow getRow(int index) => _rows[index];

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => _rows.length;

  @override
  int get selectedRowCount => 0;
}
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/sidebar_button.dart';
import '../widgets/summary_box.dart';
import '../widgets/search_bar.dart';// Import SearchBar
import '../widgets/formatted_date.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const Color primaryColor = Color(0xFF01479E); // Dark Blue
const Color secondaryColor = Color(0xFFFF6F00); // Orange
const Color backgroundColor = Color(0xFFF5F7FA); // Light background

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

    return DataRow(
      cells: [
        DataCell(
          Center(
            child: Text(
              paymentName,
              style: TextStyle(
                fontSize: 20,
                color: primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          onTap: () {
            showEditDialog(data[index]);
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

class _PaymentPageState extends State<PaymentPage> {
  int _selectedIndex = 5; // Default index select = 'Payment'
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
        final paymentType = doc.data() as Map<String, dynamic>;
        final paymentName =
            paymentType['paymentName']?.toString().toLowerCase() ?? '';
        return paymentName.contains(query);
      }).toList();
    });
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: backgroundColor,
        title: Text('Konfirmasi Logout', style: TextStyle(color: primaryColor)),
        content:
        Text('Apakah Anda yakin ingin keluar?', style: TextStyle(color: primaryColor)),
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

  void _showEditDialog(QueryDocumentSnapshot paymentDoc) {
    final payment = paymentDoc.data() as Map<String, dynamic>;
    final paymentNameController = TextEditingController(text: payment['paymentName']);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: backgroundColor,
          title: Text('Edit Payment', style: TextStyle(color: primaryColor)),
          content: TextField(
            controller: paymentNameController,
            decoration: InputDecoration(
              labelText: 'Payment Name',
              labelStyle: TextStyle(color: primaryColor.withOpacity(0.7)),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: primaryColor.withOpacity(0.4)),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: secondaryColor),
              ),
            ),
            style: TextStyle(color: primaryColor),
          ),
          actions: [
            TextButton(
              onPressed: () {
                FirebaseFirestore.instance
                    .collection('paymentType')
                    .doc(paymentDoc.id)
                    .update({
                  'paymentName': paymentNameController.text,
                }).then((_) {
                  Navigator.of(context).pop();
                });
              },
              child: Text('Save', style: TextStyle(color: secondaryColor)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel', style: TextStyle(color: primaryColor)),
            ),
            TextButton(
              onPressed: () {
                deletePayment(paymentDoc.id);
                Navigator.of(context).pop();
              },
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void deletePayment(String paymentId) {
    FirebaseFirestore.instance.collection('paymentType').doc(paymentId).delete().then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment deleted successfully')),
      );
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed To delete Payment: $error')),
      );
    });
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

  Widget getFormattedDate() {
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

  Widget _buildSearchBar() {
    return Container(
      width: 250,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          hintText: 'Search Payment',
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
                  getFormattedDate(),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      _buildSummaryBox(
                        label: 'Pendapatan',
                        value:
                        'Rp ${NumberFormat("#,##0.00", "id_ID").format(totalRevenue)}',
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
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 6,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header row with title, spacer, search bar, and add button
                            Row(
                              children: [
                                Text(
                                  'Payment Page',
                                  style: TextStyle(
                                    fontSize: 25,
                                    fontWeight: FontWeight.w700,
                                    color: primaryColor,
                                  ),
                                ),
                                const Spacer(),
                                _buildSearchBar(),
                                const SizedBox(width: 12),
                                IconButton(
                                  icon: Icon(Icons.add, color: secondaryColor),
                                  onPressed: () {
                                    Navigator.of(context).pushNamed('/addPayment');
                                  },
                                  tooltip: 'Add Payment',
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Divider(color: primaryColor.withOpacity(0.3)),
                            const SizedBox(height: 12),
                            Expanded(
                              child: StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('paymentType')
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return Center(
                                      child: CircularProgressIndicator(
                                        color: primaryColor,
                                      ),
                                    );
                                  }
                                  if (!snapshot.hasData ||
                                      snapshot.data!.docs.isEmpty) {
                                    return Center(
                                      child: Text(
                                        'No data available',
                                        style: TextStyle(
                                            color: primaryColor.withOpacity(0.4),
                                            fontSize: 16),
                                      ),
                                    );
                                  }
                                  if (originalData.isEmpty) {
                                    originalData = snapshot.data!.docs;
                                    filteredData = List.from(originalData);
                                  }

                                  final source = PaymentDataTableSource(
                                      filteredData, _showEditDialog);

                                  return PaginatedDataTable(
                                    rowsPerPage: 4,
                                    columnSpacing: 24,
                                    headingRowHeight: 56,
                                    dataRowHeight: 56,
                                    showCheckboxColumn: false,
                                    horizontalMargin: 24,
                                    columns: [
                                      DataColumn(
                                        label: SizedBox(
                                          width: 500,
                                          child: Center(
                                            child: Text(
                                              'Nama Payment',
                                              style: TextStyle(
                                                fontSize: 22,
                                                color: primaryColor,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
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

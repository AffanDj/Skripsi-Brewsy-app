import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/sidebar_button.dart';
import '../widgets/summary_box.dart';
import '../widgets/search_bar.dart'; // Import SearchBar
import '../widgets/formatted_date.dart';
import 'dart:developer';
import 'package:flutter/foundation.dart';

const Color primaryColor = Color(0xFF01479E);
const Color secondaryColor = Color(0xFFFF6F00);
const Color backgroundColor = Color(0xFFF5F7FA);

void main() {
  runApp(const MyApp());
}

class Order {
  final String orderId;
  final String customerName;
  final DateTime createdAt;
  final double amount;
  final String tableNumber;
  String status;

  Order({
    required this.orderId,
    required this.customerName,
    required this.createdAt,
    required this.amount,
    required this.tableNumber,
    required this.status,
  });
}

class TransactionDetail {
  final String productName;
  final int quantity;

  TransactionDetail({
    required this.productName,
    required this.quantity,
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Transaction Page',
      theme: ThemeData(
        primaryColor: primaryColor,
        scaffoldBackgroundColor: backgroundColor,
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: primaryColor,
          secondary: secondaryColor,
        ),
      ),
      home: const TransactionPage(),
      debugShowCheckedModeBanner: false,
      routes: {
        '/newOrder': (context) => const DummyPage(title: 'New Order Page'),
        '/dashboard': (context) => const DummyPage(title: 'Dashboard Page'),
        '/product': (context) => const DummyPage(title: 'Product Page'),
        '/transaction': (context) => const TransactionPage(),
        '/category': (context) => const DummyPage(title: 'Category Page'),
        '/payment': (context) => const DummyPage(title: 'Payment Page'),
        '/': (context) => const DummyPage(title: 'Home Page'),
      },
    );
  }
}

class DummyPage extends StatelessWidget {
  final String title;
  const DummyPage({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: primaryColor,
      ),
      body: Center(
        child: Text(
          title,
          style: const TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}

class TransactionPage extends StatefulWidget {
  const TransactionPage({super.key});

  @override
  State<TransactionPage> createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage> {
  List<Order> _allOrders = [];
  Map<String, List<TransactionDetail>> _transactionDetails = {};
  List<Order> _filteredOrders = [];
  DateTime? _selectedDate;
  final TextEditingController _searchController = TextEditingController();
  int _selectedSidebarIndex = 3;
  bool _isLoadingOrders = false;
  bool _isLoadingDetails = false;

  // Pagination variables
  static const int _rowsPerPage = 9;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
    _fetchTransactionDetails();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _isLoadingOrders = true;
    });
    try {
      QuerySnapshot snapshot =
      await FirebaseFirestore.instance.collection('orders').get();

      List<Order> orders = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Order(
          orderId: data['orderId'] ?? '',
          customerName: data['customerName'] ?? 'Unknown',
          createdAt: (data['createdAt'] as Timestamp).toDate(),
          amount: (data['amount'] as num).toDouble(),
          tableNumber: data['tableNumber'] ?? 'N/A',
          status: data['status'] ?? 'unknown',
        );
      }).toList();

      setState(() {
        _allOrders = orders;
        _filteredOrders = List.from(_allOrders);
        _currentPage = 0; // Reset page on new data
      });
    } catch (e) {
      debugPrint('Error fetching orders: $e');
    } finally {
      setState(() {
        _isLoadingOrders = false;
      });
    }
  }

  Future<void> _fetchTransactionDetails() async {
    setState(() {
      _isLoadingDetails = true;
    });
    try {
      QuerySnapshot snapshot =
      await FirebaseFirestore.instance.collection('transactionDetails').get();

      Map<String, List<TransactionDetail>> detailsMap = {};

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final orderId = data['orderId'] ?? '';
        final productName = data['productName'] ?? '';
        final quantity = (data['quantity'] as num).toInt();

        if (!detailsMap.containsKey(orderId)) {
          detailsMap[orderId] = [];
        }
        detailsMap[orderId]!.add(TransactionDetail(
          productName: productName,
          quantity: quantity,
        ));
      }

      setState(() {
        _transactionDetails = detailsMap;
      });
    } catch (e) {
      debugPrint('Error fetching transaction details: $e');
    } finally {
      setState(() {
        _isLoadingDetails = false;
      });
    }
  }

  void _onSearchChanged() {
    _filterOrders();
  }

  void _filterOrders() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredOrders = _allOrders.where((order) {
        final nameMatch = order.customerName.toLowerCase().contains(query);
        final dateMatch = _selectedDate == null ||
            (order.createdAt.year == _selectedDate!.year &&
                order.createdAt.month == _selectedDate!.month &&
                order.createdAt.day == _selectedDate!.day);
        return (nameMatch || query.isEmpty) && dateMatch;
      }).toList();
      _currentPage = 0; // Reset to first page on filter change
    });
  }

  void _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              onSurface: primaryColor,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: primaryColor),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      _filterOrders();
      log('date: $_selectedDate');
      debugPrint('date: $_selectedDate');
    }
  }

  void _clearDate() {
    setState(() {
      _selectedDate = null;
    });
    _filterOrders();
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('orderId', isEqualTo: orderId)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        DocumentSnapshot document = querySnapshot.docs.first;
        await document.reference.update({'status': newStatus});

        // Update local state
        final index = _allOrders.indexWhere((order) => order.orderId == orderId);
        if (index != -1) {
          setState(() {
            _allOrders[index].status = newStatus;
          });
          _filterOrders();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to $newStatus'),
            backgroundColor: secondaryColor,
          ),
        );
      } else {
        debugPrint('No document found with orderId: $orderId');
      }
    } catch (e) {
      debugPrint('Error updating status: $e');
    }
  }

  void _showLogoutDialog() {
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
              Navigator.of(context).pushReplacementNamed('/');
            },
            child: Text('Ya', style: TextStyle(color: primaryColor)),
          ),
        ],
      ),
    );
  }

  void _onSidebarButtonTapped(int index) {
    setState(() {
      _selectedSidebarIndex = index;
    });
    switch (index) {
      case 0:
        Navigator.of(context).pushReplacementNamed('/newOrder');
        break;
      case 1:
        Navigator.of(context).pushReplacementNamed('/dashboard');
        break;
      case 2:
        Navigator.of(context).pushReplacementNamed('/product');
        break;
      case 3:
      // Already on transaction page, do nothing or refresh
        break;
      case 4:
        Navigator.of(context).pushReplacementNamed('/category');
        break;
      case 5:
        Navigator.of(context).pushReplacementNamed('/payment');
        break;
      case 6:
        _showLogoutDialog();
        break;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final formatter = DateFormat('EEEE, d MMMM yyyy - HH:mm', 'id_ID');
    return formatter.format(dateTime);
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 2);
    return formatter.format(amount);
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'on-proggress':
        return Colors.orange.shade600;
      case 'delivered':
        return Colors.green.shade600;
      case 'canceled':
        return Colors.red.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  Widget _buildStatusText(String status) {
    return Text(
      status[0].toUpperCase() + status.substring(1),
      style: TextStyle(
        color: _statusColor(status),
        fontWeight: FontWeight.w600,
        fontSize: 20,
      ),
    );
  }

  void _showTransactionDetailDialog(Order order) {
    final details = _transactionDetails[order.orderId] ?? [];
    String selectedStatus = order.status;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: backgroundColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Transaction Detail', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 450,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: details.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final detail = details[index];
                        return Container(
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.15),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              const SizedBox(width: 0),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      detail.productName,
                                      style: TextStyle(
                                        color: primaryColor,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Quantity: ${detail.quantity}',
                                      style: TextStyle(
                                        color: primaryColor.withOpacity(0.8),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Select Status:',
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: primaryColor.withOpacity(0.4)),
                    ),
                    child: DropdownButton<String>(
                      value: selectedStatus,
                      isExpanded: true,
                      underline: const SizedBox(),
                      iconEnabledColor: primaryColor,
                      dropdownColor: backgroundColor,
                      items: <String>['on-proggress', 'delivered', 'canceled']
                          .map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(
                            value[0].toUpperCase() + value.substring(1),
                            style: TextStyle(color: primaryColor),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setStateDialog(() {
                            selectedStatus = newValue;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  _updateOrderStatus(order.orderId, selectedStatus);
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'Update Status',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: primaryColor.withOpacity(0.7),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Close',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          );
        });
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
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: primaryColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: primaryColor),
        decoration: InputDecoration(
          hintText: 'Search Transaction',
          hintStyle: TextStyle(color: primaryColor.withOpacity(0.5)),
          prefixIcon: Icon(Icons.search, color: primaryColor.withOpacity(0.7)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildTransactionTable() {
    if (_isLoadingOrders) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_filteredOrders.isEmpty) {
      return Center(
        child: Text(
          'No data available',
          style: TextStyle(color: primaryColor.withOpacity(0.4), fontSize: 16),
        ),
      );
    }

    // Calculate pagination slice
    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = (_currentPage + 1) * _rowsPerPage;
    final pageItems = _filteredOrders.sublist(
      startIndex,
      endIndex > _filteredOrders.length ? _filteredOrders.length : endIndex,
    );

    final totalPages = (_filteredOrders.length / _rowsPerPage).ceil();

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 56,
            dataRowHeight: 56,
            columnSpacing: 40,
            showCheckboxColumn: false,
            columns: [
              DataColumn(
                label: SizedBox(
                  width: 200,
                  child: Center(
                    child: Text('Nama Customer',
                        style: TextStyle(
                            fontSize: 22,
                            color: primaryColor,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              DataColumn(
                label: SizedBox(
                  width: 180,
                  child: Center(
                    child: Text('Tanggal Order',
                        style: TextStyle(
                            fontSize: 22,
                            color: primaryColor,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              DataColumn(
                label: SizedBox(
                  width: 180,
                  child: Center(
                    child: Text('Total Harga',
                        style: TextStyle(
                            fontSize: 22,
                            color: primaryColor,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              DataColumn(
                label: SizedBox(
                  width: 180,
                  child: Center(
                    child: Text('No Meja',
                        style: TextStyle(
                            fontSize: 22,
                            color: primaryColor,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              DataColumn(
                label: SizedBox(
                  width: 180,
                  child: Center(
                    child: Text('Status',
                        style: TextStyle(
                            fontSize: 22,
                            color: primaryColor,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
            rows: pageItems.map((order) {
              return DataRow(
                cells: [
                  DataCell(Text(order.customerName,
                      style: TextStyle(fontSize: 20, color: primaryColor))),
                  DataCell(Center(
                      child: Text(
                          DateFormat('dd/MM/yyyy').format(order.createdAt),
                          style: TextStyle(
                              fontSize: 20, color: primaryColor.withOpacity(0.85))))),
                  DataCell(Center(
                      child: Text(_formatCurrency(order.amount),
                          style: TextStyle(
                              fontSize: 20, color: primaryColor.withOpacity(0.85))))),
                  DataCell(Center(
                      child: Text(order.tableNumber,
                          style: TextStyle(
                              fontSize: 20, color: primaryColor.withOpacity(0.7))))),
                  DataCell(Center(child: _buildStatusText(order.status))),
                ],
                onSelectChanged: (selected) {
                  if (selected ?? false) {
                    _showTransactionDetailDialog(order);
                  }
                },
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Page ${_currentPage + 1} of $totalPages',
              style: TextStyle(color: primaryColor.withOpacity(0.7), fontSize: 14),
            ),
            IconButton(
              icon: Icon(Icons.chevron_left, color: primaryColor),
              onPressed: _currentPage > 0
                  ? () {
                setState(() {
                  _currentPage--;
                });
              }
                  : null,
            ),
            IconButton(
              icon: Icon(Icons.chevron_right, color: primaryColor),
              onPressed: _currentPage < totalPages - 1
                  ? () {
                setState(() {
                  _currentPage++;
                });
              }
                  : null,
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final formattedDateTime = _formatDateTime(now);

    final totalRevenue = _filteredOrders.fold<double>(
        0, (previousValue, element) => previousValue + element.amount);
    final totalOrders = _filteredOrders.length;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formattedDateTime,
                    style: TextStyle(
                      fontSize: 16,
                      color: primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _buildSummaryBox(
                        label: 'Pendapatan',
                        value: _formatCurrency(totalRevenue),
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
                            // Title, Search Bar and Date Picker
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Transaction Page',
                                  style: TextStyle(
                                      fontSize: 25,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor),
                                ),
                                Row(
                                  children: [
                                    _buildSearchBar(),
                                    const SizedBox(width: 12),
                                    IconButton(
                                      icon: Icon(Icons.calendar_today,
                                          color: primaryColor),
                                      onPressed: () => _selectDate(context),
                                      tooltip: 'Select Date',
                                    ),
                                    if (_selectedDate != null)
                                      IconButton(
                                        icon: Icon(Icons.clear,
                                            color: primaryColor.withOpacity(0.7)),
                                        onPressed: _clearDate,
                                        tooltip: 'Clear Date Filter',
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            Divider(color: primaryColor.withOpacity(0.3)),
                            Expanded(child: _buildTransactionTable()),
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

  Widget _buildSidebar() {
    return Container(
      width: 110,
      color: backgroundColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 15),
          _buildSidebarButton(
            icon: Icons.add_shopping_cart_outlined,
            label: 'New Order',
            selected: _selectedSidebarIndex == 0,
            onPressed: () => _onSidebarButtonTapped(0),
          ),
          const SizedBox(height: 18),
          _buildSidebarButton(
            icon: Icons.show_chart_outlined,
            label: 'Dashboard',
            selected: _selectedSidebarIndex == 1,
            onPressed: () => _onSidebarButtonTapped(1),
          ),
          const SizedBox(height: 18),
          _buildSidebarButton(
            icon: Icons.inventory_2_outlined,
            label: 'Product',
            selected: _selectedSidebarIndex == 2,
            onPressed: () => _onSidebarButtonTapped(2),
          ),
          const SizedBox(height: 18),
          _buildSidebarButton(
            icon: Icons.swap_horiz_outlined,
            label: 'Transaction',
            selected: _selectedSidebarIndex == 3,
            onPressed: () => _onSidebarButtonTapped(3),
          ),
          const SizedBox(height: 18),
          _buildSidebarButton(
            icon: Icons.label_outline,
            label: 'Category',
            selected: _selectedSidebarIndex == 4,
            onPressed: () => _onSidebarButtonTapped(4),
          ),
          const SizedBox(height: 18),
          _buildSidebarButton(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Payment',
            selected: _selectedSidebarIndex == 5,
            onPressed: () => _onSidebarButtonTapped(5),
          ),
          const SizedBox(height: 18),
          _buildSidebarButton(
            icon: Icons.exit_to_app,
            label: 'Logout',
            selected: _selectedSidebarIndex == 6,
            onPressed: () => _onSidebarButtonTapped(6),
          ),
        ],
      ),
    );
  }
}

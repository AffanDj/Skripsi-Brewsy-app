import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

const Color secondaryColor = Color(0xFFFF6F00); // Orange
const Color primaryColor = Color(0xFF01479E); // Dark Blue
const Color backgroundColor = Color(0xFFF5F7FA); // Light background

class NewOrderPage extends StatefulWidget {
  @override
  _NewOrderPageState createState() => _NewOrderPageState();
}

class _NewOrderPageState extends State<NewOrderPage> {
  String _selectedCategory = 'Drinks'; // Default category
  Map<String, int> cart = {}; // Shopping cart
  TextEditingController searchController = TextEditingController();

  // Simpan data transaksi ke Firestore
  Future<void> _saveTransactionToFirestore({
    required String orderId,
    required int amount,
    required String customerName,
    required String email,
    required String phone,
    required String tableNumber,
    required List<Map<String, dynamic>> items,
    required String status,
  }) async {
    final ordersCollection = FirebaseFirestore.instance.collection('orders');
    final detailsCollection = FirebaseFirestore.instance.collection('transactionDetails');

    // Simpan data order utama
    await ordersCollection.doc(orderId).set({
      'orderId': orderId,
      'amount': amount,
      'customerName': customerName,
      'email': email,
      'phone': phone,
      'tableNumber': tableNumber,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Simpan detail transaksi (items)
    for (var item in items) {
      await detailsCollection.add({
        'orderId': orderId,
        'productName': item['name'],
        'quantity': item['quantity'],
        'price': item['price'],
        'code': item['code'],
      });
    }
  }

  // Initiate payment function
  Future<void> initiatePayment(
      Map<String, int> cart,
      String name,
      String email,
      String phone,
      String tableNumber,
      String paymentMethod) async {
    try {
      final url = Uri.parse(
          'https://us-central1-brewsypos.cloudfunctions.net/createTransaction');

      QuerySnapshot snapshot =
      await FirebaseFirestore.instance.collection('item').get();
      List<Map<String, dynamic>> allProducts = snapshot.docs.map((doc) {
        return {
          'name': doc['name'],
          'price': doc['price'],
          'code': doc['code']
        };
      }).toList();

      if (cart.isEmpty) {
        throw Exception('Keranjang kosong! Tidak ada item untuk diproses.');
      }

      List<Map<String, dynamic>> items = [];
      int totalAmount = 0;

      cart.forEach((productName, quantity) {
        var product = allProducts.firstWhere(
              (p) => p['name'] == productName,
          orElse: () => {
            'name': productName,
            'price': 0,
            'code': '',
          },
        );
        items.add({
          'name': product['name'],
          'quantity': quantity,
          'price': product['price'],
          'code': product['code'],
        });
        totalAmount += (product['price'] as int) * quantity;
      });

      final orderId = 'order_${DateTime.now().millisecondsSinceEpoch}';

      // Simpan data transaksi ke Firestore dengan status sesuai paymentMethod
      await _saveTransactionToFirestore(
        orderId: orderId,
        amount: totalAmount,
        customerName: name,
        email: email,
        phone: phone,
        tableNumber: tableNumber,
        items: items,
        status: paymentMethod == 'Cash' ? 'paid' : 'pending',
      );

      if (paymentMethod == 'Virtual') {
        // Jika metode Virtual, lanjutkan ke payment gateway
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'orderId': orderId,
            'amount': totalAmount,
            'customerName': name,
            'email': email,
            'phone': phone,
            'tableNumber': tableNumber,
            'items': items,
          }),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          String paymentUrl = data['redirect_url'];
          if (await canLaunch(paymentUrl)) {
            await launch(paymentUrl);
          } else {
            print('Failed to open payment URL');
          }
        } else {
          print('Failed to initiate payment: ${response.body}');
        }
      } else {
        // Jika Cash, tampilkan pesan sukses
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Payment completed with Cash!'),
          backgroundColor: secondaryColor,
        ));
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              backgroundColor: backgroundColor,
              title: Text('Payment Success', style: TextStyle(color: primaryColor)),
              content: Text('Your payment has been completed successfully.', style: TextStyle(color: primaryColor)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('OK', style: TextStyle(color: primaryColor)),
                ),
              ],
            );
          },
        );
      }

      Navigator.pop(context); // Tutup dialog input customer
    } catch (e) {
      print('Error: $e');
    }
  }

  void _showCustomerInputDialog() {
    final _formKey = GlobalKey<FormState>();

    final TextEditingController nameController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController tableController = TextEditingController();

    String paymentMethod = 'Cash';

    bool validateEmail(String email) {
      final emailRegex = RegExp(r'^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,6}$');
      return emailRegex.hasMatch(email);
    }

    bool validatePhone(String phone) {
      final phoneRegex = RegExp(r'^[0-9]{10,15}$');
      return phoneRegex.hasMatch(phone);
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Customer Information', style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600, fontSize: 20)),
          content: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return SizedBox(
                  width: 400,
                  height: 300,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Name',
                          labelStyle: TextStyle(color: primaryColor.withOpacity(0.7)),
                          prefixIcon: Icon(Icons.person, color: primaryColor.withOpacity(0.7)),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: secondaryColor),
                          ),
                        ),
                        style: TextStyle(color: primaryColor),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          labelStyle: TextStyle(color: primaryColor.withOpacity(0.7)),
                          prefixIcon: Icon(Icons.email, color: primaryColor.withOpacity(0.7)),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: secondaryColor),
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: primaryColor),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!validateEmail(value.trim())) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneController,
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          labelStyle: TextStyle(color: primaryColor.withOpacity(0.7)),
                          prefixIcon: Icon(Icons.phone, color: primaryColor.withOpacity(0.7)),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: secondaryColor),
                          ),
                        ),
                        keyboardType: TextInputType.phone,
                        style: TextStyle(color: primaryColor),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your phone number';
                          }
                          if (!validatePhone(value.trim())) {
                            return 'Please enter a valid phone number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: tableController,
                        decoration: InputDecoration(
                          labelText: 'Table Number',
                          labelStyle: TextStyle(color: primaryColor.withOpacity(0.7)),
                          prefixIcon: Icon(Icons.table_chart, color: primaryColor.withOpacity(0.7)),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: secondaryColor),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: primaryColor),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your table number';
                          }
                          if (int.tryParse(value.trim()) == null) {
                            return 'Table number must be a number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        value: paymentMethod,
                        onChanged: (String? newValue) {
                          setState(() {
                            paymentMethod = newValue!;
                          });
                        },
                        items: <String>['Cash', 'Virtual']
                            .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value, style: TextStyle(color: primaryColor)),
                          );
                        }).toList(),
                        dropdownColor: backgroundColor,
                        decoration: InputDecoration(
                          labelText: 'Payment Method',
                          labelStyle: TextStyle(color: primaryColor.withOpacity(0.7)),
                          prefixIcon: Icon(Icons.payment, color: primaryColor.withOpacity(0.7)),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: secondaryColor),
                          ),
                        ),
                        style: TextStyle(color: primaryColor),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: primaryColor)),
            ),
            ElevatedButton(
              onPressed: () {
                if (_formKey.currentState?.validate() ?? false) {
                  Navigator.of(context).pop();

                  initiatePayment(
                    cart, // Your cart data
                    nameController.text.trim(), // Customer name
                    emailController.text.trim(), // Customer email
                    phoneController.text.trim(), // Customer phone
                    tableController.text.trim(), // Customer table number
                    paymentMethod, // Pass payment method here
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: secondaryColor),
              child: Text('Submit', style: TextStyle(color: Colors.white)),
            )
          ],
        );
      },
    );
  }

  void _addToCart(String productName) {
    setState(() {
      if (cart.containsKey(productName)) {
        cart[productName] = cart[productName]! + 1;
      } else {
        cart[productName] = 1;
      }
    });
  }

  void _removeFromCart(String productName) {
    setState(() {
      if (cart.containsKey(productName) && cart[productName]! > 1) {
        cart[productName] = cart[productName]! - 1;
      } else {
        cart.remove(productName);
      }
    });
  }

  int _calculateTotal(List<Map<String, dynamic>> allProducts) {
    int total = 0;
    cart.forEach((productName, quantity) {
      var product = allProducts.firstWhere(
            (product) => product['name'] == productName,
        orElse: () => {'name': '', 'price': 0},
      );
      total += (product['price'] as int) * quantity;
    });
    return total;
  }

  Future<bool> _onWillPop() async {
    Navigator.of(context).pushReplacementNamed('/dashboard');
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: primaryColor),
            onPressed: () {
              Navigator.of(context).pushReplacementNamed('/dashboard');
            },
          ),
          title: Text('New Order', style: TextStyle(color: primaryColor)),
          backgroundColor: backgroundColor,
          elevation: 0,
        ),
        body: Row(
          children: [
            // Sidebar with categories
            Container(
              width: 100,
              color: backgroundColor,
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('category').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: primaryColor));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(child: Text('No Categories', style: TextStyle(color: primaryColor.withOpacity(0.7))));
                  }
                  List<QueryDocumentSnapshot> categories = snapshot.data!.docs;
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(height: 20),
                      ...categories.map((category) {
                        String categoryName = category['categoryName'];
                        bool selected = _selectedCategory == categoryName;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCategory = categoryName;
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.all(10.0),
                            margin: EdgeInsets.only(bottom: 10.0),
                            decoration: BoxDecoration(
                              color: selected ? secondaryColor : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: selected
                                  ? [
                                BoxShadow(
                                  color: secondaryColor.withOpacity(0.3),
                                  blurRadius: 6,
                                  offset: Offset(0, 3),
                                )
                              ]
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                categoryName,
                                style: TextStyle(
                                  color: selected ? Colors.white : primaryColor.withOpacity(0.7),
                                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  );
                },
              ),
            ),

            // Main content: Search and product grid
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    // Rounded Search Bar
                    Container(
                      width: 350,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
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
                        controller: searchController,
                        onChanged: (value) => setState(() {}),
                        style: TextStyle(color: primaryColor),
                        decoration: InputDecoration(
                          hintText: 'Search Product',
                          hintStyle: TextStyle(color: primaryColor.withOpacity(0.5)),
                          prefixIcon: Icon(Icons.search, color: primaryColor.withOpacity(0.7)),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    // Product grid
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('item')
                            .where('category', isEqualTo: _selectedCategory)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator(color: primaryColor));
                          }
                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return Center(child: Text('No Products', style: TextStyle(color: primaryColor.withOpacity(0.7))));
                          }
                          List<Map<String, dynamic>> filteredProducts = snapshot.data!.docs
                              .map((doc) => {
                            'name': doc['name'],
                            'price': doc['price'],
                            'image_url': doc['image_url'] ?? '',
                          })
                              .where((product) => product['name']
                              .toLowerCase()
                              .contains(searchController.text.toLowerCase()))
                              .toList();

                          return GridView.builder(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 20,
                              crossAxisSpacing: 20,
                              childAspectRatio: 3 / 4,
                            ),
                            itemCount: filteredProducts.length,
                            itemBuilder: (context, index) {
                              return GestureDetector(
                                onTap: () {
                                  _addToCart(filteredProducts[index]['name']);
                                },
                                child: Card(
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: filteredProducts[index]['image_url'] != null &&
                                            filteredProducts[index]['image_url'].isNotEmpty
                                            ? ClipRRect(
                                          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                          child: Image.network(
                                            filteredProducts[index]['image_url'],
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            loadingBuilder: (context, child, loadingProgress) {
                                              if (loadingProgress == null) return child;
                                              return Center(child: CircularProgressIndicator());
                                            },
                                            errorBuilder: (context, error, stackTrace) {
                                              return Icon(Icons.broken_image, size: 120, color: Colors.grey);
                                            },
                                          ),
                                        )
                                            : Container(
                                          height: 120,
                                          alignment: Alignment.center,
                                          child: Icon(Icons.image, size: 80, color: Colors.grey),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(10.0),
                                        child: Column(
                                          children: [
                                            Text(
                                              filteredProducts[index]['name'],
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: primaryColor,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            SizedBox(height: 5),
                                            Text(
                                              'Rp ${filteredProducts[index]['price']}',
                                              style: TextStyle(color: primaryColor.withOpacity(0.8)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Order summary panel
            Container(
              width: 280,
              color: Colors.white,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'New Order',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor),
                      ),
                    ),
                    Divider(),
                    Container(
                      height: MediaQuery.of(context).size.height * 0.45,
                      child: ListView.builder(
                        itemCount: cart.length,
                        itemBuilder: (context, index) {
                          String productName = cart.keys.elementAt(index);
                          int quantity = cart[productName]!;
                          return ListTile(
                            title: Text(productName, style: TextStyle(color: primaryColor)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.remove, color: secondaryColor),
                                  onPressed: () => _removeFromCart(productName),
                                ),
                                Text(quantity.toString(), style: TextStyle(color: primaryColor)),
                                IconButton(
                                  icon: Icon(Icons.add, color: secondaryColor),
                                  onPressed: () => _addToCart(productName),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total:',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
                          ),
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance.collection('item').snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData) {
                                return Text('Rp 0', style: TextStyle(color: primaryColor));
                              }
                              List<Map<String, dynamic>> allProducts = snapshot.data!.docs.map((doc) {
                                return {
                                  'name': doc['name'] ?? '',
                                  'price': doc['price'] ?? 0,
                                };
                              }).toList();
                              return Text('Rp ${_calculateTotal(allProducts)}', style: TextStyle(color: primaryColor));
                            },
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ElevatedButton(
                        onPressed: () {
                          _showCustomerInputDialog();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: secondaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                        ),
                        child: Text('Pay', style: TextStyle(color: Colors.white, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

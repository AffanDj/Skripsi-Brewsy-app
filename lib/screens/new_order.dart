import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';


class NewOrderPage extends StatefulWidget {
  @override
  _NewOrderPageState createState() => _NewOrderPageState();
}

class _NewOrderPageState extends State<NewOrderPage> {
  String _selectedCategory = 'Drinks'; // Kategori default
  Map<String, int> cart = {}; // Keranjang belanja
  bool isPaymentPage = false;
  String paymentUrl = '';
  TextEditingController searchController = TextEditingController();

  // Fungsi untuk memulai pembayaran
  Future<void> initiatePayment(
      Map<String, int> cart, String name, String email, String phone, String tableNumber) async {
    try {
      // URL API
      final url = Uri.parse(
          'https://us-central1-brewsypos.cloudfunctions.net/createTransaction');

      // Ambil data produk dari Firestore
      QuerySnapshot snapshot =
      await FirebaseFirestore.instance.collection('item').get();
      List<Map<String, dynamic>> allProducts = snapshot.docs.map((doc) {
        return {
          'name': doc['name'],
          'price': doc['price'],
          'code': doc['code']
        };
      }).toList();

      // Validasi jika `cart` kosong
      if (cart.isEmpty) {
        throw Exception('Keranjang kosong! Tidak ada item untuk diproses.');
      }

      // Buat daftar item dan hitung total harga
      List<Map<String, dynamic>> items = [];
      int totalAmount = 0;

      cart.forEach((productName, quantity) {
        var product = allProducts.firstWhere(
              (p) => p['name'] == productName,
          orElse: () => {
            'name': productName,
            'price': 0, // Default harga jika produk tidak ditemukan
          },
        );
        // Tambahkan item ke daftar
        items.add({
          'name': product['name'],
          'quantity': quantity,
          'price': product['price'],
          'code' : product['code']
        });

        // Hitung total harga
        totalAmount += (product['price'] as int) * quantity;
      });

      // Kirim request ke API
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'orderId': 'order_${DateTime.now().millisecondsSinceEpoch}', // ID pesanan unik
          'amount': totalAmount,
          'customerName': name, // Nama pelanggan
          'email': email, // Email pelanggan
          'phone': phone, // Nomor telepon
          'tableNumber': tableNumber, // Nomor meja
          'items': items, // Data item
        }),
      );

      // Cek status respons dari server
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String paymentUrl = data['redirect_url']; // URL untuk redirect ke pembayaran
        if (await canLaunch(paymentUrl)) {
          await launch(paymentUrl); // Buka URL pembayaran di browser
        } else {
          print('Gagal membuka URL pembayaran');
        }
        Navigator.pop(context);
      } else {
        // Error dari server
        print('Gagal memulai pembayaran: ${response.body}');
      }
    } catch (e) {
      // Tangani error secara global
      print('Error terjadi: $e');
    }
  }

  // Fungsi untuk memunculkan pop-up input data pelanggan
  void _showCustomerInputDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController tableController = TextEditingController();

    String paymentMethod = 'Cash'; // Default payment method is 'Cash'

    // Function to validate email
    bool validateEmail(String email) {
      final emailRegex = RegExp(r'^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,6}$');
      return emailRegex.hasMatch(email);
    }

    // Function to validate phone number
    bool validatePhone(String phone) {
      final phoneRegex = RegExp(r'^[0-9]{10,15}$');  // Phone number with 10 to 15 digits
      return phoneRegex.hasMatch(phone);
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Customer Information'),
          content: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(labelText: 'Name'),
                    ),
                    TextField(
                      controller: emailController,
                      decoration: InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    TextField(
                      controller: phoneController,
                      decoration: InputDecoration(labelText: 'Phone Number'),
                      keyboardType: TextInputType.phone,
                    ),
                    TextField(
                      controller: tableController,
                      decoration: InputDecoration(labelText: 'Table Number'),
                      keyboardType: TextInputType.number,
                    ),
                    // Dropdown for payment method selection
                    DropdownButton<String>(
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
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // Check if all fields are filled and valid
                if (nameController.text.isNotEmpty &&
                    emailController.text.isNotEmpty &&
                    phoneController.text.isNotEmpty &&
                    tableController.text.isNotEmpty) {
                  if (validateEmail(emailController.text) &&
                      validatePhone(phoneController.text)) {
                    Navigator.of(context).pop(); // Close the dialog
                    // Call the payment function with customer data
                    if (paymentMethod == 'Virtual') {
                      initiatePayment(
                        cart, // Your cart data
                        nameController.text, // Customer name
                        emailController.text, // Customer email
                        phoneController.text, // Customer phone
                        tableController.text, // Customer table number
                      );
                    } else {
                      // If Cash, show success message
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Payment completed with Cash!'),
                      ));
                      // Optionally, you can show a dialog for success
                      showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: Text('Payment Success'),
                            content: Text('Your payment has been completed successfully.'),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop(); // Close the dialog
                                },
                                child: Text('OK'),
                              ),
                            ],
                          );
                        },
                      );
                    }
                  } else {
                    // Show error message if email or phone is invalid
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Please enter valid email and phone number!'),
                    ));
                  }
                } else {
                  // Show error message if any field is empty
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Please fill all the fields!'),
                  ));
                }
              },
              child: Text('Submit'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.grey[700]),
          onPressed: () {
            Navigator.pop(context); // Kembali ke halaman sebelumnya
          },
        ),
        title: Text('New Order', style: TextStyle(color: Colors.grey[700])),
        backgroundColor: Colors.grey[300],
        elevation: 0,
      ),
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 100,
            color: Colors.grey[100],
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('category').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('No Categories'));
                }

                List<QueryDocumentSnapshot> categories = snapshot.data!.docs;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    SizedBox(height: 20),
                    ...categories.map((category) {
                      String categoryName = category['categoryName'];
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
                            color: _selectedCategory == categoryName ? Colors.blue : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              categoryName,
                              style: TextStyle(
                                color: _selectedCategory == categoryName ? Colors.white : Colors.grey,
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

          // Main Content (Product List)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // Search Bar
                  TextField(
                    controller: searchController,
                    onChanged: (value) {
                      setState(() {}); // Memperbarui UI saat teks berubah
                    },
                    decoration: InputDecoration(
                      hintText: 'Cari Produk',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                    ),
                  ),

                  SizedBox(height: 20),
                  // Product Grid
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('item')
                          .where('category', isEqualTo: _selectedCategory)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(child: Text('No Products'));
                        }

                        // Filter produk sesuai dengan teks pencarian
                        List<Map<String, dynamic>> filteredProducts = snapshot.data!.docs
                            .map((doc) => {
                          'name': doc['name'],
                          'price': doc['price'],
                          'image_url': doc['image_url'] ?? '',
                        })
                            .where((product) =>
                            product['name']
                                .toLowerCase()
                                .contains(searchController.text.toLowerCase()))
                            .toList();

                        return GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
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
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: filteredProducts[index]['image_url'] != null && filteredProducts[index]['image_url'].isNotEmpty
                                          ? Image.network(
                                        filteredProducts[index]['image_url'],
                                        fit: BoxFit.cover, // Sesuaikan ukuran foto dengan ukuran container
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return Center(child: CircularProgressIndicator());
                                        },
                                        errorBuilder: (context, error, stackTrace) {
                                          return Icon(Icons.broken_image, size: 120, color: Colors.grey);
                                        },
                                      )
                                          : Icon(Icons.image, size: 80, color: Colors.grey),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(10.0),
                                      child: Column(
                                        children: [
                                          Text(
                                            filteredProducts[index]['name'],
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          SizedBox(height: 5),
                                          Text('Rp ${filteredProducts[index]['price']}'),
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

          // Order Summary
          Container(
            width: 250,
            color: Colors.white,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'New Order',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Divider(),
                  // Cart Items
                  Container(
                    height: MediaQuery.of(context).size.height * 0.4,
                    child: ListView.builder(
                      itemCount: cart.length,
                      itemBuilder: (context, index) {
                        String productName = cart.keys.elementAt(index);
                        int quantity = cart[productName]!;
                        return ListTile(
                          title: Text(productName),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.remove),
                                onPressed: () => _removeFromCart(productName),
                              ),
                              Text(quantity.toString()),
                              IconButton(
                                icon: Icon(Icons.add),
                                onPressed: () => _addToCart(productName),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  Divider(),
                  // Total Price
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total:',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection('item').snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData) {
                              return Text('Rp 0');
                            }

                            List<Map<String, dynamic>> allProducts = snapshot.data!.docs.map((doc) {
                              return {
                                'name': doc['name'] ?? '',
                                'price': doc['price'] ?? 0,
                              };
                            }).toList();

                            return Text('Rp ${_calculateTotal(allProducts)}');
                          },
                        ),
                      ],
                    ),
                  ),
                  // Pay Button
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton(
                      onPressed: () {
                        // Memanggil fungsi pembayaran dengan parameter yang benar
                        _showCustomerInputDialog();  // Menampilkan input dialog pelanggan
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                      ),
                      child: Text('Pay'),
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
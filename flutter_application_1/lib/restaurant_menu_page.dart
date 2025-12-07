import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import 'edit_menu_page.dart';
import 'services/onepay_service.dart';
import 'services/transaction_service.dart';
import 'receipt_page.dart';
import 'l10n/app_translations.dart';
import 'providers/language_provider.dart';

class RestaurantMenuPage extends StatefulWidget {
  const RestaurantMenuPage({super.key});

  @override
  State<RestaurantMenuPage> createState() => _RestaurantMenuPageState();
}

class _RestaurantMenuPageState extends State<RestaurantMenuPage> {
  final Color darkBlue = const Color(0xFF1E2444);
  final Color lightBlue = const Color(0xFFB3BCF5);
  final user = FirebaseAuth.instance.currentUser;
  String _searchQuery = "";

  Map<String, int> cart = {};
  Map<String, Map<String, dynamic>> productData = {};
  final NumberFormat currencyFormat = NumberFormat("#,##0", "en_US");
  
  Timer? _pollTimer;

  String tr(String key) {
    final lang = Provider.of<LanguageProvider>(context, listen: false).selectedLanguage;
    return AppTranslations.get(lang, key);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _addToCart(String docId, Map<String, dynamic> data) {
    setState(() {
      cart[docId] = (cart[docId] ?? 0) + 1;
      productData[docId] = data;
    });
  }

  void _removeFromCart(String docId) {
    setState(() {
      if (cart[docId] != null && cart[docId]! > 0) {
        cart[docId] = cart[docId]! - 1;
        if (cart[docId] == 0) {
          cart.remove(docId);
          productData.remove(docId);
        }
      }
    });
  }

  double _calculateTotal() {
    double total = 0;
    cart.forEach((key, quantity) {
      if (productData[key] != null) {
        total += (productData[key]!['price'] ?? 0) * quantity;
      }
    });
    return total;
  }

  int _calculateTotalItems() {
    int count = 0;
    cart.forEach((key, quantity) {
      count += quantity;
    });
    return count;
  }

  // 🔥 ฟังก์ชันไปหน้าใบเสร็จ (Clear ตะกร้า และ Navigate)
  void _goToReceipt({double cashReceived = 0, double change = 0, bool autoPrint = false}) {
    // เตรียมข้อมูลสินค้าสำหรับส่งไปหน้าใบเสร็จ
    List<Map<String, dynamic>> orderItems = [];
    cart.forEach((docId, quantity) {
      if (productData[docId] != null) {
        orderItems.add({
          'name': productData[docId]!['name'],
          'price': productData[docId]!['price'],
          'quantity': quantity,
        });
      }
    });
    
    double finalTotal = _calculateTotal();

    // Save Transaction
    TransactionService.saveTransaction(
      orderId: "ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}",
      amount: finalTotal,
      type: 'restaurant',
      status: 'paid',
      items: orderItems,
      paymentMethod: cashReceived > 0 ? 'cash' : 'qr',
      cashReceived: cashReceived > 0 ? cashReceived : finalTotal,
      change: change,
  
    );

    // เคลียร์ข้อมูลในหน้านี้
    setState(() {
      cart.clear();
      productData.clear();
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReceiptPage(
          orderData: {'orderId': "ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}"},
          items: orderItems,
          totalAmount: finalTotal,
          cashReceived: cashReceived,
          change: change,
          autoPrint: autoPrint,
        ),
      ),
    );
  }

  // 🔥 Dialog รับเงินสด
  void _showCashDialog(double totalAmount) {
    final cashController = TextEditingController();
    double change = 0;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(tr('receive_cash'), textAlign: TextAlign.center),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("${tr('payment_amount')}: ${currencyFormat.format(totalAmount)} LAK", style: TextStyle(fontSize: 18, color: darkBlue, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(
                  controller: cashController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: tr('received_amount'),
                    border: const OutlineInputBorder(),
                    suffixText: "LAK",
                  ),
                  onChanged: (value) {
                    double received = double.tryParse(value) ?? 0;
                    setStateDialog(() {
                      change = received - totalAmount;
                    });
                  },
                ),
                const SizedBox(height: 20),
                if (change >= 0)
                  Text("${tr('change')}: ${currencyFormat.format(change)} LAK", style: const TextStyle(fontSize: 20, color: Colors.green, fontWeight: FontWeight.bold))
                else
                  Text("${tr('missing_amount')}: ${currencyFormat.format(change.abs())} LAK", style: const TextStyle(fontSize: 16, color: Colors.red)),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('cancel'))),
              ElevatedButton(
                onPressed: (change >= 0 && cashController.text.isNotEmpty)
                    ? () {
                        Navigator.pop(context); // ปิด Dialog
                        // ไปหน้าใบเสร็จ
                        double received = double.tryParse(cashController.text) ?? 0;
                        _goToReceipt(cashReceived: received, change: change, autoPrint: true);
                      }
                    : null,
                style: ElevatedButton.styleFrom(backgroundColor: darkBlue),
                child: Text(tr('confirm_payment'), style: const TextStyle(color: Colors.white)),
              ),
            ],
          );
        });
      },
    );
  }

  // 🔥 Dialog QR Code และระบบ Polling
  void _showQRCodeDialog(String qrData, double amount, int itemCount, String orderId) {
    // เริ่มเช็คสถานะทุก 3 วินาที
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      bool isPaid = await OnepayService.checkPaymentStatus(orderId);
      if (isPaid) {
        timer.cancel();
        if (mounted) {
          Navigator.pop(context); // ปิด Dialog QR
          _goToReceipt(autoPrint: true); // ไปหน้าใบเสร็จ (จ่าย QR ไม่ต้องทอนเงิน)
        }
      }
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // QR Code
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.red, width: 2),
                  ),
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white,
                  ),
                ),
                
                const SizedBox(height: 16),
                // Bank Logos (Placeholder)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.network(
                      'https://firebasestorage.googleapis.com/v0/b/wirexmenu-2fd27.firebasestorage.app/o/icon%2FmessageImage_1763726393248.jpg?alt=media',
                      height: 40,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                const Divider(color: Colors.grey, thickness: 0.5),
                const SizedBox(height: 16),

                // Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('total_payment'), style: const TextStyle(color: Colors.grey, fontSize: 14)),
                        Text("${currencyFormat.format(amount)} LAK", style: TextStyle(color: darkBlue, fontSize: 22, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(tr('total_items'), style: const TextStyle(color: Colors.grey, fontSize: 14)),
                        Text("$itemCount ${tr('items')}", style: TextStyle(color: darkBlue, fontSize: 22, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ปุ่มยกเลิก
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () {
                      _pollTimer?.cancel(); // หยุดเช็คสถานะ
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: darkBlue),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(tr('cancel_close'), style: TextStyle(color: darkBlue, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: darkBlue),
        centerTitle: true,
        title: Text(tr('select_menu'), style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_note, color: darkBlue),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const EditMenuPage()),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          // --- Search Bar ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: tr('search_menu'),
                prefixIcon: Icon(Icons.search, color: darkBlue),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: darkBlue, width: 1.5),
                ),
              ),
            ),
          ),
          
          // --- Menu Grid ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user?.uid)
                  .collection('menupos')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('${tr('error')}: ${snapshot.error}'));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final allDocs = snapshot.data!.docs;
                final filteredDocs = _searchQuery.isEmpty
                    ? allDocs
                    : allDocs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final name = (data['name'] ?? '').toString().toLowerCase();
                        return name.contains(_searchQuery);
                      }).toList();

                if (filteredDocs.isEmpty) {
                  return Center(child: Text(tr('menu_not_found')));
                }

                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    var doc = filteredDocs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    int qty = cart[doc.id] ?? 0;

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                image: DecorationImage(
                                  image: (data['imageUrl'] != null && data['imageUrl'] != "")
                                      ? NetworkImage(data['imageUrl'])
                                      : const AssetImage('assets/placeholder.png') as ImageProvider,
                                  fit: BoxFit.cover,
                                ),
                                color: Colors.grey[200],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(data['name'], style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("${currencyFormat.format(data['price'])} LAK", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    if (qty == 0)
                                      GestureDetector(
                                        onTap: () => _addToCart(doc.id, data),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(color: darkBlue, borderRadius: BorderRadius.circular(8)),
                                          child: const Icon(Icons.add, color: Colors.white, size: 18),
                                        ),
                                      )
                                    else
                                      Row(
                                        children: [
                                          GestureDetector(
                                            onTap: () => _removeFromCart(doc.id),
                                            child: Icon(Icons.remove_circle, color: darkBlue, size: 24),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 4),
                                            child: Text("$qty", style: const TextStyle(fontWeight: FontWeight.bold)),
                                          ),
                                          GestureDetector(
                                            onTap: () => _addToCart(doc.id, data),
                                            child: Icon(Icons.add_circle, color: darkBlue, size: 24),
                                          ),
                                        ],
                                      )
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // --- Bottom Actions ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6F9),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 5,
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "${tr('total')}: ${currencyFormat.format(_calculateTotal())} LAK", 
                    style: TextStyle(color: darkBlue, fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 12),

                  // ปุ่มเงินสด
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        double total = _calculateTotal();
                        if (total > 0) {
                           _showCashDialog(total);
                        } else {
                           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('please_select_item'))));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: lightBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text(tr('cash'), style: TextStyle(color: darkBlue, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ปุ่มสร้าง QR Code
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        double subtotal = _calculateTotal();
                        if (subtotal <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(tr('please_select_item'))),
                          );
                          return;
                        }

                        showDialog(
                          context: context, 
                          barrierDismissible: false,
                          builder: (c) => const Center(child: CircularProgressIndicator())
                        );

                        String orderId = "ORD-${DateTime.now().millisecondsSinceEpoch}";
                        String? qrCode = await OnepayService.generateQR(
                          amount: subtotal,
                          orderId: orderId,
                          description: "Table Order",
                        );

                        Navigator.pop(context); // ปิด Loading

                        if (qrCode != null) {
                           _showQRCodeDialog(qrCode, subtotal, _calculateTotalItems(), orderId);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(tr('cannot_create_qr'))),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: darkBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text(tr('create_qr'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
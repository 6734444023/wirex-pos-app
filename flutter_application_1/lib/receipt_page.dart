import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ✅ เพิ่ม
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ เพิ่ม
import 'print_preview_page.dart';

class ReceiptPage extends StatefulWidget {
  final Map<String, dynamic> orderData;
  final List<Map<String, dynamic>> items;
  final double totalAmount;
  final double cashReceived;
  final double change;

  const ReceiptPage({
    super.key,
    required this.orderData,
    required this.items,
    required this.totalAmount,
    this.cashReceived = 0,
    this.change = 0,
  });

  @override
  State<ReceiptPage> createState() => _ReceiptPageState();
}

class _ReceiptPageState extends State<ReceiptPage> {
  String _storeName = "ร้านค้าของคุณ"; // ชื่อเริ่มต้นระหว่างรอโหลด

  @override
  void initState() {
    super.initState();
    _fetchStoreName();
  }

  // ฟังก์ชันดึงชื่อร้านจาก Firestore
  Future<void> _fetchStoreName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data();
          if (mounted) {
            setState(() {
              // ดึงค่า storeName_pos ที่ตั้งไว้ในหน้าตั้งค่า
              _storeName = data?['storeName_pos'] ?? "ร้านค้าของคุณ";
            });
          }
        }
      } catch (e) {
        debugPrint("Error fetching store name: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color darkBlue = Color(0xFF1E2444);
    const Color lightBlue = Color(0xFFB3BCF5);
    final currencyFormat = NumberFormat("#,##0", "en_US");

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: darkBlue),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          "ใบเสร็จ",
          style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 5,
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- Header ---
                    const Text(
                      "ใบเสร็จรับเงิน / RECEIPT",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    
                    // --- Store Info ---
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // โลโก้ร้าน (Placeholder)
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: darkBlue,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Icon(Icons.store, color: Colors.white, size: 30),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ✅ แสดงชื่อร้านที่โหลดมา
                              Text(_storeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text(
                                "วันที่: ${DateFormat('dd/MM/yyyy เวลา HH:mm').format(DateTime.now())}",
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                              Text(
                                "เลขที่บิล: ${widget.orderData['orderId'] ?? '-'}",
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: Colors.grey, thickness: 0.5),
                    const SizedBox(height: 10),

                    // --- Items List ---
                    if (widget.items.isEmpty)
                       const Padding(
                         padding: EdgeInsets.symmetric(vertical: 10),
                         child: Text("- ไม่มีรายการสินค้า -"),
                       ),
                    ...widget.items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: Text(item['name'], style: const TextStyle(fontSize: 14)),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text("x${item['quantity']}", textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              "${currencyFormat.format(item['price'] * item['quantity'])} LAK",
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    )).toList(),

                    const SizedBox(height: 10),
                    const Divider(color: Colors.grey, thickness: 0.5),
                    const SizedBox(height: 10),

                    // --- Summary ---
                    _buildSummaryRow("Total", "${currencyFormat.format(widget.totalAmount)} LAK"),

                    const SizedBox(height: 10),
                    
                    // ส่วนแสดงเงินสดและเงินทอน
                    if (widget.cashReceived > 0) ...[
                       const Divider(color: Colors.grey, thickness: 0.5, height: 20),
                       _buildSummaryRow("รับเงินสด", "${currencyFormat.format(widget.cashReceived)} LAK"),
                       Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("เงินทอน", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                          Text("${currencyFormat.format(widget.change)} LAK", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ] else ...[
                       _buildSummaryRow("ชำระโดย", "QR Code"),
                    ],
                    
                    const SizedBox(height: 10),
                    const Divider(color: Colors.black, thickness: 1),
                    const SizedBox(height: 10),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("ยอดรวมสุทธิ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        Text(
                          "${currencyFormat.format(widget.totalAmount)} LAK",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.black),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),

                    // --- Footer ---
                    const Text("ขอบคุณที่ใช้บริการ 🙏", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    const Text(
                      "WireX Portable POS",
                      style: TextStyle(color: Color(0xFF1E2444), fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Serif'),
                    ),
                    const Text("Call center: 02077222099", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),

          // --- Print Buttons ---
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PrintPreviewPage(
                            copies: 2,
                            storeName: _storeName,
                            orderData: widget.orderData,
                            items: widget.items,
                            totalAmount: widget.totalAmount,
                            cashReceived: widget.cashReceived,
                            change: widget.change,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: darkBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("พิมพ์ 2 ฉบับ", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PrintPreviewPage(
                            copies: 1,
                            storeName: _storeName,
                            orderData: widget.orderData,
                            items: widget.items,
                            totalAmount: widget.totalAmount,
                            cashReceived: widget.cashReceived,
                            change: widget.change,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: lightBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text("พิมพ์ 1 ฉบับ", style: TextStyle(color: darkBlue, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Text(value, style: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'print_preview_page.dart';

class PaymentSuccessPage extends StatelessWidget {
  final double totalAmount;
  final Map<String, dynamic> orderData;
  final List<Map<String, dynamic>> items;
  final double cashReceived;
  final double change;
  final String storeName;

  const PaymentSuccessPage({
    super.key,
    required this.totalAmount,
    required this.orderData,
    required this.items,
    required this.storeName,
    this.cashReceived = 0,
    this.change = 0,
  });

  @override
  Widget build(BuildContext context) {
    const Color darkBlue = Color(0xFF1E2444);
    final currencyFormat = NumberFormat("#,##0.00", "en_US");

    return Scaffold(
      backgroundColor: darkBlue, // พื้นหลังสีน้ำเงินเข้ม
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo & Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.qr_code, color: darkBlue, size: 24),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      "WireX Portable POS",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Serif',
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 60),

                // Success Icon (วงกลมติ๊กถูก)
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.blue.shade300, width: 2),
                  ),
                  padding: const EdgeInsets.all(15),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.rectangle,
                      borderRadius: BorderRadius.all(Radius.circular(20)),
                    ),
                    child: const Center(
                      child: CircleAvatar(
                        backgroundColor: darkBlue,
                        radius: 25,
                        child: Icon(Icons.check, color: Colors.white, size: 30),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                const Text(
                  "ชำระเงินสำเร็จ",
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 30),

                // Amount Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 25),
                  decoration: BoxDecoration(
                    color: const Color(0xFF151A35),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      "${currencyFormat.format(totalAmount)} LAK",
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                
                const SizedBox(height: 50),

                // ปุ่มพิมพ์ใบเสร็จ
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () {
                      // ไปหน้า Print Preview
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PrintPreviewPage(
                            copies: 1,
                            storeName: storeName, // ส่งชื่อร้านไป
                            orderData: orderData,
                            items: items,
                            totalAmount: totalAmount,
                            cashReceived: cashReceived,
                            change: change,
                          ),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text("พิมพ์ใบเสร็จ", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),

                const SizedBox(height: 16),

                // ปุ่มกลับสู่เมนู
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context), // กลับไปหน้าสั่งอาหาร
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text("กลับสู่เมนู", style: TextStyle(color: darkBlue, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
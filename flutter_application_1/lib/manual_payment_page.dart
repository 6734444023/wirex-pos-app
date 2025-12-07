import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';
import 'l10n/app_translations.dart';
import 'providers/language_provider.dart';
import 'services/onepay_service.dart';
import 'services/transaction_service.dart';
import 'payment_success_page.dart';

class ManualPaymentPage extends StatefulWidget {
  const ManualPaymentPage({super.key});

  @override
  State<ManualPaymentPage> createState() => _ManualPaymentPageState();
}

class _ManualPaymentPageState extends State<ManualPaymentPage> {
  final Color darkBlue = const Color(0xFF1E2444);
  final Color lightBlueText = const Color(0xFFB3BCF5); // สีตัวหนังสือยอดเงิน
  
  String _amountStr = ""; // เก็บค่าตัวเลขที่กดเป็น String
  String _storeName = "WireX Smart POS";
  
  Timer? _pollTimer;
  final currencyFormat = NumberFormat("#,##0.##", "en_US");

  String tr(String key) {
    final lang = Provider.of<LanguageProvider>(context, listen: false).selectedLanguage;
    return AppTranslations.get(lang, key);
  }

  @override
  void initState() {
    super.initState();
    _fetchStoreName();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchStoreName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _storeName = doc.data()?['storeName_pos'] ?? "WireX Smart POS";
        });
      }
    }
  }

  // ฟังก์ชันจัดการเมื่อกดปุ่มตัวเลข
  void _onKeyPress(String value) {
    setState(() {
      if (value == 'C') {
        _amountStr = "";
      } else if (value == 'DEL') {
        if (_amountStr.isNotEmpty) {
          _amountStr = _amountStr.substring(0, _amountStr.length - 1);
        }
      } else {
        // ป้องกันการใส่ทศนิยมซ้ำ
        if (value == '.' && _amountStr.contains('.')) return;
        // จำกัดความยาว
        if (_amountStr.length > 9) return;
        
        _amountStr += value;
      }
    });
  }

  // ฟังก์ชันสำหรับปุ่มคีย์ลัด
  void _onQuickAmountPress(String amount) {
    setState(() {
      _amountStr = amount;
    });
  }

  // ฟังก์ชันเมื่อกด ENTER
  void _onEnterPress() async {
    double amount = double.tryParse(_amountStr) ?? 0;
    if (amount <= 0) return;

    // 1. แสดง Loading
    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator())
    );

    // 2. เรียก API สร้าง QR
    String orderId = "MANUAL-${DateTime.now().millisecondsSinceEpoch}";
    String? qrCode = await OnepayService.generateQR(
      amount: amount,
      orderId: orderId,
      description: "Manual Payment",
    );

    Navigator.pop(context); // ปิด Loading

    // 3. แสดง QR Dialog
    if (qrCode != null) {
       _showQRCodeDialog(qrCode, amount, orderId);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('cannot_create_qr'))),
      );
    }
  }

  void _showQRCodeDialog(String qrData, double amount, String orderId) {
    // เริ่มเช็คสถานะ
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      bool isPaid = await OnepayService.checkPaymentStatus(orderId);
      if (isPaid) {
        timer.cancel();
        if (mounted) {
          Navigator.pop(context); // ปิด Dialog QR
          _goToSuccessPage(amount, orderId);
        }
      }
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
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
              // Bank Logos
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
                      Text(tr('type'), style: const TextStyle(color: Colors.grey, fontSize: 14)),
                      Text(tr('quick_pay'), style: TextStyle(color: darkBlue, fontSize: 22, fontWeight: FontWeight.bold)),
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
                    _pollTimer?.cancel();
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
      ),
    );
  }



  void _goToSuccessPage(double amount, String orderId) {
    // Save Transaction
    TransactionService.saveTransaction(
      orderId: orderId,
      amount: amount,
      type: 'manual',
      status: 'paid',
      items: [
        {'name': tr('service_payment'), 'price': amount, 'quantity': 1}
      ],
      paymentMethod: 'qr',
      cashReceived: amount,
      change: 0,
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentSuccessPage(
          storeName: _storeName,
          totalAmount: amount,
          orderData: {'orderId': orderId},
          items: [
            // สร้างรายการจำลองสำหรับใบเสร็จ
            {'name': tr('service_payment'), 'price': amount, 'quantity': 1}
          ],
          cashReceived: amount, // ถือว่าจ่ายพอดี
          change: 0,
          autoPrint: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA), // พื้นหลังสีเทาอ่อนๆ ตามรูป
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: darkBlue),
        centerTitle: true,
        title: Text(tr('enter_amount'), style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // --- ส่วนแสดงผลตัวเลข ---
          Expanded(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _amountStr.isEmpty ? "0 LAK" : "${currencyFormat.format(double.tryParse(_amountStr) ?? 0)} LAK",
                    style: TextStyle(
                      color: _amountStr.isEmpty ? Colors.grey[300] : darkBlue,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  // ปุ่มคีย์ลัด
                  Column(
                    children: [
                      Row(
                        children: [
                          _buildQuickAmountBtn('20000'),
                          const SizedBox(width: 8),
                          _buildQuickAmountBtn('50000'),
                          const SizedBox(width: 8),
                          _buildQuickAmountBtn('100000'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildQuickAmountBtn('300000'),
                          const SizedBox(width: 8),
                          _buildQuickAmountBtn('500000'),
                          const SizedBox(width: 8),
                          _buildQuickAmountBtn('1000000'),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // --- Keypad Section ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 3 คอลัมน์ซ้าย (ตัวเลข)
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      _buildKeyRow(['1', '2', '3']),
                      const SizedBox(height: 10),
                      _buildKeyRow(['4', '5', '6']),
                      const SizedBox(height: 10),
                      _buildKeyRow(['7', '8', '9']),
                      const SizedBox(height: 10),
                      _buildKeyRow(['C', '0', '000']),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // 1 คอลัมน์ขวา (ลบ และ Enter)
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      // ปุ่มลบ (Backspace)
                      _buildKeyBtn(
                        label: '',
                        icon: Icons.backspace_outlined,
                        color: Colors.white,
                        textColor: darkBlue,
                        onTap: () => _onKeyPress('DEL'),
                        height: 80, // ความสูงเท่าแถวปกติ
                      ),
                      const SizedBox(height: 10),
                      // ปุ่ม ENTER (ยาวลงมา)
                      GestureDetector(
                        onTap: _onEnterPress,
                        child: Container(
                          height: 260, // ความสูง = 3 ปุ่ม + ช่องว่าง
                          decoration: BoxDecoration(
                            color: darkBlue,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))],
                          ),
                          child: Center(
                            child: Text(
                              tr('enter'),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // --- Footer ---
          Padding(
            padding: const EdgeInsets.only(bottom: 30),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: darkBlue,
                        borderRadius: BorderRadius.zero,
                        image: const DecorationImage(
                          image: NetworkImage(
                            'https://firebasestorage.googleapis.com/v0/b/wirexmenu-2fd27.firebasestorage.app/o/logo%2FmessageImage_1763726179957.jpg?alt=media',
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(tr('wirex_pos'), style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 5),
                Text("${tr('call_center')} : 02077222099", style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyRow(List<String> keys) {
    return Row(
      children: keys.map((key) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: _buildKeyBtn(
              label: key,
              onTap: () => _onKeyPress(key),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildKeyBtn({
    required String label,
    IconData? icon,
    VoidCallback? onTap,
    Color color = Colors.white,
    Color textColor = const Color(0xFF1E2444),
    double height = 80,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Center(
          child: icon != null
              ? Icon(icon, color: textColor, size: 28)
              : Text(
                  label,
                  style: TextStyle(color: textColor, fontSize: 28, fontWeight: FontWeight.w500),
                ),
        ),
      ),
    );
  }

  Widget _buildQuickAmountBtn(String amount) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _onQuickAmountPress(amount),
        child: Container(
          height: 45,
          decoration: BoxDecoration(
            color: darkBlue,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: Center(
            child: Text(
              currencyFormat.format(double.parse(amount)),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
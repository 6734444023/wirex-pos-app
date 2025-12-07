import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'l10n/app_translations.dart';
import 'providers/language_provider.dart';
import 'services/sunmi_service.dart';

class PaymentSuccessPage extends StatefulWidget {
  final double totalAmount;
  final Map<String, dynamic> orderData;
  final List<Map<String, dynamic>> items;
  final double cashReceived;
  final double change;
  final String storeName;
  final bool autoPrint;

  const PaymentSuccessPage({
    super.key,
    required this.totalAmount,
    required this.orderData,
    required this.items,
    required this.storeName,
    this.cashReceived = 0,
    this.change = 0,
    this.autoPrint = false,
  });

  @override
  State<PaymentSuccessPage> createState() => _PaymentSuccessPageState();
}

class _PaymentSuccessPageState extends State<PaymentSuccessPage> {
  @override
  void initState() {
    super.initState();
    if (widget.autoPrint) {
      _printReceipt();
    }
  }

  Future<void> _printReceipt() async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    await SunmiService.printReceipt(
      storeName: widget.storeName,
      orderId: widget.orderData['orderId'] ?? '-',
      items: widget.items,
      totalAmount: widget.totalAmount,
      cashReceived: widget.cashReceived,
      change: widget.change,
      paymentMethod: widget.cashReceived > 0 ? 'cash' : 'qr',
      language: languageProvider.selectedLanguage,
    );
  }

  String tr(String key) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    return AppTranslations.get(languageProvider.selectedLanguage, key);
  }

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
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.zero,
                        image: const DecorationImage(
                          image: NetworkImage(
                            'https://firebasestorage.googleapis.com/v0/b/wirexmenu-2fd27.firebasestorage.app/o/logo%2FmessageImage_1763726179957.jpg?alt=media',
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      tr('wirex_pos'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
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

                Text(
                  tr('payment_success'),
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
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
                      "${currencyFormat.format(widget.totalAmount)} LAK",
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                
                const SizedBox(height: 50),

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
                    child: Text(tr('back_to_menu'), style: const TextStyle(color: darkBlue, fontSize: 16, fontWeight: FontWeight.bold)),
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
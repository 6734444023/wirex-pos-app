import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'l10n/app_translations.dart';
import 'providers/language_provider.dart';
import 'services/sunmi_service.dart';

class GasPaymentSuccessPage extends StatefulWidget {
  final double totalAmount;
  final String fuelName;
  final double liters;
  final double pricePerLiter;
  final String storeName;
  final bool autoPrint;

  const GasPaymentSuccessPage({
    super.key,
    required this.totalAmount,
    required this.fuelName,
    required this.liters,
    required this.pricePerLiter,
    required this.storeName,
    this.autoPrint = false,
  });

  @override
  State<GasPaymentSuccessPage> createState() => _GasPaymentSuccessPageState();
}

class _GasPaymentSuccessPageState extends State<GasPaymentSuccessPage> {
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
      orderId: "GAS-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}",
      items: [
        {
          'name': "${widget.fuelName} (${widget.pricePerLiter.toStringAsFixed(0)}/L)",
          'quantity': 1,
          'price': widget.totalAmount,
        },
        {
          'name': tr('liters_amount'),
          'quantity': 0,
          'price': widget.liters,
        }
      ],
      totalAmount: widget.totalAmount,
      cashReceived: widget.totalAmount,
      change: 0,
      paymentMethod: 'cash', // Assuming cash for now or passed from previous page if needed
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
                  padding: const EdgeInsets.all(15), // Gap ระหว่างวงนอกกับใน
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white, // พื้นหลังขาวตามรูป
                      shape: BoxShape.rectangle,
                      borderRadius: BorderRadius.all(Radius.circular(20)), // ทำเป็นรูปมือถือตามรูป
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
                    color: const Color(0xFF151A35), // สีพื้นหลังกล่องเงิน (เข้มกว่า bg นิดนึง)
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      "${currencyFormat.format(widget.totalAmount)} LAK",
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                
                const SizedBox(height: 10),
                // รายละเอียดเพิ่มเติมเล็กน้อย (Optional)
                Text(
                  "${widget.fuelName}: ${widget.liters.toStringAsFixed(2)} ${tr('liters')}",
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                ),

                const SizedBox(height: 50),

                // Back Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context), // กลับไปหน้าปั๊ม
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
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'edit_fuel_page.dart';
import 'gas_payment_success_page.dart';
import 'services/onepay_service.dart';
import 'services/transaction_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'l10n/app_translations.dart';
import 'providers/language_provider.dart';

class GasStationPage extends StatefulWidget {
  const GasStationPage({super.key});

  @override
  State<GasStationPage> createState() => _GasStationPageState();
}

class _GasStationPageState extends State<GasStationPage> {
  final Color darkBlue = const Color(0xFF1E2444);
  final user = FirebaseAuth.instance.currentUser;
  final currencyFormat = NumberFormat("#,##0", "en_US");

  Map<String, dynamic>? _selectedFuel;
  final TextEditingController _amountController = TextEditingController();
  double _liters = 0.0;
  String _storeName = "WireX Station";
  Timer? _pollTimer;

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
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _storeName = doc.data()?['storeName_pos'] ?? "WireX Station";
        });
      }
    }
  }

  void _calculateLiters(String value) {
    double amount = double.tryParse(value.replaceAll(',', '')) ?? 0;
    if (_selectedFuel != null) {
      double price = (_selectedFuel!['pricePerLiter'] as num).toDouble();
      setState(() {
        _liters = (price > 0) ? amount / price : 0;
      });
    }
  }

  void _processPayment(String type) async {
    double amount = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;
    if (amount <= 0 || _selectedFuel == null) return;

    if (type == 'cash') {
      // Save Transaction
      TransactionService.saveTransaction(
        orderId: "GAS-${DateTime.now().millisecondsSinceEpoch}",
        amount: amount,
        type: 'gas',
        status: 'paid',
        items: [
          {'name': _selectedFuel!['name'], 'price': amount, 'quantity': _liters}
        ],
        paymentMethod: 'cash',
        cashReceived: amount,
        change: 0,
      );

      // ถ้าเงินสด ไปหน้าสำเร็จเลย
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GasPaymentSuccessPage(
            totalAmount: amount,
            fuelName: _selectedFuel!['name'],
            liters: _liters,
            pricePerLiter: (_selectedFuel!['pricePerLiter'] as num).toDouble(),
            storeName: _storeName,
            autoPrint: true,
          ),
        ),
      );
    } else {
      // QR Code Logic (ย่อ)
      showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));
      String orderId = "GAS-${DateTime.now().millisecondsSinceEpoch}";
      String? qrCode = await OnepayService.generateQR(amount: amount, orderId: orderId, description: "Fuel");
      Navigator.pop(context);

      if (qrCode != null) {
        // แสดง QR Dialog และรอจ่าย
         _showQRCodeDialog(qrCode, amount, orderId);
      }
    }
  }

  void _showQRCodeDialog(String qrData, double amount, String orderId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      bool isPaid = await OnepayService.checkPaymentStatus(orderId);
      if (isPaid) {
        timer.cancel();
        if (mounted) {
          Navigator.pop(context);
          
          // Save Transaction
          TransactionService.saveTransaction(
            orderId: orderId,
            amount: amount,
            type: 'gas',
            status: 'paid',
            items: [
              {'name': _selectedFuel!['name'], 'price': amount, 'quantity': _liters}
            ],
            paymentMethod: 'qr',
            cashReceived: amount,
            change: 0,
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => GasPaymentSuccessPage(
                totalAmount: amount,
                fuelName: _selectedFuel!['name'],
                liters: _liters,
                pricePerLiter: (_selectedFuel!['pricePerLiter'] as num).toDouble(),
                storeName: _storeName,
                autoPrint: true,
              ),
            ),
          );
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
                  _buildBankIcon(Colors.red, "One"),
                  _buildBankIcon(Colors.blue, "BFL"),
                  _buildBankIcon(Colors.green, "JDB"),
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
                      Text(tr('fill_fuel'), style: const TextStyle(color: Colors.grey, fontSize: 14)),
                      Text("${_liters.toStringAsFixed(2)} ${tr('liters')}", style: TextStyle(color: darkBlue, fontSize: 22, fontWeight: FontWeight.bold)),
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

  Widget _buildBankIcon(Color color, String text) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(tr('gas_station_title'), style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: darkBlue),
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: darkBlue),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const EditFuelPage())),
          )
        ],
      ),
      body: Column(
        children: [
          // 1. Fuel Selector
          SizedBox(
            height: 120,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).collection('fuel_types').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                var docs = snapshot.data!.docs;
                if (docs.isEmpty) return Center(child: Text(tr('add_fuel_type')));

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  scrollDirection: Axis.horizontal,
                  itemCount: docs.length,
                  separatorBuilder: (c, i) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    bool isSelected = _selectedFuel?['name'] == data['name'];

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedFuel = data;
                          _calculateLiters(_amountController.text);
                        });
                      },
                      child: Container(
                        width: 120,
                        decoration: BoxDecoration(
                          color: isSelected ? darkBlue : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isSelected ? darkBlue : Colors.grey.shade300),
                          boxShadow: isSelected ? [BoxShadow(color: darkBlue.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.local_gas_station, color: isSelected ? Colors.white : Colors.grey, size: 32),
                            const SizedBox(height: 8),
                            Text(data['name'], style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                            Text("${data['pricePerLiter']} LAK", style: TextStyle(color: isSelected ? Colors.white70 : Colors.grey, fontSize: 10)),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // 2. Input & Display
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_selectedFuel != null ? "${tr('fill_fuel')} ${_selectedFuel!['name']}" : tr('please_select_fuel'), style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                  const SizedBox(height: 20),
                  
                  // Amount Input
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    readOnly: _selectedFuel == null,
                    onTap: () {
                      if (_selectedFuel == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(tr('please_select_fuel'))),
                        );
                      }
                    },
                    style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: darkBlue),
                    decoration: const InputDecoration(
                      hintText: "0",
                      border: InputBorder.none,
                      suffixText: "LAK",
                    ),
                    onChanged: _calculateLiters,
                  ),
                  const Divider(),
                  
                  // Liters Display
                  Text(
                    "${_liters.toStringAsFixed(2)} ${tr('liters')}",
                    style: const TextStyle(fontSize: 24, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),

          // 3. Keypad & Action (Simplified)
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 60,
                    child: ElevatedButton(
                      onPressed: () => _processPayment('cash'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(tr('cash'), style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 60,
                    child: ElevatedButton(
                      onPressed: () => _processPayment('qr'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: darkBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(tr('qr_code'), style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
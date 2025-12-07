import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'l10n/app_translations.dart';
import 'providers/language_provider.dart';
import 'services/transaction_service.dart';
import 'services/sunmi_service.dart';

class TransactionHistoryPage extends StatefulWidget {
  const TransactionHistoryPage({super.key});

  @override
  State<TransactionHistoryPage> createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends State<TransactionHistoryPage> {
  final Color darkBlue = const Color(0xFF1E2444);
  final Color lightBlueText = const Color(0xFFB3BCF5);
  final currencyFormat = NumberFormat("#,##0.00", "en_US");
  String _storeName = "WireX Smart POS";

  String tr(String key) {
    final lang = Provider.of<LanguageProvider>(context, listen: false).selectedLanguage;
    return AppTranslations.get(lang, key);
  }

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('th', null);
    _fetchStoreName();
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

  String _formatDateHeader(DateTime date) {
    // Example: วันอาทิตย์, 02 สิงหาคม 2020
    // If 'th' locale is not available, it will fallback or might need manual mapping.
    // Trying standard intl format first.
    try {
      return DateFormat('EEEE, dd MMMM yyyy', 'th').format(date);
    } catch (e) {
      return DateFormat('EEEE, dd MMMM yyyy').format(date);
    }
  }

  String _formatTime(DateTime date) {
    return DateFormat('hh.mm a').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: darkBlue),
        centerTitle: true,
        title: Text(tr('transaction_history'), style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Filter Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.manage_search, color: darkBlue),
                    const SizedBox(width: 8),
                    Text(tr('date_time_filter'), style: TextStyle(color: darkBlue, fontSize: 16)),
                  ],
                ),
                Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
          
          // List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: TransactionService.getTransactions(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('${tr('error')}: ${snapshot.error}'));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return Center(child: Text(tr('no_transactions_found')));

                // Group by Date
                Map<String, List<DocumentSnapshot>> grouped = {};
                for (var doc in docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final timestamp = data['createdAt'] as Timestamp?;
                  if (timestamp == null) continue;
                  
                  final date = timestamp.toDate();
                  final dateKey = _formatDateHeader(date);
                  
                  if (!grouped.containsKey(dateKey)) {
                    grouped[dateKey] = [];
                  }
                  grouped[dateKey]!.add(doc);
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: grouped.length,
                  itemBuilder: (context, index) {
                    String dateKey = grouped.keys.elementAt(index);
                    List<DocumentSnapshot> transactions = grouped[dateKey]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date Header
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: darkBlue,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(dateKey, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              Text(
                                "${currencyFormat.format(transactions.fold(0.0, (sum, doc) => sum + ((doc.data() as Map)['amount'] ?? 0)))} LAK",
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),

                        // Transactions in this date
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                            boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4)],
                          ),
                          child: Column(
                            children: transactions.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final timestamp = (data['createdAt'] as Timestamp).toDate();
                              final amount = data['amount'] ?? 0.0;
                              final cashReceived = data['cashReceived'] ?? amount;
                              final change = data['change'] ?? 0.0;
                              final orderId = data['orderId'] ?? '-';
                              final status = data['status'] ?? 'unknown';

                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "${currencyFormat.format(amount)} LAK",
                                            style: TextStyle(color: darkBlue, fontSize: 18, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "${_formatTime(timestamp)} - #$orderId",
                                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: darkBlue,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            status == 'paid' ? tr('paid') : status,
                                            style: const TextStyle(color: Colors.white, fontSize: 12),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () async {
                                            // Reprint directly via Sunmi
                                            await SunmiService.printReceipt(
                                              storeName: _storeName,
                                              orderId: orderId,
                                              items: List<Map<String, dynamic>>.from(data['items'] ?? []),
                                              totalAmount: amount,
                                              cashReceived: cashReceived,
                                              change: change,
                                              paymentMethod: cashReceived > 0 ? 'cash' : 'qr',
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFB3BCF5),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              tr('reprint'),
                                              style: const TextStyle(color: Color(0xFF1E2444), fontSize: 12, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

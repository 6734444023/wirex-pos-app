import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TransactionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<void> saveTransaction({
    required String orderId,
    required double amount,
    required String type, // 'manual', 'shop', 'restaurant', 'gas'
    required String status, // 'paid'
    required List<Map<String, dynamic>> items,
    String? paymentMethod, // 'cash', 'qr'
    double cashReceived = 0,
    double change = 0,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('transactions')
          .add({
        'orderId': orderId,
        'amount': amount,
        'type': type,
        'status': status,
        'items': items,
        'paymentMethod': paymentMethod ?? 'unknown',
        'cashReceived': cashReceived,
        'change': change,
        'createdAt': FieldValue.serverTimestamp(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      print("Error saving transaction: $e");
    }
  }

  static Stream<QuerySnapshot> getTransactions() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('transactions')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}

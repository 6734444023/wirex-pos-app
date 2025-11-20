import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OnepayService {
  // ใส่ URL ของคุณเหมือนเดิม
  static const String _baseUrl = "https://api-blprlkxsua-as.a.run.app"; 

  // ฟังก์ชันคำนวณราคาสุทธิ
  static Future<double> calculateFinalAmount(double subtotal) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return subtotal;

    try {
      // ดึงค่า Setting ล่าสุดจาก Firestore
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        
        // ✅ เปลี่ยนตรงนี้: อ่านค่าจาก _pos
        final vatMode = data['vatMode_pos'] ?? 'in';
        final vatRate = (data['vatRate_pos'] ?? 10).toInt();

        if (vatMode == 'out') {
          // ถ้า VAT นอก: ราคาสินค้า + (ราคาสินค้า * vat%)
          // ตัวอย่าง: ของ 100, vat 7% -> จ่าย 107
          return subtotal + (subtotal * vatRate / 100);
        }
      }
    } catch (e) {
      print("Error calculating VAT: $e");
    }
    
    // ถ้า VAT ใน (in) หรือหาค่าไม่เจอ ให้ใช้ราคาเดิม
    return subtotal;
  }

  // ฟังก์ชันสร้าง QR Code
  static Future<String?> generateQR({
    required double amount, 
    required String orderId,
    required String description,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    // 1. คำนวณยอดเงินจริงตาม VAT Setting (แบบ _pos) ก่อนส่ง
    double finalAmount = await calculateFinalAmount(amount);

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/onepay/generate-qr'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': finalAmount,
          'orderId': orderId,
          'desc': description,
          'userId': user.uid, 
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['qrc']; 
      } else {
        print("API Error: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Network Error: $e");
      return null;
    }
  }

  static Future<bool> checkPaymentStatus(String orderId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/onepay/check-status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'orderId': orderId,
          'userId': user.uid, 
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // สมมติว่า API ตอบกลับมาว่า result: 0 คือสำเร็จ (ปรับตาม API จริงของคุณ)
        return data['result'] == 0 || data['status'] == 'SUCCESS'; 
      }
      return false;
    } catch (e) {
      print("Check Status Error: $e");
      return false;
    }
  }
}
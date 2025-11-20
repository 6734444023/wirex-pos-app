import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final Color darkBlue = const Color(0xFF1E2444);
  final Color lightBackground = const Color(0xFFF4F6F9);

  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  final List<int> _vatOptions = [0, 3, 5, 7, 10];
  int _selectedVat = 7;
  String _vatMode = 'in'; // 'in' = VAT ใน, 'out' = VAT นอก
  bool _isLoading = true;

  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // โหลดข้อมูลร้านค้า (อ่านจาก field _pos)
  Future<void> _loadSettings() async {
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          // ✅ เปลี่ยนตรงนี้: อ่านจาก key ที่ลงท้ายด้วย _pos
          _storeNameController.text = data['storeName_pos'] ?? '';
          _phoneController.text = data['phone_pos'] ?? '';
          _selectedVat = (data['vatRate_pos'] ?? 7).toInt();
          _vatMode = data['vatMode_pos'] ?? 'in';
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Error loading settings: $e");
      setState(() => _isLoading = false);
    }
  }

  // บันทึกข้อมูล (บันทึกเป็น _pos)
  Future<void> _saveSettings() async {
    if (user == null) return;
    
    setState(() => _isLoading = true);
    try {
      // ✅ เปลี่ยนตรงนี้: บันทึก key เป็น _pos ทั้งหมด
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
        'storeName_pos': _storeNameController.text,
        'phone_pos': _phoneController.text,
        'vatRate_pos': _selectedVat,
        'vatMode_pos': _vatMode,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('บันทึกการตั้งค่า (POS) แล้ว'), backgroundColor: darkBlue),
        );
      }
    } catch (e) {
      print("Error saving: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เกิดข้อผิดพลาด'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: darkBlue),
        title: Text(
          'ตั้งค่าร้านค้า (POS)',
          style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionCard(
                title: 'ข้อมูลร้านค้า',
                child: Column(
                  children: [
                    _buildLabeledField(
                      label: 'ชื่อร้าน',
                      child: TextField(
                        controller: _storeNameController,
                        decoration: const InputDecoration(hintText: 'เช่น WireX Café'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildLabeledField(
                      label: 'เบอร์โทรร้าน',
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(hintText: 'เช่น 020-123-4567'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildSectionCard(
                title: 'การตั้งค่า VAT',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('อัตรา VAT (%)', style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: _selectedVat,
                      items: _vatOptions.map((value) => DropdownMenuItem<int>(value: value, child: Text('$value%'))).toList(),
                      onChanged: (value) => setState(() => _selectedVat = value!),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('รูปแบบ VAT', style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildVatToggle('VAT ใน (รวมในราคา)', 'in'),
                        const SizedBox(width: 10),
                        _buildVatToggle('VAT นอก (บวกเพิ่ม)', 'out'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _saveSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: darkBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('บันทึกการตั้งค่า', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: darkBlue, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        child,
      ]),
    );
  }

  Widget _buildLabeledField({required String label, required Widget child}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      child,
    ]);
  }

  Widget _buildVatToggle(String label, String value) {
    final bool isSelected = _vatMode == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _vatMode = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? darkBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? darkBlue : Colors.transparent, width: 1.5),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : darkBlue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
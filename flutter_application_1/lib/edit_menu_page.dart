import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart'; // สำหรับอัปโหลดรูป
import 'package:image_picker/image_picker.dart'; // สำหรับเลือกรูป
import 'package:provider/provider.dart';
import 'l10n/app_translations.dart';
import 'providers/language_provider.dart';

class EditMenuPage extends StatefulWidget {
  const EditMenuPage({super.key});

  @override
  State<EditMenuPage> createState() => _EditMenuPageState();
}

class _EditMenuPageState extends State<EditMenuPage> {
  final Color darkBlue = const Color(0xFF1E2444);
  final user = FirebaseAuth.instance.currentUser;
  
  // ตัวแปรเก็บรูปที่เลือกชั่วคราว
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  String tr(String key) {
    final lang = Provider.of<LanguageProvider>(context, listen: false).selectedLanguage;
    return AppTranslations.get(lang, key);
  }

  // ฟังก์ชันเลือกรูป
  Future<void> _pickImage(StateSetter setStateDialog) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setStateDialog(() {
        _selectedImage = File(image.path);
      });
    }
  }

  // ฟังก์ชันอัปโหลดรูปขึ้น Firebase Storage
  Future<String> _uploadImage(File imageFile) async {
    try {
      String fileName = 'menu_${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference ref = FirebaseStorage.instance
          .ref()
          .child('users/${user!.uid}/menu_images/$fileName');
      
      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } catch (e) {
      print("Upload Error: $e");
      return "";
    }
  }

  void _showAddMenuDialog() {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    _selectedImage = null; // รีเซ็ตรูปเก่า

    showDialog(
      context: context,
      barrierDismissible: false, // ห้ามกดปิดตอนโหลด
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(tr('add_new_menu')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- ส่วนเลือกรูปภาพ ---
                GestureDetector(
                  onTap: () => _pickImage(setStateDialog),
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade400),
                      image: _selectedImage != null
                          ? DecorationImage(
                              image: FileImage(_selectedImage!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _selectedImage == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt, color: Colors.grey[600], size: 40),
                              Text(tr('tap_to_pick_image'), style: TextStyle(color: Colors.grey[600])),
                            ],
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: tr('menu_name')),
                ),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: tr('price_lak')),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: _isUploading ? null : () => Navigator.pop(context),
                child: Text(tr('cancel')),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: darkBlue),
                onPressed: _isUploading
                    ? null
                    : () async {
                        if (user != null &&
                            nameController.text.isNotEmpty &&
                            priceController.text.isNotEmpty) {
                          
                          setStateDialog(() => _isUploading = true); // เริ่มโหลด

                          String imageUrl = "";
                          // ถ้ามีการเลือกรูป ให้อัปโหลดก่อน
                          if (_selectedImage != null) {
                            imageUrl = await _uploadImage(_selectedImage!);
                          }

                          // บันทึกลง Firestore (menupos)
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(user!.uid)
                              .collection('menupos')
                              .add({
                            'name': nameController.text,
                            'price': double.tryParse(priceController.text) ?? 0,
                            'imageUrl': imageUrl, // ใช้ URL จาก Storage
                            'category': 'general',
                            'isAvailable': true,
                            'createdAt': FieldValue.serverTimestamp(),
                          });

                          setStateDialog(() => _isUploading = false); // จบโหลด
                          if (mounted) Navigator.pop(context);
                        }
                      },
                child: _isUploading
                    ? const SizedBox(
                        width: 20, height: 20, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(tr('save'), style: const TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  // ฟังก์ชันลบเมนู
  void _deleteMenu(String docId) {
    if (user != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('menupos')
          .doc(docId)
          .delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: darkBlue),
        centerTitle: true,
        title: Text(
          tr('edit_menu'),
          style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .collection('menupos')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var docs = snapshot.data!.docs;

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.8,
            ),
            // +1 เพื่อเพิ่มปุ่ม Add
            itemCount: docs.length + 1,
            itemBuilder: (context, index) {
              // ปุ่มเพิ่มเมนู (แสดงเป็นอันแรกหรืออันสุดท้ายก็ได้ อันนี้เอาไว้ท้าย)
              if (index == docs.length) {
                return GestureDetector(
                  onTap: _showAddMenuDialog,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, size: 40, color: darkBlue),
                        const SizedBox(height: 8),
                        Text(tr('add_menu'), style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                );
              }

              var data = docs[index].data() as Map<String, dynamic>;
              return Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                              image: DecorationImage(
                                image: (data['imageUrl'] != null && data['imageUrl'] != "")
                                    ? NetworkImage(data['imageUrl'])
                                    : const AssetImage('assets/placeholder.png') as ImageProvider,
                                fit: BoxFit.cover,
                              ),
                              color: Colors.grey[200],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['name'] ?? tr('no_name'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
                              Text("${data['price']} LAK", style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 8, right: 8,
                    child: GestureDetector(
                      onTap: () => _deleteMenu(docs[index].id),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
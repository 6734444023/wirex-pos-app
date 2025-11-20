import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class EditShopProductPage extends StatefulWidget {
  const EditShopProductPage({super.key});

  @override
  State<EditShopProductPage> createState() => _EditShopProductPageState();
}

class _EditShopProductPageState extends State<EditShopProductPage> {
  final Color darkBlue = const Color(0xFF1E2444);
  final user = FirebaseAuth.instance.currentUser;
  
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  Future<void> _pickImage(StateSetter setStateDialog) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setStateDialog(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<String> _uploadImage(File imageFile) async {
    try {
      String fileName = 'shop_${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference ref = FirebaseStorage.instance
          .ref()
          .child('users/${user!.uid}/shop_images/$fileName');
      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } catch (e) {
      print("Upload Error: $e");
      return "";
    }
  }

  void _showAddProductDialog() {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final barcodeController = TextEditingController(); // ✅ เพิ่ม Controller บาร์โค้ด
    _selectedImage = null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text("เพิ่มสินค้าใหม่"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                                Text("แตะเพื่อเลือกรูป", style: TextStyle(color: Colors.grey[600])),
                              ],
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: "ชื่อสินค้า"),
                  ),
                  TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "ราคา (LAK)"),
                  ),
                  // ✅ เพิ่มช่องกรอกบาร์โค้ด
                  TextField(
                    controller: barcodeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "รหัสบาร์โค้ด",
                      prefixIcon: Icon(Icons.qr_code),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: _isUploading ? null : () => Navigator.pop(context),
                child: const Text("ยกเลิก"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: darkBlue),
                onPressed: _isUploading
                    ? null
                    : () async {
                        if (user != null && nameController.text.isNotEmpty && priceController.text.isNotEmpty) {
                          setStateDialog(() => _isUploading = true);

                          String imageUrl = "";
                          if (_selectedImage != null) {
                            imageUrl = await _uploadImage(_selectedImage!);
                          }

                          // ✅ บันทึกลง collection 'shop_products' และเพิ่ม field barcode
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(user!.uid)
                              .collection('shop_products')
                              .add({
                            'name': nameController.text,
                            'price': double.tryParse(priceController.text) ?? 0,
                            'barcode': barcodeController.text, // บันทึกบาร์โค้ด
                            'imageUrl': imageUrl,
                            'category': 'general',
                            'isAvailable': true,
                            'createdAt': FieldValue.serverTimestamp(),
                          });

                          setStateDialog(() => _isUploading = false);
                          if (mounted) Navigator.pop(context);
                        }
                      },
                child: _isUploading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("บันทึก", style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _deleteProduct(String docId) {
    if (user != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('shop_products')
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
        title: Text("จัดการสินค้า", style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .collection('shop_products')
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
              childAspectRatio: 0.75, // ปรับให้ยาวขึ้นนิดนึงเผื่อที่ให้บาร์โค้ด
            ),
            itemCount: docs.length + 1,
            itemBuilder: (context, index) {
              if (index == docs.length) {
                return GestureDetector(
                  onTap: _showAddProductDialog,
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
                        Text("เพิ่มสินค้า", style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold)),
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
                                data['name'] ?? 'No Name',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
                              // ✅ แสดงบาร์โค้ด
                              if (data['barcode'] != null && data['barcode'] != "")
                                Text("Barcode: ${data['barcode']}", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                              
                              const SizedBox(height: 4),
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
                      onTap: () => _deleteProduct(docs[index].id),
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
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'l10n/app_translations.dart';
import 'providers/language_provider.dart';

class EditFuelPage extends StatefulWidget {
  const EditFuelPage({super.key});

  @override
  State<EditFuelPage> createState() => _EditFuelPageState();
}

class _EditFuelPageState extends State<EditFuelPage> {
  final Color darkBlue = const Color(0xFF1E2444);
  final user = FirebaseAuth.instance.currentUser;

  String tr(String key) {
    final lang = Provider.of<LanguageProvider>(context, listen: false).selectedLanguage;
    return AppTranslations.get(lang, key);
  }

  void _showAddFuelDialog() {
    final nameController = TextEditingController();
    final priceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('add_fuel_type_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: tr('fuel_name_hint')),
            ),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: tr('price_per_liter')),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: darkBlue),
            onPressed: () async {
              if (user != null && nameController.text.isNotEmpty && priceController.text.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user!.uid)
                    .collection('fuel_types')
                    .add({
                  'name': nameController.text,
                  'pricePerLiter': double.tryParse(priceController.text) ?? 0,
                  'isAvailable': true,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (mounted) Navigator.pop(context);
              }
            },
            child: Text(tr('save'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _deleteFuel(String docId) {
    if (user != null) {
      FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('fuel_types').doc(docId).delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(tr('manage_fuel_prices'), style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: darkBlue),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddFuelDialog,
        backgroundColor: darkBlue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).collection('fuel_types').orderBy('createdAt').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var docs = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (c, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, 2))],
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data['name'], style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue)),
                        Text("${data['pricePerLiter']} LAK / ${tr('liters')}", style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteFuel(docs[index].id),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
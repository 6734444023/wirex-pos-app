import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'l10n/app_translations.dart';
import 'providers/language_provider.dart';

class PrintPreviewPage extends StatelessWidget {
  final int copies;
  final String storeName;
  final Map<String, dynamic> orderData;
  final List<Map<String, dynamic>> items;
  final double totalAmount;
  final double cashReceived;
  final double change;

  const PrintPreviewPage({
    super.key,
    required this.copies,
    required this.storeName,
    required this.orderData,
    required this.items,
    required this.totalAmount,
    required this.cashReceived,
    required this.change,
  });

  @override
  Widget build(BuildContext context) {
    final language = Provider.of<LanguageProvider>(context).selectedLanguage;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslations.get(language, 'receipt_preview')),
        backgroundColor: const Color(0xFF1E2444),
        foregroundColor: Colors.white,
      ),
      body: PdfPreview(
        // ฟังก์ชันสร้าง PDF
        build: (format) => _generatePdf(format, language),
        // ตั้งค่ากระดาษเริ่มต้นเป็นแบบใบเสร็จ (Roll 80mm)
        initialPageFormat: PdfPageFormat.roll80, 
        canChangePageFormat: false, // ห้ามเปลี่ยนขนาดกระดาษ
        canDebug: false,
      ),
    );
  }

  Future<Uint8List> _generatePdf(PdfPageFormat format, String language) async {
    final doc = pw.Document();
    final currencyFormat = NumberFormat("#,##0", "en_US");
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    String tr(String key) => AppTranslations.get(language, key);

    // 1. โหลดฟอนต์ภาษาไทย (จำเป็นมาก ไม่งั้นจะเป็นสี่เหลี่ยม)
    // ใช้ Sarabun จาก Google Fonts เพราะอ่านง่ายและรองรับไทยครบ
    final font = await PdfGoogleFonts.sarabunRegular();
    final fontBold = await PdfGoogleFonts.sarabunBold();

    // 2. สร้างหน้า PDF ตามจำนวนสำเนา (copies)
    for (int i = 0; i < copies; i++) {
      doc.addPage(
        pw.Page(
          pageFormat: format,
          margin: const pw.EdgeInsets.all(10), // ขอบกระดาษ
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // --- Header ---
                pw.Center(
                  child: pw.Text(storeName, style: pw.TextStyle(font: fontBold, fontSize: 18)),
                ),
                pw.SizedBox(height: 5),
                pw.Center(
                  child: pw.Text(tr('receipt_header'), style: pw.TextStyle(font: font, fontSize: 12)),
                ),
                pw.Divider(),
                
                // --- Order Info ---
                pw.Text("${tr('bill_no')}: ${orderData['orderId'] ?? '-'}", style: pw.TextStyle(font: font, fontSize: 10)),
                pw.Text("${tr('date')}: ${dateFormat.format(DateTime.now())}", style: pw.TextStyle(font: font, fontSize: 10)),
                pw.Divider(),

                // --- Items ---
                ...items.map((item) {
                  return pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Text(item['name'], style: pw.TextStyle(font: font, fontSize: 10)),
                      ),
                      pw.SizedBox(width: 10),
                      pw.Text("x${item['quantity']}", style: pw.TextStyle(font: font, fontSize: 10)),
                      pw.SizedBox(width: 20),
                      pw.Text(
                        "${currencyFormat.format(item['price'] * item['quantity'])}",
                        style: pw.TextStyle(font: font, fontSize: 10),
                      ),
                    ],
                  );
                }).toList(),

                pw.Divider(),

                // --- Totals ---
                _buildPdfRow(tr('total'), "${currencyFormat.format(totalAmount)} LAK", fontBold),
                
                if (cashReceived > 0) ...[
                   pw.SizedBox(height: 2),
                  _buildPdfRow(tr('receive_cash'), "${currencyFormat.format(cashReceived)} LAK", font),
                  _buildPdfRow(tr('change'), "${currencyFormat.format(change)} LAK", font),
                ] else ...[
                   pw.SizedBox(height: 2),
                  _buildPdfRow(tr('paid_by'), "QR Code", font),
                ],

                pw.SizedBox(height: 10),
                pw.Divider(borderStyle: pw.BorderStyle.dashed),
                pw.SizedBox(height: 5),
                
                // --- Footer ---
                pw.Center(
                  child: pw.Text(tr('thank_you'), style: pw.TextStyle(font: font, fontSize: 10)),
                ),
                pw.Center(
                  child: pw.Text(tr('wirex_pos'), style: pw.TextStyle(font: fontBold, fontSize: 12)),
                ),
                // ถ้าเป็นสำเนาให้บอกด้วย
                if (i > 0) 
                  pw.Center(
                    child: pw.Text("*** ${tr('copy')} (${i+1}) ***", style: pw.TextStyle(font: font, fontSize: 8)),
                  ),
              ],
            );
          },
        ),
      );
    }

    return doc.save();
  }

  // Helper สร้างแถวใน PDF
  pw.Widget _buildPdfRow(String label, String value, pw.Font font) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(font: font, fontSize: 10)),
        pw.Text(value, style: pw.TextStyle(font: font, fontSize: 10)),
      ],
    );
  }
}
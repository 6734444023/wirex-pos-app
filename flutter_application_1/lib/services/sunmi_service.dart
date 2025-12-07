import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';
import 'package:intl/intl.dart';
import '../l10n/app_translations.dart';

class SunmiService {
  // ฟังก์ชันเริ่มต้นการเชื่อมต่อเครื่องพิมพ์
  static Future<void> initPrinter() async {
    try {
      await SunmiPrinter.bindingPrinter();
    } catch (e) {
      print("Error binding printer: $e");
    }
  }

  // ฟังก์ชันพิมพ์ใบเสร็จ
  static Future<void> printReceipt({
    required String storeName,
    required String orderId,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required double cashReceived,
    required double change,
    String paymentMethod = 'cash',
    String language = 'TH', // ค่าเริ่มต้นเป็น TH
  }) async {
    final currencyFormat = NumberFormat("#,##0", "en_US");
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    String tr(String key) => AppTranslations.get(language, key);

    // 1. เริ่มการพิมพ์
    await SunmiPrinter.initPrinter();
    await SunmiPrinter.startTransactionPrint(true);

    // 2. ส่วนหัว (Header)
    await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
    // ปรับขนาดตัวอักษรชื่อร้านให้พอดี (24) และตัวหนา
    await SunmiPrinter.printText(storeName,
        style: SunmiTextStyle(fontSize: 24, bold: true));
    await SunmiPrinter.printText(tr('receipt_header'));
    await SunmiPrinter.lineWrap(1);

    await SunmiPrinter.setAlignment(SunmiPrintAlign.LEFT);
    await SunmiPrinter.printText('${tr('bill_no')}: $orderId');
    await SunmiPrinter.printText('${tr('date')}: ${dateFormat.format(DateTime.now())}');
    await SunmiPrinter.lineWrap(1);
    await SunmiPrinter.printText('--------------------------------');

    // 3. รายการสินค้า (Items) - ปรับ Layout ใหม่
    for (var item in items) {
      String name = item['name'];
      int qty = item['quantity'];
      double price = (item['price'] as num).toDouble();
      double total = price * qty;

      // พิมพ์ชื่อสินค้าไว้บรรทัดบน (ตัวหนา) เพื่อป้องกันชื่อยาวตกขอบ
      await SunmiPrinter.printText(name, style: SunmiTextStyle(bold: true));
      
      // พิมพ์ จำนวน และ ราคา ไว้บรรทัดล่าง (แบ่งคอลัมน์ซ้าย-ขวา)
      // ปรับความกว้างเป็น 5:7 เพื่อให้พื้นที่แสดงราคาเยอะขึ้น
      await SunmiPrinter.printRow(cols: [
        SunmiColumn(
          text: '${qty}x ${currencyFormat.format(price)}', 
          width: 5, 
          style: SunmiTextStyle(align: SunmiPrintAlign.LEFT)
        ),
        SunmiColumn(
          text: '${currencyFormat.format(total)}', 
          width: 7, 
          style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT)
        ),
      ]);
    }

    await SunmiPrinter.printText('--------------------------------');

    // 4. สรุปยอด (Total)
    await SunmiPrinter.printRow(cols: [
      SunmiColumn(
        text: tr('total'), 
        width: 5, 
        style: SunmiTextStyle(bold: true, align: SunmiPrintAlign.LEFT)
      ),
      SunmiColumn(
        text: '${currencyFormat.format(totalAmount)} LAK', 
        width: 7, 
        style: SunmiTextStyle(bold: true, align: SunmiPrintAlign.RIGHT)
      ),
    ]);

    if (paymentMethod == 'cash') {
      await SunmiPrinter.printRow(cols: [
        SunmiColumn(text: tr('cash'), width: 5, style: SunmiTextStyle(align: SunmiPrintAlign.LEFT)),
        SunmiColumn(text: '${currencyFormat.format(cashReceived)}', width: 7, style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT)),
      ]);
      await SunmiPrinter.printRow(cols: [
        SunmiColumn(text: tr('change'), width: 5, style: SunmiTextStyle(align: SunmiPrintAlign.LEFT)),
        SunmiColumn(text: '${currencyFormat.format(change)}', width: 7, style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT)),
      ]);
    } else {
      await SunmiPrinter.lineWrap(1);
      await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
      await SunmiPrinter.printText('[ ${tr('paid_by_qr')} ]', style: SunmiTextStyle(bold: true));
    }

    await SunmiPrinter.lineWrap(2);

    // 5. ส่วนท้าย (Footer)
    await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
    await SunmiPrinter.printText(tr('thank_you'));
    // ชื่อแอปตัวหนา (ลบขนาด 20 ที่อาจจะใหญ่ไปออก หรือปรับลดลงถ้าต้องการ)
    await SunmiPrinter.printText(tr('wirex_pos'), style: SunmiTextStyle(bold: true));
    
    // 6. จบการพิมพ์และเลื่อนกระดาษ (Feed)
    await SunmiPrinter.lineWrap(3); 
    await SunmiPrinter.exitTransactionPrint(true);
  }
}
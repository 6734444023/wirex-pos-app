import 'package:flutter/material.dart';
import 'app_drawer.dart'; // ✅ Import AppDrawer ที่จะสร้างขึ้นมา
import 'restaurant_menu_page.dart';
import 'shop_page.dart';
import 'gas_station_page.dart';
import 'manual_payment_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    const Color darkBlue = Color(0xFF1E2444);
    const Color lightBlue = Color(0xFFE2E6FF); // สีฟ้าอ่อนสำหรับปุ่ม 'ชำระโดยไม่เลือกเมนู'

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        // เปลี่ยน title เป็น "เลือกประเภท" ตามรูป
        title: const Text(
          'เลือกประเภท',
          style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0, // ไม่มีเงา
        iconTheme: const IconThemeData(color: darkBlue), // สีไอคอน Hamburger
      ),
      drawer: const AppDrawer(), // ✅ ใส่ Drawer เข้าไปตรงนี้
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Grid ของปุ่มเลือกประเภท
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2, // 2 คอลัมน์
                  crossAxisSpacing: 16.0,
                  mainAxisSpacing: 16.0,
                  children: [
                    // ปุ่ม "ร้านอาหาร"
                    _buildCategoryButton(
                      context,
                      icon: Icons.restaurant,
                      label: 'ร้านอาหาร',
                      color: darkBlue,
                      onTap: () {
                        print('ร้านอาหาร tapped');
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RestaurantMenuPage(),
                          ),
                        );
                      },
                    ),
                    // ปุ่ม "ร้านขายของ"
                    _buildCategoryButton(
                      context,
                      icon: Icons.store,
                      label: 'ร้านขายของ',
                      color: darkBlue,
                      onTap: () {
                        print('ร้านขายของ tapped');
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ShopPage(),
                          ),
                        );
                      },
                    ),
                    // ปุ่ม "ปั๊มน้ำมัน"
                    _buildCategoryButton(
                      context,
                      icon: Icons.local_gas_station,
                      label: 'ปั๊มน้ำมัน',
                      color: darkBlue,
                      onTap: () {
                        print('ปั๊มน้ำมัน tapped');
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const GasStationPage(),
                          ),
                        );
                      },
                    ),
                    // ปุ่ม "ชำระโดยไม่เลือกเมนู" (สีต่างจากเพื่อน)
                    _buildCategoryButton(
                      context,
                      icon: Icons.qr_code_2,
                      label: 'ชำระโดยไม่เลือกเมนู',
                      color: lightBlue, // สีฟ้าอ่อน
                      iconColor: darkBlue, // สีไอคอน
                      labelColor: darkBlue, // สีตัวหนังสือ
                      onTap: () {
                        print('ชำระโดยไม่เลือกเมนู tapped');
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ManualPaymentPage(),
                          ),
                        );  
                      },
                    ),
                  ],
                ),
              ),
              // Logo และ Call Center ด้านล่าง
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: darkBlue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.qr_code, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "WireX Portable POS",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: darkBlue,
                          fontFamily: 'Serif',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Call center : 02077222099",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper function สำหรับสร้างปุ่มประเภท
  Widget _buildCategoryButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    Color iconColor = Colors.white,
    Color labelColor = Colors.white,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 3), // changes position of shadow
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 60,
              color: iconColor,
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: labelColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'login_page.dart'; // สำหรับกลับไปหน้า Login เมื่อ Logout
import 'settings_page.dart';
import 'transaction_history_page.dart';
import 'reports_page.dart';
import 'l10n/app_translations.dart';
import 'providers/language_provider.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  // ฟังก์ชัน Logout
  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil( // ใช้ pushAndRemoveUntil เพื่อเคลียร์ Stack หน้าเก่าๆ
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (Route<dynamic> route) => false, // ลบทุกหน้าใน Stack
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context).selectedLanguage;
    String tr(String key) => AppTranslations.get(lang, key);
    const Color darkBlue = Color(0xFF1E2444);

    return Drawer(
      child: Container(
        color: darkBlue, // พื้นหลัง Drawer เป็นสีน้ำเงินเข้ม
        child: Column(
          children: [
            // ส่วน Header ของ Drawer (โลโก้และชื่อ WireX)
            DrawerHeader(
              decoration: const BoxDecoration(
                // สามารถเพิ่มรูปพื้นหลังตรงนี้ได้ ถ้ามี
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                     Container(
  width: 60,
  height: 60,
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.zero,
    image: const DecorationImage(
      image: NetworkImage(
        'https://firebasestorage.googleapis.com/v0/b/wirexmenu-2fd27.firebasestorage.app/o/logo%2FmessageImage_1763726179957.jpg?alt=media',
      ),
      fit: BoxFit.cover,
    ),
  ),
),
const SizedBox(width: 16),

// 🔥 แก้ตรงนี้: เอา Expanded มาครอบ Text ไว้ครับ
Expanded( 
  child: Text(
    tr('wirex_pos'),
    style: const TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
    overflow: TextOverflow.ellipsis, // เพิ่มบรรทัดนี้: ถ้าล้นให้แสดง ... แทน
    // หรือถ้าอยากให้ขึ้นบรรทัดใหม่ ให้ลบ overflow ออก แล้วใส่ maxLines: 2 แทน
  ),
),
          
                    ],
                  ),
                ],
              ),
            ),
            
            // รายการเมนู
            _buildDrawerItem(context, Icons.home, tr('home'), () {
              Navigator.pop(context); // ปิด Drawer
              // TODO: ถ้าอยู่หน้า Dashboard อยู่แล้ว ก็ไม่ต้องทำอะไร
            }),
            _buildDrawerItem(context, Icons.history, tr('transaction_history'), () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TransactionHistoryPage()),
              );
            }),
            _buildDrawerItem(context, Icons.analytics, tr('reports'), () {
              print('ไปหน้ารายงาน');
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ReportsPage()),
              );
            }),
       
            _buildDrawerItem(context, Icons.settings, tr('settings'), () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            }),

            const Spacer(), // ใช้ Spacer เพื่อดันปุ่ม Logout ลงล่างสุด

            // ปุ่ม "ออกจากระบบ"
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => _signOut(context),
                  icon: const Icon(Icons.logout, color: darkBlue),
                  label: Text(
                    tr('logout'),
                    style: const TextStyle(color: darkBlue, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white, // ปุ่มสีขาว
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20), // เพิ่มระยะห่างด้านล่าง
          ],
        ),
      ),
    );
  }

  // Helper function สำหรับสร้างรายการเมนูใน Drawer
  Widget _buildDrawerItem(BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70), // ไอคอนสีขาวจางๆ
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 16), // ตัวหนังสือสีขาว
      ),
      onTap: onTap,
    );
  }
}
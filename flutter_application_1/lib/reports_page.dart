import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'l10n/app_translations.dart';
import 'providers/language_provider.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final Color darkBlue = const Color(0xFF1E2444);
  final currencyFormat = NumberFormat("#,##0.##", "en_US");
  
  String _paymentMode = "combined";
  double _feePercentage = 5.0;
  double _totalSales = 0.0;
  int _totalOrders = 0;
  double _totalFee = 0.0;
  double _totalDiscount = 0.0;
  double _totalCancelled = 0.0;
  bool _isLoading = true;
  
  // ตัวกรอง
  String _filterType = 'day'; // day, month, year
  DateTime _selectedDate = DateTime.now();
  
  // ข้อมูลกราฟ
  List<Map<String, dynamic>> _chartData = [];
  Map<String, int> _topProducts = {};

  String tr(String key) {
    final lang = Provider.of<LanguageProvider>(context, listen: false).selectedLanguage;
    return AppTranslations.get(lang, key);
  }

  @override
  void initState() {
    super.initState();
    _fetchReportData();
  }

  // คำนวณช่วงเวลาตามประเภทตัวกรอง
  Map<String, DateTime> _getDateRange() {
    DateTime start, end;
    final now = _selectedDate;
    
    switch (_filterType) {
      case 'day':
        start = DateTime(now.year, now.month, now.day);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'month':
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
      case 'year':
        start = DateTime(now.year, 1, 1);
        end = DateTime(now.year, 12, 31, 23, 59, 59);
        break;
      default:
        start = DateTime(now.year, now.month, now.day);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    }
    return {'start': start, 'end': end};
  }

  Future<void> _fetchReportData() async {
    setState(() => _isLoading = true);
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      final mode = userData?['paymentMode'] ?? 'combined';
      final feePercent = (userData?['feePercentage'] ?? 5).toDouble();

      final dateRange = _getDateRange();
      final startDate = dateRange['start']!;
      final endDate = dateRange['end']!;

      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('transactions') 
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      double sales = 0;
      int orders = 0;
      double fee = 0;
      double discount = 0;
      double cancelled = 0;
      Map<String, double> chartMap = {};
      Map<String, int> productCount = {};

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final status = data['status'] as String?;
        final amount = (data['amount'] ?? data['totalAmount'] ?? 0).toDouble();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        
        // จัดกลุ่มข้อมูลสำหรับกราฟ
        String chartKey;
        switch (_filterType) {
          case 'day':
            chartKey = DateFormat('HH:00').format(createdAt);
            break;
          case 'month':
            chartKey = DateFormat('dd').format(createdAt);
            break;
          case 'year':
            chartKey = DateFormat('MMM').format(createdAt);
            break;
          default:
            chartKey = DateFormat('HH:00').format(createdAt);
        }
        
        if (status == 'paid') {
          sales += amount;
          orders++;
          chartMap[chartKey] = (chartMap[chartKey] ?? 0) + amount;
          
          // นับสินค้าขายดี
          final items = data['items'] as List<dynamic>? ?? [];
          for (var item in items) {
            final name = item['name'] as String? ?? 'Unknown';
            final qty = (item['quantity'] ?? 1) as int;
            productCount[name] = (productCount[name] ?? 0) + qty;
          }
          
          // ส่วนลด
          final itemDiscount = (data['discount'] ?? 0).toDouble();
          discount += itemDiscount;
          
          if (mode == 'combined') {
            fee += amount * (feePercent / 100.0);
          }
        } else if (status == 'cancelled') {
          cancelled += amount;
        }
      }

      if (mode == 'step') {
        double feePerTrans = _calculateStepFeeRate(sales);
        fee = orders * feePerTrans;
      }

      // แปลง Map เป็น List สำหรับกราฟ
      List<Map<String, dynamic>> chartDataList = [];
      chartMap.forEach((key, value) {
        chartDataList.add({'label': key, 'value': value});
      });
      
      // เรียงลำดับตาม label
      chartDataList.sort((a, b) => a['label'].compareTo(b['label']));
      
      // เรียงสินค้าขายดี
      var sortedProducts = productCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      Map<String, int> topProducts = Map.fromEntries(sortedProducts.take(5));

      if (mounted) {
        setState(() {
          _paymentMode = mode;
          _feePercentage = feePercent;
          _totalSales = sales;
          _totalOrders = orders;
          _totalFee = fee;
          _totalDiscount = discount;
          _totalCancelled = cancelled;
          _chartData = chartDataList;
          _topProducts = topProducts;
          _isLoading = false;
        });
      }

    } catch (e) {
      print("Error fetching report: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double _calculateStepFeeRate(double totalSales) {
    if (totalSales <= 2000000) return 1000;
    if (totalSales <= 3000000) return 1500;
    if (totalSales <= 4000000) return 2500;
    if (totalSales <= 5000000) return 3000;
    if (totalSales <= 7000000) return 4500;
    if (totalSales <= 10000000) return 7500;
    if (totalSales <= 30000000) return 12000;
    if (totalSales <= 50000000) return 15500;
    if (totalSales <= 100000000) return 20000;
    if (totalSales <= 120000000) return 25000;
    if (totalSales <= 150000000) return 30000;
    return 40000;
  }

  void _showDateFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    tr('date_filter'),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // ปุ่มเลือกประเภท
              Row(
                children: [
                  _buildFilterChip(tr('daily'), 'day', setModalState),
                  const SizedBox(width: 10),
                  _buildFilterChip(tr('monthly'), 'month', setModalState),
                  const SizedBox(width: 10),
                  _buildFilterChip(tr('yearly'), 'year', setModalState),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // แสดงวันที่เลือก
              InkWell(
                onTap: () async {
                  DateTime? picked;
                  if (_filterType == 'day') {
                    picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                  } else if (_filterType == 'month') {
                    picked = await _showMonthPicker(context);
                  } else {
                    picked = await _showYearPicker(context);
                  }
                  
                  if (picked != null) {
                    setModalState(() => _selectedDate = picked!);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _getFormattedDate(),
                        style: TextStyle(fontSize: 16, color: darkBlue),
                      ),
                      Icon(Icons.calendar_today, color: darkBlue),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // ปุ่มยืนยัน
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _fetchReportData();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: darkBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(tr('confirm'), style: const TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, StateSetter setModalState) {
    final isSelected = _filterType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setModalState(() => _filterType = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? darkBlue : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : darkBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getFormattedDate() {
    switch (_filterType) {
      case 'day':
        return DateFormat('dd MMMM yyyy').format(_selectedDate);
      case 'month':
        return DateFormat('MMMM yyyy').format(_selectedDate);
      case 'year':
        return DateFormat('yyyy').format(_selectedDate);
      default:
        return DateFormat('dd MMMM yyyy').format(_selectedDate);
    }
  }

  Future<DateTime?> _showMonthPicker(BuildContext context) async {
    int selectedYear = _selectedDate.year;
    int selectedMonth = _selectedDate.month;
    
    return showDialog<DateTime>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('select_month')),
        content: SizedBox(
          width: 300,
          height: 300,
          child: Column(
            children: [
              DropdownButton<int>(
                value: selectedYear,
                items: List.generate(5, (i) => DateTime.now().year - i)
                    .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                    .toList(),
                onChanged: (val) => selectedYear = val ?? selectedYear,
              ),
              const SizedBox(height: 10),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 3,
                  children: List.generate(12, (i) {
                    final month = i + 1;
                    return InkWell(
                      onTap: () => Navigator.pop(context, DateTime(selectedYear, month)),
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: month == selectedMonth ? darkBlue : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            DateFormat('MMM').format(DateTime(2000, month)),
                            style: TextStyle(
                              color: month == selectedMonth ? Colors.white : darkBlue,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<DateTime?> _showYearPicker(BuildContext context) async {
    return showDialog<DateTime>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('select_year')),
        content: SizedBox(
          width: 200,
          height: 300,
          child: ListView(
            children: List.generate(10, (i) => DateTime.now().year - i)
                .map((year) => ListTile(
                      title: Text('$year'),
                      onTap: () => Navigator.pop(context, DateTime(year)),
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: darkBlue),
        centerTitle: true,
        title: Text(tr('sales_report'), style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ตัวกรองวันที่
                  _buildDateFilterSection(),
                  
                  // ส่วนสรุป (ขยายได้)
                  _buildSummarySection(),
                  
                  // กราฟ
                  _buildChartSection(),
                  
                  // สถิติยอดขาย
                  _buildStatsSection(),
                  
                  // สินค้าขายดี
                  _buildTopProductsSection(),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildDateFilterSection() {
    return InkWell(
      onTap: _showDateFilterSheet,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5)],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.filter_list, color: darkBlue),
                const SizedBox(width: 10),
                Text(tr('date_filter'), style: TextStyle(color: darkBlue, fontWeight: FontWeight.w500)),
              ],
            ),
            Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5)],
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(tr('summary'), style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                // แถวแรก: จำนวนรายการ
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: darkBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$_totalOrders ${tr('items')}',
                        style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // กราฟ
          SizedBox(
            height: 200,
            child: _chartData.isEmpty
                ? Center(child: Text(tr('no_data'), style: TextStyle(color: Colors.grey)))
                : CustomPaint(
                    size: Size(double.infinity, 200),
                    painter: AreaChartPainter(
                      data: _chartData,
                      lineColor: darkBlue,
                      fillColor: darkBlue.withOpacity(0.2),
                    ),
                  ),
          ),
          
          const SizedBox(height: 10),
          
          // X-axis labels
          if (_chartData.isNotEmpty)
            SizedBox(
              height: 30,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _getXAxisLabels(),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _getXAxisLabels() {
    if (_chartData.isEmpty) return [];
    
    // แสดงเฉพาะบางป้ายชื่อเพื่อไม่ให้แน่น
    int step = (_chartData.length / 7).ceil();
    if (step < 1) step = 1;
    
    List<Widget> labels = [];
    for (int i = 0; i < _chartData.length; i += step) {
      labels.add(
        Text(
          _chartData[i]['label'],
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
      );
    }
    return labels;
  }

  Widget _buildStatsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildStatCard(tr('total_sales'), '${currencyFormat.format(_totalSales)} LAK', darkBlue)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard(tr('fee'), '${currencyFormat.format(_totalFee)} LAK', Colors.orange)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatCard(tr('discount'), '${currencyFormat.format(_totalDiscount)} LAK', Colors.green)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard(tr('cancelled'), '${currencyFormat.format(_totalCancelled)} LAK', Colors.red)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProductsSection() {
    if (_topProducts.isEmpty) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('top_products'),
            style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          ..._topProducts.entries.map((entry) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    entry.key,
                    style: TextStyle(color: darkBlue),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: darkBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${entry.value}',
                    style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

// Custom Painter สำหรับกราฟแบบ Area Chart
class AreaChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final Color lineColor;
  final Color fillColor;

  AreaChartPainter({
    required this.data,
    required this.lineColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final dotPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    // หาค่า max
    double maxValue = data.map((d) => (d['value'] as double)).reduce(max);
    if (maxValue == 0) maxValue = 1;

    // คำนวณจุด
    final points = <Offset>[];
    final spacing = size.width / (data.length - 1).clamp(1, double.infinity);
    
    for (int i = 0; i < data.length; i++) {
      final x = i * spacing;
      final y = size.height - ((data[i]['value'] as double) / maxValue * size.height * 0.9);
      points.add(Offset(x, y.clamp(10, size.height - 10)));
    }

    // วาด fill area
    final fillPath = Path();
    fillPath.moveTo(0, size.height);
    for (var point in points) {
      fillPath.lineTo(point.dx, point.dy);
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);

    // วาดเส้น
    final linePath = Path();
    linePath.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      // Smooth curve
      final p0 = points[i - 1];
      final p1 = points[i];
      final midX = (p0.dx + p1.dx) / 2;
      linePath.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
    }
    canvas.drawPath(linePath, paint);

    // วาดจุดที่ค่าสูงสุด
    double maxVal = 0;
    int maxIndex = 0;
    for (int i = 0; i < data.length; i++) {
      if ((data[i]['value'] as double) > maxVal) {
        maxVal = data[i]['value'] as double;
        maxIndex = i;
      }
    }
    
    if (points.isNotEmpty && maxIndex < points.length) {
      canvas.drawCircle(points[maxIndex], 6, dotPaint);
      canvas.drawCircle(points[maxIndex], 4, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
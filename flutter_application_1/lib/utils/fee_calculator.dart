class FeeCalculator {
  // คำนวณค่าธรรมเนียมแบบ Step ตามตาราง
  static double calculateStepFee(double monthlyTotalSales) {
    if (monthlyTotalSales <= 2000000) return 1000;
    if (monthlyTotalSales <= 3000000) return 1500;
    if (monthlyTotalSales <= 4000000) return 2500;
    if (monthlyTotalSales <= 5000000) return 3000;
    if (monthlyTotalSales <= 7000000) return 4500;
    if (monthlyTotalSales <= 10000000) return 7500;
    if (monthlyTotalSales <= 30000000) return 12000;
    if (monthlyTotalSales <= 50000000) return 15500;
    if (monthlyTotalSales <= 100000000) return 20000;
    if (monthlyTotalSales <= 120000000) return 25000;
    if (monthlyTotalSales <= 150000000) return 30000;
    // เกิน 150 ล้าน (ในรูปสุดท้ายคือ 200 ล้าน แต่สมมติว่าเกินนี้คิดเรทสูงสุด)
    return 40000; 
  }
}
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class ChartPage extends StatelessWidget {
  const ChartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEF6FF),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            color: const Color(0xFF724E99),
            padding: const EdgeInsets.all(16),
            child: const Text(
              'Chart by Expenses',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 16),

          // Pie Chart
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        height: 280,
                        child: PieChart(
                          PieChartData(
                            centerSpaceRadius: 70,
                            sectionsSpace: 2,
                            centerSpaceColor: Colors.white,
                            sections: [
                              PieChartSectionData(
                                color: const Color(0xFFFF1744),
                                value: 43,
                                title: '43%',
                                titleStyle: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              PieChartSectionData(
                                color: const Color(0xFF2979FF),
                                value: 30,
                                title: '30%',
                                titleStyle: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              PieChartSectionData(
                                color: const Color(0xFFFFEA00),
                                value: 12,
                                title: '12%',
                                titleStyle: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              PieChartSectionData(
                                color: const Color(0xFF00E676),
                                value: 6,
                                title: '6%',
                                titleStyle: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              PieChartSectionData(
                                color: const Color(0xFFD500F9),
                                value: 5,
                                title: '5%',
                                titleStyle: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              PieChartSectionData(
                                color: const Color(0xFF00BCD4),
                                value: 4,
                                title: '4%',
                                titleStyle: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Text(
                        'Rp 1.800.000',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Legend Box
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: const [
                        ChartLegendItem('Food', 43, 'Rp 774.000', Color(0xFFFF1744)),
                        ChartLegendItem('Shopping', 30, 'Rp 540.000', Color(0xFF2979FF)),
                        ChartLegendItem('Clothing', 12, 'Rp 216.000', Color(0xFFFFEA00)),
                        ChartLegendItem('Hangout', 6, 'Rp 108.000', Color(0xFF00E676)),
                        ChartLegendItem('Laundry', 5, 'Rp 90.000', Color(0xFFD500F9)),
                        ChartLegendItem('Water', 4, 'Rp 72.000', Color(0xFF00BCD4)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF724E99),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        iconSize: 28,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart_rounded),
            label: 'Chart',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money_rounded),
            label: 'Add',
          ),
        ],
        currentIndex: 1,
        onTap: (index) {
         if (index == 0) {
          Navigator.pushNamed(context, '/');
        } else if (index == 1) {
          Navigator.pushNamed(context, '/chart_page');
        } else if (index == 2) {
          Navigator.pushNamed(context, '/budget_page');
        }
      },
      ),
    );
  }
}

class ChartLegendItem extends StatelessWidget {
  final String label;
  final int percent;
  final String amount;
  final Color color;

  const ChartLegendItem(this.label, this.percent, this.amount, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(radius: 6, backgroundColor: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '$percent%',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 12),
          Text(amount, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}

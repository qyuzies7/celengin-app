import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HomeYearPage extends StatefulWidget {
  @override
  _HomeYearPageState createState() => _HomeYearPageState();
}

class _HomeYearPageState extends State<HomeYearPage> {
  int currentYear = DateTime.now().year;

  final List<Map<String, dynamic>> allTransactions = [
    {'title': 'Transport', 'date': DateTime(2025, 5, 2), 'amount': -600000, 'icon': Icons.directions_bus},
    {'title': 'Bills', 'date': DateTime(2025, 5, 5), 'amount': -2000000, 'icon': Icons.receipt},
    {'title': 'Food', 'date': DateTime(2024, 4, 7), 'amount': -40000, 'icon': Icons.fastfood},
    {'title': 'Shopping', 'date': DateTime(2025, 4, 6), 'amount': -110000, 'icon': Icons.shopping_cart},
  ];

  void _navigateYear(int direction) {
    setState(() {
      currentYear += direction;
    });
  }

  void _onTabSelected(String type) {
    if (type == 'weekly') {
      Navigator.pushNamed(context, '/home');
    } else if (type == 'monthly') {
      Navigator.pushNamed(context, '/home_month');
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> currentTransactions = allTransactions
        .where((tx) => tx['date'].year == currentYear)
        .toList();

    return Scaffold(
      backgroundColor: Color(0xFFFEF6FF),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Container(
              decoration: BoxDecoration(
                color: Color(0xFF724E99),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Arrow & Year
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        IconButton(
                          icon: Icon(Icons.chevron_left, color: Colors.white),
                          onPressed: () => _navigateYear(-1),
                        ),
                        Text(
                          currentYear.toString(),
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        IconButton(
                          icon: Icon(Icons.chevron_right, color: Colors.white),
                          onPressed: () => _navigateYear(1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildSummaryCard('income', '25.000.000', Colors.green),
                          _buildSummaryCard('outcome', '9.000.000', Colors.red),
                          _buildSummaryCard('total', '16.000.000', Colors.green),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildTab('weekly', false, () => _onTabSelected('weekly')),
                  const SizedBox(width: 8),
                  _buildTab('monthly', false, () => _onTabSelected('monthly')),
                  const SizedBox(width: 8),
                  _buildTab('yearly', true, () {}),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Transactions or Empty
            currentTransactions.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 32),
                    child: Column(
                      children: [
                        SvgPicture.asset('assets/empty2.svg', height: 150),
                        SizedBox(height: 12),
                        Text(
                          'No transactions for this year',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: currentTransactions.map((tx) {
                      return _buildTransactionItem(
                        tx['title'],
                        '${tx['date'].day}/${tx['date'].month}/${tx['date'].year}',
                        '-Rp ${tx['amount'].abs().toStringAsFixed(0)}',
                        tx['icon'],
                      );
                    }).toList(),
                  ),

            const SizedBox(height: 80),
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/add_page');
        },
        backgroundColor: Color(0xFF724E99),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Icon(Icons.add_rounded, color: Colors.white, size: 40),
      ),

      bottomNavigationBar: BottomAppBar(
        shape: CircularNotchedRectangle(),
        notchMargin: 6.0,
        color: Color(0xFF724E99),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBottomNavItem(Icons.home, 0),
              _buildBottomNavItem(Icons.pie_chart_rounded, 1),
              _buildBottomNavItem(Icons.attach_money_rounded, 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String amount, Color color) {
    return Column(
      children: [
        Text(title, style: TextStyle(fontSize: 12, color: Colors.black54)),
        SizedBox(height: 8),
        Text(amount, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
      ],
    );
  }

  Widget _buildTab(String title, bool isSelected, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Color(0xFF724E99) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Color(0xFF724E99)),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 12,
              color: isSelected ? Colors.white : Color(0xFF724E99),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionItem(String title, String date, String amount, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.deepPurple[100],
              child: Icon(icon, color: Color(0xFF724E99)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(date, style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            Text(amount, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.red)),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(IconData icon, int index) {
    return IconButton(
      iconSize: 30,
      icon: Icon(icon, color: index == 0 ? Color(0xFFD4B1F8) : Colors.white),
      onPressed: () {
        if (index == 0) {
          Navigator.pushNamed(context, '/home_page');
        } else if (index == 1) {
          Navigator.pushNamed(context, '/chart_page');
        } else if (index == 2) {
          Navigator.pushNamed(context, '/budget_page');
        }
      },
    );
  }
}

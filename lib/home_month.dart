import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class HomeMonthPage extends StatefulWidget {
  @override
  _HomeMonthPageState createState() => _HomeMonthPageState();
}

class _HomeMonthPageState extends State<HomeMonthPage> {
  DateTime currentMonth = DateTime.now();

  // Simulasi data transaksi bulanan
  final Map<String, List<Map<String, dynamic>>> monthlyTransactions = {
    '05-2025': [
      {'title': 'Transport', 'date': '2/5/2025', 'amount': -60000, 'icon': Icons.directions_bus},
      {'title': 'Bills', 'date': '5/5/2025', 'amount': -200000, 'icon': Icons.receipt},
      {'title': 'Salary', 'date': '1/5/2025', 'amount': 2500000, 'icon': Icons.work},
    ],
    '06-2025': [
      {'title': 'Transport', 'date': '3/6/2025', 'amount': -50000, 'icon': Icons.directions_bus},
      {'title': 'Salary', 'date': '2/6/2025', 'amount': 2600000, 'icon': Icons.work},
    ]
  };

  void _navigateMonth(int direction) {
    setState(() {
      currentMonth = DateTime(currentMonth.year, currentMonth.month + direction);
    });
  }

  void _onTabSelected(String type) {
    if (type == 'weekly') {
      Navigator.pushNamed(context, '/home');
    } else if (type == 'yearly') {
      Navigator.pushNamed(context, '/home_year');
    }
  }

  String get monthFormatted => '${currentMonth.month}/${currentMonth.year}';
  String get keyFormatted => '${currentMonth.month.toString().padLeft(2, '0')}-${currentMonth.year}';

  List<Map<String, dynamic>> get currentTransactions =>
      monthlyTransactions[keyFormatted] ?? [];

  double get income => currentTransactions
      .where((item) => item['amount'] > 0)
      .fold(0.0, (sum, item) => sum + item['amount']);

  double get outcome => currentTransactions
      .where((item) => item['amount'] < 0)
      .fold(0.0, (sum, item) => sum + item['amount'].abs());

  double get total => income - outcome;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFEF6FF),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Container(
              decoration: BoxDecoration(
                color: Color(0xFF724E99),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.chevron_left, color: Colors.white),
                          onPressed: () => _navigateMonth(-1),
                        ),
                        Text(
                          monthFormatted,
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        IconButton(
                          icon: Icon(Icons.chevron_right, color: Colors.white),
                          onPressed: () => _navigateMonth(1),
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
                          _buildSummaryCard('income', income, Colors.green),
                          _buildSummaryCard('outcome', outcome, Colors.red),
                          _buildSummaryCard('total', total, total >= 0 ? Colors.green : Colors.red),
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
                  _buildTab('monthly', true, () {}),
                  const SizedBox(width: 8),
                  _buildTab('yearly', false, () => _onTabSelected('yearly')),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Progress Indicator
            if (income > 0) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Rp ${total.toStringAsFixed(0)}',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: total / income,
                      backgroundColor: Colors.grey[300],
                      color: Color(0xFF724E99),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Outcome: Rp ${outcome.toStringAsFixed(0)}',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text('Remaining: Rp ${total.toStringAsFixed(0)}',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Transaction List
            if (currentTransactions.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 32),
                child: Column(
                  children: [
                    SvgPicture.asset('assets/empty2.svg', height: 150),
                    Text('No transactions for this month',
                    style: TextStyle(color: Colors.grey)),
                  ],
                ),
              )
            else
              Column(
                children: currentTransactions.map((tx) {
                  return _buildTransactionItem(
                    tx['title'],
                    tx['date'],
                    (tx['amount'] > 0 ? '+Rp ' : '-Rp ') +
                        tx['amount'].abs().toStringAsFixed(0),
                    tx['icon'],
                    tx['amount'] > 0 ? Colors.green : Colors.red,
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28.0),
        ),
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

  Widget _buildSummaryCard(String title, double amount, Color color) {
    return Column(
      children: [
        Text(title, style: TextStyle(fontSize: 12, color: Colors.black54)),
        SizedBox(height: 8),
        Text('Rp ${amount.toStringAsFixed(0)}',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
      ],
    );
  }

  Widget _buildTab(String title, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
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
    );
  }

  Widget _buildTransactionItem(String title, String date, String amount, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
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
            Text(amount, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(IconData icon, int index) {
    return IconButton(
      iconSize: 30,
      icon: Icon(icon,
          color: index == 0 ? Color(0xFFD4B1F8) : Colors.white),
      onPressed: () {
        if (index == 0) {
          Navigator.pushNamed(context, '/');
        } else if (index == 1) {
          Navigator.pushNamed(context, '/chart_page');
        } else if (index == 2) {
          Navigator.pushNamed(context, '/budget_page');
        }
      },
    );
  }
}

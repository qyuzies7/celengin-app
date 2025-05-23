import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DateTime startDate = DateTime(2025, 5, 11);
  int currentIndex = 0;

  final List<Map<String, dynamic>> transactions = [
    {'title': 'Food', 'date': DateTime(2025, 5, 12), 'amount': -40000.0},
    {'title': 'Shopping', 'date': DateTime(2025, 5, 13), 'amount': -110000.0},
    {'title': 'Salary', 'date': DateTime(2025, 5, 14), 'amount': 900000.0},
    {'title': 'Bonus', 'date': DateTime(2025, 5, 20), 'amount': 100000.0},
  ];

  void _navigateWeek(int direction) {
    setState(() {
      startDate = startDate.add(Duration(days: 7 * direction));
    });
  }

  void _onBottomNavTap(int index) {
    setState(() {
      currentIndex = index;
    });

    if (!mounted) return;

    if (index == 1) {
      Navigator.pushNamed(context, '/chart_page');
    } else if (index == 2) {
      Navigator.pushNamed(context, '/budget_page');
    }
  }

  void _onTabSelected(String type) {
    if (!mounted) return;

    if (type == 'monthly') {
      Navigator.pushNamed(context, '/home_month');
    } else if (type == 'yearly') {
      Navigator.pushNamed(context, '/home_year');
    }
  }

  String get startFormatted =>
      '${startDate.day}/${startDate.month}/${startDate.year}';

  String get endFormatted {
    final endDate = startDate.add(const Duration(days: 6));
    return '${endDate.day}/${endDate.month}/${endDate.year}';
  }

  List<Map<String, dynamic>> get currentWeekTransactions {
    final endDate = startDate.add(const Duration(days: 7));
    return transactions.where((tx) {
      final txDate = tx['date'] as DateTime;
      return txDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
          txDate.isBefore(endDate);
    }).toList();
  }

  double get income => currentWeekTransactions
      .where((tx) => tx['amount'] > 0)
      .fold(0.0, (sum, tx) => sum + tx['amount']);

  double get outcome => currentWeekTransactions
      .where((tx) => tx['amount'] < 0)
      .fold(0.0, (sum, tx) => sum + tx['amount'].abs());

  double get total => income - outcome;

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');
  }

  IconData _getIconForTitle(String title) {
    if (title.toLowerCase().contains('food')) return Icons.fastfood;
    if (title.toLowerCase().contains('shopping')) return Icons.shopping_cart;
    if (title.toLowerCase().contains('salary')) return Icons.attach_money;
    return Icons.category;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEF6FF),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Container(
              decoration: const BoxDecoration(
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
                    // Arrow & Date
                    Row(
                      children: [
                        IconButton(
                          icon:
                              const Icon(Icons.chevron_left, color: Colors.white),
                          onPressed: () => _navigateWeek(-1),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          children: [
                            Text(
                              startFormatted,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12),
                            ),
                            Text(
                              endFormatted,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon:
                              const Icon(Icons.chevron_right, color: Colors.white),
                          onPressed: () => _navigateWeek(1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildSummaryCard(
                              'income', _formatCurrency(income), Colors.green),
                          _buildSummaryCard(
                              'outcome', _formatCurrency(outcome), Colors.red),
                          _buildSummaryCard(
                              'total', _formatCurrency(total), Colors.green),
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
                  _buildTab('weekly', true, () {}),
                  const SizedBox(width: 8),
                  _buildTab('monthly', false, () => _onTabSelected('monthly')),
                  const SizedBox(width: 8),
                  _buildTab('yearly', false, () => _onTabSelected('yearly')),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rp ${_formatCurrency(total)}',
                    style:
                        const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: income == 0 ? 0 : (total / income).clamp(0.0, 1.0),
                    backgroundColor: Colors.grey[300],
                    color: const Color(0xFF724E99),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Outcome: ${_formatCurrency(outcome)}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      Text('Remaining: ${_formatCurrency(total)}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Transactions
            ...currentWeekTransactions.map((tx) => _buildTransactionItem(
                  tx['title'],
                  '${tx['date'].day}/${tx['date'].month}/${tx['date'].year}',
                  (tx['amount'] > 0 ? '+Rp ' : '-Rp ') +
                      _formatCurrency(tx['amount'].abs()),
                  _getIconForTitle(tx['title']),
                )),

            if (currentWeekTransactions.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 32),
                child: Column(
                  children: [
                    SvgPicture.asset('assets/empty2.svg', height: 150),
                    const Text('No transactions for this week',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),

      // FAB
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/add_page');
        },
        backgroundColor: const Color(0xFF724E99),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28.0),
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 40),
      ),

      // Bottom Navigation
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 6.0,
        color: const Color(0xFF724E99),
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
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 8),
        Text('Rp $amount',
            style:
                TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
      ],
    );
  }

  Widget _buildTab(String title, bool isSelected, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF724E99) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF724E99)),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 12,
              color: isSelected ? Colors.white : const Color(0xFF724E99),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionItem(
      String title, String date, String amount, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
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
              child: Icon(icon, color: const Color(0xFF724E99)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(date,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            Text(amount,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color:
                        amount.contains('-') ? Colors.red : Colors.green)),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(IconData icon, int index) {
    return IconButton(
      iconSize: 30,
      icon: Icon(icon,
          color:
              currentIndex == index ? const Color(0xFFD4B1F8) : Colors.white),
      onPressed: () => _onBottomNavTap(index),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

const apiBaseUrl = 'http://3.1.207.173/api';

class ChartPage extends StatefulWidget {
  const ChartPage({super.key});

  @override
  State<ChartPage> createState() => _ChartPageState();
}

class _ChartPageState extends State<ChartPage> {
  int currentYear = DateTime.now().year;
  List<Map<String, dynamic>> allTransactions = [];
  double continuedBalance = 0.0;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchTransactions();
    _loadContinuedBalance();
  }

  Future<void> _loadContinuedBalance() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      continuedBalance = prefs.getDouble('continued_balance_yearly_$currentYear') ?? _calculateContinuedBalance();
      debugPrint('Loaded continuedBalance for year $currentYear: $continuedBalance');
    });
  }

  double _calculateContinuedBalance() {
    final incomes = currentYearTransactions
        .where((tx) => tx['type'] == 'income' && tx['amount'] > 0)
        .fold(0.0, (sum, tx) => sum + tx['amount']);
    final expenses = currentYearTransactions
        .where((tx) => tx['type'] == 'outcome' && tx['amount'] < 0)
        .fold(0.0, (sum, tx) => sum + tx['amount'].abs());
    return (incomes - expenses);
  }

  Future<void> _saveContinuedBalance() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('continued_balance_yearly_$currentYear', continuedBalance);
  }

  Future<String?> getTokenFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> fetchTransactions() async {
    setState(() {
      isLoading = true;
    });
    try {
      final token = await getTokenFromStorage();
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sesi kadaluarsa, silakan login kembali')),
          );
        }
        return;
      }
      final response = await http.get(
        Uri.parse('$apiBaseUrl/transaksi'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> list = data is List ? data : data['transaksi'] ?? [];
        setState(() {
          allTransactions = list.map<Map<String, dynamic>>((item) {
            String? icon;
            String? categoryName;
            if (item['jenis'] == 'income' && item['income'] != null) {
              icon = item['income']['icon']?.toString();
              categoryName = item['income']['nama']?.toString() ?? 'Unknown';
            } else if (item['outcome'] != null) {
              icon = item['outcome']['icon']?.toString();
              categoryName = item['outcome']['nama']?.toString() ?? 'Unknown';
            }
            return {
              'id': item['id'],
              'title': categoryName ?? 'Unknown',
              'description': item['keterangan']?.toString() ?? '',
              'date': DateTime.tryParse(item['tanggal'].toString()) ?? DateTime.now(),
              'amount': double.tryParse(item['nominal'].toString()) ?? 0.0,
              'icon': icon ?? '',
              'type': item['jenis'],
            };
          }).toList();
          continuedBalance = _calculateContinuedBalance();
          _saveContinuedBalance();
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal memuat transaksi: ${response.statusCode}')),
          );
        }
        debugPrint('Failed to load transactions: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error memuat transaksi: $e')),
        );
      }
      debugPrint('Error fetching transactions: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _navigateYear(int direction) {
    setState(() {
      currentYear += direction;
    });
    fetchTransactions();
    _loadContinuedBalance();
  }

  List<Map<String, dynamic>> get currentYearTransactions {
    return allTransactions.where((tx) {
      final txDate = tx['date'] as DateTime;
      return txDate.year == currentYear;
    }).toList();
  }

  Map<String, double> getExpenseCategories() {
    final expenses = currentYearTransactions.where((tx) => tx['type'] == 'outcome' && tx['amount'] < 0).toList();
    final Map<String, double> categories = {};
    for (var tx in expenses) {
      final category = tx['title'] ?? 'Unknown';
      categories[category] = (categories[category] ?? 0.0) + tx['amount'].abs();
    }
    return categories;
  }

  double get totalExpenses {
    return currentYearTransactions
        .where((tx) => tx['type'] == 'outcome' && tx['amount'] < 0)
        .fold(0.0, (sum, tx) => sum + tx['amount'].abs());
  }

  String _formatCurrency(double amount) {
    return NumberFormat('#,##0', 'id_ID').format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final expenseCategories = getExpenseCategories();
    final hasExpenses = expenseCategories.isNotEmpty;
    final total = totalExpenses;

    final colors = [
      Colors.red,
      const Color(0xFF2979FF),
      const Color(0xFFFFEA00),
      const Color(0xFF00E676),
      const Color(0xFFD500F9),
      const Color(0xFF00BCD4),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFEF6FF),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            color: const Color(0xFF724E99),
            padding: const EdgeInsets.only(top: 63, bottom: 32, left: 16, right: 16),
            child: const Text(
              'Chart by Expenses',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Sisa Saldo dan Navigasi Tahun
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF724E99),
                        ),
                        child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Wallet',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              color: Color(0xFF724E99),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Rp ${_formatCurrency(continuedBalance)}',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 18,
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, color: Colors.black),
                        onPressed: () => _navigateYear(-1),
                      ),
                      Text(
                        currentYear.toString(),
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, color: Colors.black),
                        onPressed: () => _navigateYear(1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Pie Chart atau Pesan Jika Tidak Ada Transaksi
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  if (isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (!hasExpenses)
                    const Padding(
                      padding: EdgeInsets.only(top: 32),
                      child: Center(
                        child: Text(
                          'No expenses this year',
                          style: TextStyle(
                            color: Colors.grey,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    )
                  else
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
                              sections: expenseCategories.entries.map((entry) {
                                final index = expenseCategories.keys.toList().indexOf(entry.key);
                                final totalValue = expenseCategories.values.reduce((a, b) => a + b);
                                final percentage = (entry.value / totalValue * 100).round();
                                return PieChartSectionData(
                                  color: colors[index % colors.length],
                                  value: entry.value,
                                  title: '$percentage%',
                                  titleStyle: const TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        Text(
                          'Rp ${_formatCurrency(total)}',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 16),

                  // Legend Box
                  if (hasExpenses)
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
                        children: expenseCategories.entries.map((entry) {
                          final index = expenseCategories.keys.toList().indexOf(entry.key);
                          final totalValue = expenseCategories.values.reduce((a, b) => a + b);
                          final percentage = (entry.value / totalValue * 100).round();
                          return ChartLegendItem(
                            entry.key,
                            percentage,
                            'Rp ${_formatCurrency(entry.value)}',
                            colors[index % colors.length],
                          );
                        }).toList(),
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart_rounded),
            label: 'Chart',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Budgeting',
          ),
        ],
        currentIndex: 1,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushNamed(context, '/home');
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
            flex: 3,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '$percent%',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              amount,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontFamily: 'Poppins',
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:flutter_slidable/flutter_slidable.dart';

const apiBaseUrl = 'http://10.0.2.2:8000/api';

Future<String?> getTokenFromStorage() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('token');
}

class UserAvatarMenu extends StatelessWidget {
  final String? avatarPath;
  final VoidCallback? onSignOut;

  const UserAvatarMenu({super.key, this.avatarPath, this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: CircleAvatar(
        backgroundImage: avatarPath != null ? AssetImage(avatarPath!) : null,
        radius: 18,
        backgroundColor: Colors.deepPurple[200],
        child: avatarPath == null
            ? const Icon(Icons.person, size: 20, color: Colors.white)
            : null,
      ),
      onSelected: (value) async {
        if (value == 'signout' && onSignOut != null) {
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('token');
            if (context.mounted) {
              Navigator.pushReplacementNamed(context, '/login');
            }
          } catch (e) {
            if (context.mounted) {
              scaffoldMessenger.showSnackBar(
                SnackBar(content: Text('Gagal logout: $e')),
              );
            }
          }
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'signout',
          child: Row(
            children: [
              Icon(Icons.logout, color: Colors.black54, size: 20),
              SizedBox(width: 8),
              Text(
                'Sign Out',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 14),
              ),
            ],
          ),
        ),
      ],
      offset: const Offset(0, 40),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DateTime startDate = DateTime.now();
  int currentIndex = 0;
  String? avatarPath;
  double weeklyBudget = 0.0;
  List<Map<String, dynamic>> transactions = [];
  bool isLoading = false;
  double continuedBalance = 0.0;

  final List<String> avatarList = [
    'assets/avatars/avatar1.png',
    'assets/avatars/avatar2.png',
    'assets/avatars/avatar3.png',
    'assets/avatars/avatar4.png',
  ];

  @override
  void initState() {
    super.initState();
    _loadAvatar();
    fetchTransactions();
    fetchWeeklyBudget();
    _loadContinuedBalance();
  }

  Future<void> _loadContinuedBalance() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      continuedBalance = prefs.getDouble('continued_balance_weekly') ?? 0.0;
    });
  }

  Future<void> _saveContinuedBalance() async {
    final prefs = await SharedPreferences.getInstance();
    double previousBalance = prefs.getDouble('continued_balance_weekly') ?? 0.0;
    double newBalance = previousBalance + total;
    await prefs.setDouble('continued_balance_weekly', newBalance);
    await prefs.setDouble('continued_balance_monthly', newBalance);
    await prefs.setDouble('continued_balance_yearly', newBalance);
  }

  Future<void> fetchWeeklyBudget() async {
    final prefs = await SharedPreferences.getInstance();
    final now = startDate;
    final weekNumber = _getWeekNumber(now);
    final budgetKey = 'budget_weekly_${now.year}_$weekNumber';
    final cachedBudget = prefs.getInt(budgetKey);
    if (cachedBudget != null) {
      setState(() {
        weeklyBudget = cachedBudget.toDouble();
      });
    } else {
      setState(() {
        weeklyBudget = 0.0;
      });
    }

    final token = await getTokenFromStorage();
    if (token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sesi kadaluarsa, silakan login kembali')),
        );
      }
      return;
    }
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/plan'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> plans = jsonDecode(response.body);
        final plan = plans.firstWhere(
          (p) =>
              p['periode_type'] == 'weekly' &&
              _sameDate(DateTime.parse(p['periode_start']), weekStart) &&
              _sameDate(DateTime.parse(p['periode_end']), weekEnd),
          orElse: () => null,
        );
        final budgetValue = plan != null ? double.tryParse(plan['nominal'].toString()) ?? 0.0 : 0.0;
        setState(() {
          weeklyBudget = budgetValue;
          if (budgetValue > 0) {
            prefs.setInt(budgetKey, budgetValue.toInt());
          } else {
            prefs.remove(budgetKey);
          }
        });
      } else {
        debugPrint('Failed to load budget: ${response.statusCode}');
        setState(() {
          weeklyBudget = 0.0;
          prefs.remove(budgetKey);
        });
      }
    } catch (e) {
      debugPrint('Error fetching weekly budget: $e');
      setState(() {
        weeklyBudget = 0.0;
        prefs.remove(budgetKey);
      });
    }
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
        final now = startDate;
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 6));
        List<Map<String, dynamic>> weeklyTransactions = list.map<Map<String, dynamic>>((item) {
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
        }).where((tx) {
          final txDate = tx['date'] as DateTime;
          return txDate.isAfter(weekStart.subtract(const Duration(days: 1))) &&
              txDate.isBefore(weekEnd.add(const Duration(days: 1)));
        }).toList();

        setState(() {
          transactions = weeklyTransactions;
        });

        await _saveContinuedBalance();
        await fetchWeeklyBudget();
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

  Future<void> deleteTransaction(int id) async {
    try {
      final token = await getTokenFromStorage();
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sesi kadaluarsa, silakan login kembali')),
          );
          Navigator.pushReplacementNamed(context, '/login');
        }
        return;
      }
      final response = await http.delete(
        Uri.parse('$apiBaseUrl/transaksi/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transaksi berhasil dihapus')),
          );
          fetchTransactions();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menghapus transaksi: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error menghapus transaksi: $e')),
        );
      }
    }
  }

  Future<void> _loadAvatar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? storedAvatar = prefs.getString('avatarUrl');

      if (storedAvatar == null) {
        storedAvatar = avatarList[Random().nextInt(avatarList.length)];
        await prefs.setString('avatarUrl', storedAvatar);
      }

      setState(() {
        avatarPath = storedAvatar;
      });
    } catch (e) {
      debugPrint('Error loading avatar: $e');
    }
  }

  void _navigateWeek(int direction) {
    setState(() {
      startDate = startDate.add(Duration(days: 7 * direction));
    });
    fetchWeeklyBudget();
    fetchTransactions();
  }

  void _onBottomNavTap(int index) {
    setState(() {
      currentIndex = index;
    });
    if (!mounted) return;
    switch (index) {
      case 1:
        Navigator.pushNamed(context, '/chart_page').then((_) => fetchWeeklyBudget());
        break;
      case 2:
        Navigator.pushNamed(context, '/budget_page').then((_) => fetchWeeklyBudget());
        break;
    }
  }

  void _onTabSelected(String type) {
    if (!mounted) return;
    switch (type) {
      case 'monthly':
        Navigator.pushNamed(context, '/home_month').then((_) => fetchWeeklyBudget());
        break;
      case 'yearly':
        Navigator.pushNamed(context, '/home_year').then((_) => fetchWeeklyBudget());
        break;
    }
  }

  String get startFormatted =>
      '${startDate.day}/${startDate.month}/${startDate.year}';

  String get endFormatted {
    final endDate = startDate.add(const Duration(days: 6));
    return '${endDate.day}/${endDate.month}/${endDate.year}';
  }

  List<Map<String, dynamic>> get currentWeekTransactions {
    final endDate = startDate.add(const Duration(days: 6));
    return transactions.where((tx) {
      final txDate = tx['date'] as DateTime;
      return txDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
          txDate.isBefore(endDate.add(const Duration(days: 1)));
    }).toList();
  }

  double get income => currentWeekTransactions
      .where((tx) => tx['type'] == 'income' && tx['amount'] > 0)
      .fold(0.0, (sum, tx) => sum + tx['amount']);

  double get outcome => currentWeekTransactions
      .where((tx) => tx['type'] == 'outcome' && tx['amount'] < 0)
      .fold(0.0, (sum, tx) => sum + tx['amount'].abs());

  double get total => income - outcome;

  String _formatCurrency(double amount) {
    return NumberFormat('#,##0', 'id_ID').format(amount);
  }

  Color _getProgressColor(double progress) {
    if (progress < 0.5) return Colors.green;
    if (progress < 0.8) return Colors.orange;
    return Colors.red;
  }

  int _getWeekNumber(DateTime date) {
    final firstJan = DateTime(date.year, 1, 1);
    final days = date.difference(firstJan).inDays;
    return ((days + firstJan.weekday) / 7).ceil();
  }

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final progress = weeklyBudget == 0.0 ? 0.0 : (outcome / weeklyBudget).clamp(0.0, 1.0);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
        backgroundColor: const Color(0xFF724E99),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFFEF6FF),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.chevron_left, color: Colors.white),
                                    onPressed: () => _navigateWeek(-1),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        startFormatted,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                      Text(
                                        endFormatted,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.chevron_right, color: Colors.white),
                                    onPressed: () => _navigateWeek(1),
                                  ),
                                ],
                              ),
                              UserAvatarMenu(
                                avatarPath: avatarPath,
                                onSignOut: () async {
                                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                                  try {
                                    final prefs = await SharedPreferences.getInstance();
                                    await prefs.remove('token');
                                    if (context.mounted) {
                                      Navigator.pushReplacementNamed(context, '/login');
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      scaffoldMessenger.showSnackBar(
                                        SnackBar(content: Text('Gagal logout: $e')),
                                      );
                                    }
                                  }
                                },
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
                                _buildSummaryCard('income', _formatCurrency(income), Colors.green),
                                _buildSummaryCard('outcome', _formatCurrency(outcome), Colors.red),
                                _buildSummaryCard('total', _formatCurrency(total), total >= 0 ? Colors.green : Colors.red),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _buildTab('weekly', true, () => null),
                        const SizedBox(width: 8),
                        _buildTab('monthly', false, () => _onTabSelected('monthly')),
                        const SizedBox(width: 8),
                        _buildTab('yearly', false, () => _onTabSelected('yearly')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (weeklyBudget > 0.0) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rp ${_formatCurrency(total)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.grey[300],
                            color: _getProgressColor(progress),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Outcome: ${_formatCurrency(outcome)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              Text(
                                'Budget: ${_formatCurrency(weeklyBudget)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (currentWeekTransactions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 32),
                      child: Column(
                        children: [
                          SvgPicture.asset(
                            'assets/empty2.svg',
                            height: 150,
                            placeholderBuilder: (context) => const Icon(Icons.image_not_supported),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No transactions found for this week',
                            style: TextStyle(
                              color: Colors.grey,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Column(
                      children: currentWeekTransactions.map((tx) {
                        return Slidable(
                          key: ValueKey(tx['id']),
                          endActionPane: ActionPane(
                            motion: const ScrollMotion(),
                            children: [
                              SlidableAction(
                                onPressed: (context) {
                                  Navigator.pushNamed(
                                    context,
                                    '/edit_page',
                                    arguments: tx,
                                  ).then((result) {
                                    if (result == true) fetchTransactions();
                                  });
                                },
                                backgroundColor: Color.fromARGB(255, 224, 214, 235),
                                foregroundColor: Colors.white,
                                icon: Icons.edit,
                                label: 'Edit',
                              ),
                              SlidableAction(
                                onPressed: (context) => deleteTransaction(tx['id']),
                                backgroundColor: Color.fromARGB(255, 224, 214, 235),
                                foregroundColor: Colors.white,
                                icon: Icons.delete,
                                label: 'Delete',
                              ),
                            ],
                          ),
                          child: _buildTransactionItem(
                            tx['title'],
                            '${tx['date'].day}/${tx['date'].month}/${tx['date'].year}',
                            tx['amount'] > 0
                                ? '+Rp ${_formatCurrency(tx['amount'].abs())}'
                                : '-Rp ${_formatCurrency(tx['amount'].abs())}',
                            tx['icon'],
                            tx['description'],
                            tx['amount'] > 0 ? Colors.green : Colors.red,
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/add_page').then((_) {
            fetchTransactions();
            fetchWeeklyBudget();
          });
        },
        backgroundColor: const Color(0xFF724E99),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28.0),
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 40),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: _onBottomNavTap,
        backgroundColor: const Color(0xFF724E99),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        iconSize: 28,
        selectedLabelStyle: const TextStyle(fontFamily: 'Poppins'),
        unselectedLabelStyle: const TextStyle(fontFamily: 'Poppins'),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart),
            label: 'Chart',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Budgeting',
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String amount, Color color) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black54,
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Rp $amount',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
            fontFamily: 'Poppins',
          ),
        ),
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
              fontFamily: 'Poppins',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionItem(String title, String date, String amount, String? iconUrl, String description, Color color) {
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
              radius: 18,
              child: iconUrl != null && iconUrl.isNotEmpty
                  ? iconUrl.toLowerCase().endsWith('.svg')
                      ? SvgPicture.network(
                          'http://10.0.2.2:8000/storage/$iconUrl',
                          width: 20,
                          height: 20,
                          colorFilter: const ColorFilter.mode(
                            Color(0xFF724E99),
                            BlendMode.srcIn,
                          ),
                          placeholderBuilder: (context) => const Icon(
                            Icons.category,
                            size: 20,
                            color: Color(0xFF724E99),
                          ),
                        )
                      : Image.network(
                          'http://10.0.2.2:8000/storage/$iconUrl',
                          width: 20,
                          height: 20,
                          errorBuilder: (context, error, stackTrace) {
                            debugPrint('Error loading image: $error');
                            return const Icon(
                              Icons.category,
                              size: 20,
                              color: Color(0xFF724E99),
                            );
                          },
                        )
                  : const Icon(
                      Icons.category,
                      size: 20,
                      color: Color(0xFF724E99),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  if (description.isNotEmpty)
                    Text(
                      description,
                      style: const TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: 12,
                        color: Colors.grey,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  Text(
                    date,
                    style: const TextStyle(
                      fontWeight: FontWeight.w300,
                      fontSize: 12,
                      color: Colors.grey,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
            Text(
              amount,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: color,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
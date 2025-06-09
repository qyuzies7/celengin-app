import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:flutter_slidable/flutter_slidable.dart';

const apiBaseUrl = 'http://3.1.207.173/api';

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
          onSignOut!();
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
  final DateTime? initialDate;
  const HomePage({super.key, this.initialDate});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late DateTime startDate;
  int currentIndex = 0;
  String? avatarPath;
  double weeklyBudget = 0.0;
  bool hasWeeklyBudget = false;
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
    startDate = widget.initialDate ?? DateTime.now();
    startDate = DateTime(startDate.year, startDate.month, startDate.day - (startDate.weekday - 1));
    _loadAvatar();
    fetchData();
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

  Future<void> fetchData() async {
    setState(() {
      isLoading = true;
    });
    await Future.wait([
      fetchWeeklyBudget(),
      fetchTransactions(),
    ]);
    setState(() {
      isLoading = false;
    });
  }

  Future<void> fetchWeeklyBudget() async {
    final token = await getTokenFromStorage();
    if (token == null) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
      return;
    }

    final weekStart = startDate;
    final weekEnd = startDate.add(const Duration(days: 6));
    final dateFormat = DateFormat('yyyy-MM-dd');
    final startFormatted = dateFormat.format(weekStart);
    final endFormatted = dateFormat.format(weekEnd);

    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/plan'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> plans = jsonDecode(response.body);
        final weekPlan = plans.firstWhere(
          (plan) =>
              plan['periode_type'] == 'weekly' &&
              plan['periode_start'] == startFormatted &&
              plan['periode_end'] == endFormatted,
          orElse: () => null,
        );
        if (weekPlan != null &&
            double.tryParse(weekPlan['nominal'].toString()) != null &&
            double.tryParse(weekPlan['nominal'].toString())! > 0) {
          final budgetValue = double.tryParse(weekPlan['nominal'].toString()) ?? 0.0;
          setState(() {
            weeklyBudget = budgetValue;
            hasWeeklyBudget = true;
          });
        } else {
          setState(() {
            weeklyBudget = 0.0;
            hasWeeklyBudget = false;
          });
        }
      } else {
        setState(() {
          weeklyBudget = 0.0;
          hasWeeklyBudget = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching weekly budget: $e');
      setState(() {
        weeklyBudget = 0.0;
        hasWeeklyBudget = false;
      });
    }
  }

  Future<void> fetchTransactions() async {
    final token = await getTokenFromStorage();
    if (token == null) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
      return;
    }

    final weekStart = startDate;
    final weekEnd = startDate.add(const Duration(days: 6));
    final dateFormat = DateFormat('yyyy-MM-dd');
    final startFormatted = dateFormat.format(weekStart);
    final endFormatted = dateFormat.format(weekEnd);

    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/transaksi?start=$startFormatted&end=$endFormatted'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> list = data is List ? data : data['transaksi'] ?? [];
        final weeklyTransactions = list.map<Map<String, dynamic>>((item) {
          String? icon;
          String? categoryName;
          if (item['jenis'] == 'income' && item['income'] != null) {
            icon = item['income']['icon']?.toString();
            categoryName = item['income']['nama']?.toString() ?? 'Unknown';
          } else if (item['outcome'] != null) {
            icon = item['outcome']['icon']?.toString();
            categoryName = item['outcome']['nama']?.toString() ?? 'Unknown';
          }
          final dateString = item['tanggal']?.toString() ?? DateTime.now().toIso8601String();
          final date = DateTime.tryParse(dateString) ?? DateTime.now();
          return {
            'id': item['id'],
            'title': categoryName ?? 'Unknown',
            'description': item['keterangan']?.toString() ?? '',
            'date': date.toIso8601String(),
            'amount': double.tryParse(item['nominal'].toString()) ?? 0.0,
            'icon': icon ?? '',
            'type': item['jenis'],
          };
        }).where((tx) {
          final txDate = DateTime.parse(tx['date'] as String);
          return txDate.isAfter(weekStart.subtract(const Duration(days: 1))) &&
              txDate.isBefore(weekEnd.add(const Duration(days: 1)));
        }).toList();

        // Sort by date descending (terbaru-terlama)
        weeklyTransactions.sort((a, b) => DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));

        setState(() {
          transactions = weeklyTransactions;
        });
      } else if (response.statusCode == 401) {
        if (mounted) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();
          Navigator.pushReplacementNamed(context, '/login');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal memuat transaksi: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error memuat transaksi: $e')),
        );
      }
    }
  }

  Future<void> deleteTransaction(int id) async {
    try {
      final token = await getTokenFromStorage();
      if (token == null) {
        if (mounted) {
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
        setState(() {
          transactions.removeWhere((tx) => tx['id'] == id);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transaksi berhasil dihapus')),
          );
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

  void _navigateWeek(int direction) {
    setState(() {
      startDate = startDate.add(Duration(days: 7 * direction));
    });
    fetchData();
  }

  void _onTabSelected(String type) {
    if (!mounted) return;
    switch (type) {
      case 'monthly':
        Navigator.pushReplacementNamed(context, '/home_month', arguments: {'initialDate': startDate});
        break;
      case 'yearly':
        Navigator.pushReplacementNamed(context, '/home_year', arguments: {'initialDate': startDate});
        break;
    }
  }

  void _onBottomNavTap(int index) {
    setState(() {
      currentIndex = index;
    });
    if (!mounted) return;
    switch (index) {
      case 0:
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/chart_page');
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/budget_page');
        break;
    }
  }

  String get startFormatted => '${startDate.day}/${startDate.month}/${startDate.year}';

  String get endFormatted {
    final endDate = startDate.add(const Duration(days: 6));
    return '${endDate.day}/${endDate.month}/${endDate.year}';
  }

  double get income => transactions
      .where((tx) => tx['type'] == 'income')
      .fold(0.0, (sum, tx) => sum + (tx['amount'] as double));

  double get outcome => transactions
      .where((tx) => tx['type'] == 'outcome')
      .fold(0.0, (sum, tx) => sum + (tx['amount'] as double).abs());

  double get total => income - outcome + continuedBalance;

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

  bool get isCurrentWeek {
    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day - now.weekday + 1);
    return startDate.isAtSameMomentAs(startOfWeek);
  }

  @override
  Widget build(BuildContext context) {
    final progress = hasWeeklyBudget && weeklyBudget > 0.0 ? (outcome / weeklyBudget).clamp(0.0, 1.0) : 0.0;

    final now = DateTime.now();
    final currentWeekStart = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final isCurrentWeek = startDate.year == currentWeekStart.year &&
        startDate.month == currentWeekStart.month &&
        startDate.day == currentWeekStart.day;

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
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.clear();
                                  if (mounted) {
                                    Navigator.pushReplacementNamed(context, '/login');
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
                        _buildTab('weekly', true, () {}),
                        const SizedBox(width: 8),
                        _buildTab('monthly', false, () => _onTabSelected('monthly')),
                        const SizedBox(width: 8),
                        _buildTab('yearly', false, () => _onTabSelected('yearly')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (hasWeeklyBudget && weeklyBudget > 0.0 && isCurrentWeek && transactions.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rp ${_formatCurrency(outcome)}',
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
                                // TAMPILKAN MINUS JIKA MELEBIHI BUDGET
                                'Budget Left: ${weeklyBudget - outcome < 0 ? '-' : ''}Rp ${_formatCurrency((weeklyBudget - outcome).abs())}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              Text(
                                'Budget: Rp ${_formatCurrency(weeklyBudget)}',
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
                  if (transactions.isEmpty)
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
                      children: transactions.map((tx) {
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
                                    if (result == true) fetchData();
                                  });
                                },
                                backgroundColor: const Color.fromARGB(255, 224, 214, 235),
                                foregroundColor: Colors.white,
                                icon: Icons.edit,
                                label: 'Edit',
                              ),
                              SlidableAction(
                                onPressed: (context) => deleteTransaction(tx['id']),
                                backgroundColor: const Color.fromARGB(255, 224, 214, 235),
                                foregroundColor: Colors.white,
                                icon: Icons.delete,
                                label: 'Delete',
                              ),
                            ],
                          ),
                          child: _buildTransactionItem(
                            tx['title'] as String,
                            '${DateTime.parse(tx['date'] as String).day}/${DateTime.parse(tx['date'] as String).month}/${DateTime.parse(tx['date'] as String).year}',
                            (tx['amount'] as double) > 0
                                ? '+Rp ${_formatCurrency(tx['amount'].abs())}'
                                : '-Rp ${_formatCurrency(tx['amount'].abs())}',
                            tx['icon'] as String?,
                            tx['description'] as String,
                            (tx['amount'] as double) > 0 ? Colors.green : Colors.red,
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
          Navigator.pushNamed(context, '/add_page').then((_) => fetchData());
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
                  ? FutureBuilder<String?>(
                      future: getTokenFromStorage(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data == null) {
                          return const Icon(
                            Icons.category,
                            size: 20,
                            color: Color(0xFF724E99),
                          );
                        }
                        return SvgPicture.network(
                          iconUrl.startsWith('http') ? iconUrl : 'http://3.1.207.173/storage/$iconUrl',
                          width: 20,
                          height: 20,
                          headers: {
                            'Authorization': 'Bearer ${snapshot.data}',
                          },
                          colorFilter: const ColorFilter.mode(
                            Color(0xFF724E99),
                            BlendMode.srcIn,
                          ),
                          placeholderBuilder: (context) => const Icon(
                            Icons.category,
                            size: 20,
                            color: Color(0xFF724E99),
                          ),
                          fit: BoxFit.contain,
                          semanticsLabel: 'Ikon Kategori',
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
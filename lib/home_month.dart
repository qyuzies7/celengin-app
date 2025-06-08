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

class HomeMonthPage extends StatefulWidget {
  final DateTime? initialDate;
  const HomeMonthPage({super.key, this.initialDate});

  @override
  State<HomeMonthPage> createState() => _HomeMonthPageState();
}

class _HomeMonthPageState extends State<HomeMonthPage> {
  late DateTime currentMonth;
  List<Map<String, dynamic>> allTransactions = [];
  double monthlyBudget = 0.0;
  bool hasMonthlyBudget = false;
  int currentIndex = 0;
  String? avatarPath;
  bool isLoading = false;
  double continuedBalance = 0.0;
  bool isNewUser = false; // Track if user is new

  final List<String> avatarList = [
    'assets/avatars/avatar1.png',
    'assets/avatars/avatar2.png',
    'assets/avatars/avatar3.png',
    'assets/avatars/avatar4.png',
  ];

  @override
  void initState() {
    super.initState();
    currentMonth = widget.initialDate ?? DateTime.now();
    currentMonth = DateTime(currentMonth.year, currentMonth.month, 1);
    _loadAvatar();
    _checkIfNewUser();
    _loadCachedData();
    fetchData();
  }

  Future<void> _checkIfNewUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('userId');
    if (userId != null) {
      // Check if user has any saved data (transactions, budgets, etc.)
      final hasAnyData = prefs.getKeys().any((key) => 
        key.startsWith('transactions_') || 
        key.startsWith('budget_') || 
        key.startsWith('has_weekly_budget_') ||
        key.startsWith('has_monthly_budget_')
      );
      setState(() {
        isNewUser = !hasAnyData;
      });
    }
  }

  Future<void> _loadCachedData() async {
    final prefs = await SharedPreferences.getInstance();
    final monthKey = '${currentMonth.year}_${currentMonth.month}';
    final monthBudgetKey = 'budget_monthly_$monthKey';
    final hasMonthBudgetKey = 'has_monthly_budget_$monthKey';

    final cachedTx = prefs.getString('transactions_monthly_$monthKey');
    if (cachedTx != null) {
      setState(() {
        allTransactions = List<Map<String, dynamic>>.from(jsonDecode(cachedTx));
        isNewUser = false; // User has data, not new anymore
      });
    } else {
      setState(() {
        allTransactions = [];
      });
    }

    final hasBudget = prefs.getBool(hasMonthBudgetKey) ?? false;
    setState(() {
      hasMonthlyBudget = hasBudget;
    });

    if (hasMonthlyBudget) {
      final cachedBudget = prefs.get(monthBudgetKey);
      if (cachedBudget != null) {
        setState(() {
          monthlyBudget = (cachedBudget is int) ? cachedBudget.toDouble() : (cachedBudget as double);
          isNewUser = false; // User has budget, not new anymore
        });
        debugPrint('Loaded cached monthly budget: $monthlyBudget for month $monthKey');
      }
    } else {
      setState(() {
        monthlyBudget = 0.0;
      });
    }

    final previousMonth = DateTime(currentMonth.year, currentMonth.month - 1);
    final previousMonthKey = 'balance_monthly_${previousMonth.year}_${previousMonth.month}';
    final previousBalance = prefs.get(previousMonthKey);
    setState(() {
      continuedBalance = (previousBalance is int) ? previousBalance.toDouble() : (previousBalance as double? ?? 0.0);
    });
  }

  Future<void> _saveCachedData() async {
    final prefs = await SharedPreferences.getInstance();
    final monthKey = '${currentMonth.year}_${currentMonth.month}';
    final monthBudgetKey = 'budget_monthly_$monthKey';
    final hasMonthBudgetKey = 'has_monthly_budget_$monthKey';

    await prefs.setString('transactions_monthly_$monthKey', jsonEncode(allTransactions));
    await prefs.setBool(hasMonthBudgetKey, hasMonthlyBudget);

    if (hasMonthlyBudget && monthlyBudget > 0) {
      await prefs.setDouble(monthBudgetKey, monthlyBudget);
      debugPrint('Saved cached monthly budget: $monthlyBudget for month $monthKey');
    } else {
      await prefs.remove(monthBudgetKey);
    }

    final balanceKey = 'balance_monthly_${currentMonth.year}_${currentMonth.month}';
    await prefs.setDouble(balanceKey, total);
    
    // Mark user as no longer new if they have data
    if (allTransactions.isNotEmpty || hasMonthlyBudget) {
      setState(() {
        isNewUser = false;
      });
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

  Future<void> fetchData() async {
    setState(() {
      isLoading = true;
    });
    await Future.wait([
      fetchMonthlyBudget(),
      fetchTransactions(),
    ]);
    setState(() {
      isLoading = false;
    });
  }

  Future<void> fetchMonthlyBudget() async {
    final token = await getTokenFromStorage();
    if (token == null) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
      return;
    }

    final monthStart = DateTime(currentMonth.year, currentMonth.month, 1);
    final monthEnd = DateTime(currentMonth.year, currentMonth.month + 1, 0);
    final dateFormat = DateFormat('yyyy-MM-dd');
    final startFormatted = dateFormat.format(monthStart);
    final endFormatted = dateFormat.format(monthEnd);

    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/plan?periode_type=monthly&periode_start=$startFormatted&periode_end=$endFormatted'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> plans = jsonDecode(response.body);
        if (plans.isNotEmpty) {
          final budgetValue = double.tryParse(plans[0]['nominal'].toString()) ?? 0.0;
          setState(() {
            monthlyBudget = budgetValue;
            hasMonthlyBudget = budgetValue > 0;
            if (hasMonthlyBudget) isNewUser = false; // User has budget, not new anymore
          });
          debugPrint('Fetched monthly budget: $budgetValue for $startFormatted to $endFormatted');
        } else {
          setState(() {
            monthlyBudget = 0.0;
            hasMonthlyBudget = false;
          });
          debugPrint('No monthly budget found for $startFormatted to $endFormatted');
        }
        await _saveCachedData();
      } else {
        setState(() {
          monthlyBudget = 0.0;
          hasMonthlyBudget = false;
        });
        debugPrint('Failed to fetch monthly budget: ${response.statusCode}');
        await _saveCachedData();
      }
    } catch (e) {
      debugPrint('Error fetching monthly budget: $e');
      setState(() {
        monthlyBudget = 0.0;
        hasMonthlyBudget = false;
      });
      await _saveCachedData();
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

    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/transaksi?year=${currentMonth.year}&month=${currentMonth.month}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> list = data is List ? data : data['transaksi'] ?? [];
        final monthlyTransactions = list.map<Map<String, dynamic>>((item) {
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
          return txDate.month == currentMonth.month && txDate.year == currentMonth.year;
        }).toList();

        setState(() {
          allTransactions = monthlyTransactions;
          if (allTransactions.isNotEmpty) isNewUser = false; // User has transactions, not new anymore
        });
        await _saveCachedData();
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
          allTransactions.removeWhere((tx) => tx['id'] == id);
        });
        await _saveCachedData();
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
          SnackBar(content: Text('Error deleting transaksi: $e')),
        );
      }
    }
  }

  void _navigateMonth(int direction) {
    setState(() {
      currentMonth = DateTime(currentMonth.year, currentMonth.month + direction);
    });
    _loadCachedData();
    fetchData();
  }

  void _onTabSelected(String type) {
    if (!mounted) return;
    switch (type) {
      case 'weekly':
        Navigator.pushReplacementNamed(context, '/home', arguments: {'initialDate': currentMonth});
        break;
      case 'yearly':
        Navigator.pushReplacementNamed(context, '/home_year', arguments: {'initialDate': DateTime(currentMonth.year)});
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
        Navigator.pushReplacementNamed(context, '/budget_page').then((_) {
          // Refresh data when returning from budget page
          fetchData();
        });
        break;
    }
  }

  String get monthFormatted => '${currentMonth.month}/${currentMonth.year}';

  double get income => allTransactions
      .where((tx) => tx['type'] == 'income')
      .fold(0.0, (sum, tx) => sum + (tx['amount'] as double));

  double get outcome => allTransactions
      .where((tx) => tx['type'] == 'outcome')
      .fold(0.0, (sum, tx) => sum + (tx['amount'] as double).abs());

  double get total => income - outcome + continuedBalance;

  String _formatCurrency(double amount) {
    return NumberFormat('#,##0', 'id_ID').format(amount.abs());
  }

  Color _getProgressColor(double progress) {
    if (progress < 0.5) return Colors.green;
    if (progress < 0.8) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final progress = hasMonthlyBudget && monthlyBudget > 0.0 ? (outcome / monthlyBudget).clamp(0.0, 1.0) : 0.0;
    
    // Check if current month is the actual current month (today)
    final now = DateTime.now();
    final isCurrentMonth = currentMonth.year == now.year && currentMonth.month == now.month;
    
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
                                    onPressed: () => _navigateMonth(-1),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    monthFormatted,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.chevron_right, color: Colors.white),
                                    onPressed: () => _navigateMonth(1),
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
                        _buildTab('weekly', false, () => _onTabSelected('weekly')),
                        const SizedBox(width: 8),
                        _buildTab('monthly', true, () {}),
                        const SizedBox(width: 8),
                        _buildTab('yearly', false, () => _onTabSelected('yearly')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Progress bar ONLY shows if NOT new user AND has monthly budget AND budget > 0 AND is current month
                  if (!isNewUser && hasMonthlyBudget && monthlyBudget > 0.0 && isCurrentMonth) ...[
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
                                'Budget Left: ${_formatCurrency(monthlyBudget - outcome)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              Text(
                                'Budget: ${_formatCurrency(monthlyBudget)}',
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
                  if (allTransactions.isEmpty)
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
                          Text(
                            isNewUser 
                              ? 'Welcome! Start by adding your first transaction or setting up a budget.'
                              : 'No transactions found for this month',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontFamily: 'Poppins',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    Column(
                      children: allTransactions.map((tx) {
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
                                ? '+Rp ${_formatCurrency(tx['amount'] as double)}'
                                : '-Rp ${_formatCurrency(tx['amount'] as double)}',
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
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

const apiBaseUrl = 'http://3.1.207.173/api';

Future<String?> getTokenFromStorage() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('token');
}

Future<int?> getUserIdFromStorage() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt('userId');
}

class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key});

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  String amount = '';
  int weeklyBudget = 0;
  int monthlyBudget = 0;
  String currentMode = ''; // "weekly" atau "monthly"
  int _selectedIndex = 2;
  final NumberFormat _numberFormat = NumberFormat('#,##0', 'id_ID');

  @override
  void initState() {
    super.initState();
    fetchBudgets();
  }

  Future<void> fetchBudgets() async {
    final token = await getTokenFromStorage();
    if (token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No token found, please login again')),
        );
      }
      return;
    }
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);

    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/plan'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> plans = jsonDecode(response.body);
        final weekly = plans.firstWhere(
          (p) =>
              p['periode_type'] == 'weekly' &&
              _sameDate(DateTime.parse(p['periode_start']), weekStart) &&
              _sameDate(DateTime.parse(p['periode_end']), weekEnd),
          orElse: () => null,
        );
        final monthly = plans.firstWhere(
          (p) =>
              p['periode_type'] == 'monthly' &&
              _sameDate(DateTime.parse(p['periode_start']), monthStart) &&
              _sameDate(DateTime.parse(p['periode_end']), monthEnd),
          orElse: () => null,
        );
        setState(() {
          weeklyBudget = weekly != null ? int.tryParse(weekly['nominal'].toString()) ?? 0 : 0;
          monthlyBudget = monthly != null ? int.tryParse(monthly['nominal'].toString()) ?? 0 : 0;
        });
      } else {
        debugPrint('Failed to fetch budgets: ${response.statusCode} - ${response.body}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to fetch budgets: ${response.statusCode}')),
          );
        }
        setState(() {
          weeklyBudget = 0;
          monthlyBudget = 0;
        });
      }
    } catch (e) {
      debugPrint('Error fetching budgets: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching budgets: $e')),
        );
      }
      setState(() {
        weeklyBudget = 0;
        monthlyBudget = 0;
      });
    }
  }

  Future<void> deleteBudget(String mode) async {
    final token = await getTokenFromStorage();
    if (token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No token found, please login again')),
        );
      }
      return;
    }

    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);

    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/plan'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> plans = jsonDecode(response.body);
        dynamic plan;
        if (mode == 'weekly') {
          plan = plans.firstWhere(
            (p) =>
                p['periode_type'] == 'weekly' &&
                _sameDate(DateTime.parse(p['periode_start']), weekStart) &&
                _sameDate(DateTime.parse(p['periode_end']), weekEnd),
            orElse: () => null,
          );
        } else {
          plan = plans.firstWhere(
            (p) =>
                p['periode_type'] == 'monthly' &&
                _sameDate(DateTime.parse(p['periode_start']), monthStart) &&
                _sameDate(DateTime.parse(p['periode_end']), monthEnd),
            orElse: () => null,
          );
        }

        if (plan == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No budget found to delete')),
            );
          }
          return;
        }

        final planId = plan['id'];
        final deleteResponse = await http.delete(
          Uri.parse('$apiBaseUrl/plan/$planId'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );

        if (deleteResponse.statusCode == 200 || deleteResponse.statusCode == 204) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Budget deleted successfully!')),
            );
          }
          setState(() {
            if (mode == 'weekly') {
              weeklyBudget = 0;
            } else {
              monthlyBudget = 0;
            }
            amount = '';
            currentMode = '';
          });
          await fetchBudgets();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to delete budget: ${deleteResponse.statusCode}')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to fetch budgets: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error deleting budget: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting budget: $e')),
        );
      }
    }
  }

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  int _getWeekNumber(DateTime date) {
    final firstJan = DateTime(date.year, 1, 1);
    final days = date.difference(firstJan).inDays;
    return ((days + firstJan.weekday) / 7).ceil();
  }

  Future<int?> _fetchUserId(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/user'),
        headers: {'Authorization': 'Bearer $token'},
      );
      debugPrint('Fetch user ID response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);
        final userId = int.tryParse(userData['id'].toString());
        if (userId != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('userId', userId);
          return userId;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching user ID: $e');
      return null;
    }
  }

  Future<void> _saveBudget({required int nominal, required String mode}) async {
    final token = await getTokenFromStorage();
    if (token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No token found, please login again')),
        );
      }
      return;
    }

    int? userId = await getUserIdFromStorage();
    if (userId == null) {
      userId = await _fetchUserId(token);
      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to fetch user ID')),
          );
        }
        return;
      }
    }

    DateTime now = DateTime.now();
    DateFormat formatter = DateFormat('yyyy-MM-dd');
    late DateTime periodStart, periodEnd;
    if (mode == 'weekly') {
      int daysToMonday = now.weekday - 1;
      periodStart = now.subtract(Duration(days: daysToMonday));
      periodEnd = periodStart.add(const Duration(days: 6));
    } else {
      periodStart = DateTime(now.year, now.month, 1);
      periodEnd = DateTime(now.year, now.month + 1, 0);
    }

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/plan'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'pengguna_id': userId,
          'periode_type': mode,
          'periode_start': formatter.format(periodStart),
          'periode_end': formatter.format(periodEnd),
          'nominal': nominal.toString(),
          'created_at': formatter.format(now),
          'updated_at': formatter.format(now),
        }),
      );

      debugPrint('Save budget response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Budget saved successfully!')),
          );
        }
        await fetchBudgets();
        setState(() {
          amount = '';
          currentMode = '';
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save budget: ${response.statusCode} - ${response.body}')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error saving budget: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving budget: $e')),
        );
      }
    }
  }

  void _onNumberPressed(String value) {
    setState(() {
      String rawAmount = amount.replaceAll('.', '');
      if ((value == '.' || value == ',') && (rawAmount.contains('.') || rawAmount.contains(','))) return;
      if (rawAmount == '0' && value != '.') {
        rawAmount = value;
      } else {
        rawAmount += value;
      }
      int? parsed = int.tryParse(rawAmount.replaceAll(',', ''));
      if (parsed != null) {
        amount = _numberFormat.format(parsed);
      } else {
        amount = rawAmount;
      }
    });
  }

  void _onDeletePressed() {
    setState(() {
      if (amount.isNotEmpty) {
        String rawAmount = amount.replaceAll('.', '');
        rawAmount = rawAmount.substring(0, rawAmount.length - 1);
        int? parsed = int.tryParse(rawAmount);
        amount = parsed != null ? _numberFormat.format(parsed) : '';
      }
    });
  }

  void _onConfirmPressed() {
    if (currentMode.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a budget mode (weekly/monthly)')),
        );
      }
      return;
    }
    if (amount.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid positive amount')),
        );
      }
      return;
    }

    int? parsedAmount = int.tryParse(amount.replaceAll('.', ''));
    if (parsedAmount == null || parsedAmount <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid positive amount')),
        );
      }
      setState(() {
        amount = '';
        currentMode = '';
      });
      return;
    }

    _saveBudget(nominal: parsedAmount, mode: currentMode);
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (!mounted) return;
    switch (index) {
      case 0:
        Navigator.pushNamed(context, '/home').then((_) => fetchBudgets());
        break;
      case 1:
        Navigator.pushNamed(context, '/chart_page').then((_) => fetchBudgets());
        break;
    }
  }

  Widget _buildBudgetTile({required String label, required int amountValue, required String mode}) {
    final isActive = currentMode == mode;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
            ),
            const SizedBox(height: 8),
            Text(
              'IDR ${_numberFormat.format(amountValue)}',
              style: const TextStyle(
                fontSize: 20,
                color: Color(0xFF724E99),
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              readOnly: true,
              onTap: () {
                setState(() {
                  currentMode = mode;
                  amount = '';
                });
              },
              decoration: InputDecoration(
                hintText: 'Enter $mode amount (IDR)',
                hintStyle: const TextStyle(fontFamily: 'Poppins'),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              controller: TextEditingController(text: isActive ? amount : ''),
              style: const TextStyle(fontFamily: 'Poppins'),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (isActive && amount.isNotEmpty) ? _onConfirmPressed : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF724E99),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[400],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('SAVE BUDGET', style: TextStyle(fontFamily: 'Poppins')),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => deleteBudget(mode),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 71, 43, 98),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('DELETE BUDGET', style: TextStyle(fontFamily: 'Poppins')),
              ),
            ),
            if (isActive)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '(IDR) ${amount.isEmpty ? '0' : amount}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF724E99),
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypadButton(String label, {VoidCallback? onTap, Widget? icon}) {
    return Padding(
      padding: const EdgeInsets.all(6.0),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.all(20),
          elevation: 0,
        ),
        child: icon != null
            ? icon
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
      ),
    );
  }

  Widget _buildKeypad() {
    final List<List<String>> keys = [
      ['1', '2', '3', 'del'],
      ['4', '5', '6', 'check'],
      ['7', '8', '9', ''],
      ['.', '0', ',', ''],
    ];

    return Container(
      color: const Color(0xFF724E99),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: keys.map((row) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((label) {
              if (label == 'del') {
                return Expanded(
                  child: _buildKeypadButton(
                    '',
                    onTap: _onDeletePressed,
                    icon: const Icon(Icons.backspace_outlined, color: Colors.black),
                  ),
                );
              } else if (label == 'check') {
                return Expanded(
                  child: _buildKeypadButton(
                    '',
                    onTap: (amount.isNotEmpty) ? _onConfirmPressed : null,
                    icon: Icon(
                      Icons.check_circle,
                      color: (amount.isNotEmpty) ? const Color(0xFF724E99) : Colors.grey[400],
                      size: 32,
                    ),
                  ),
                );
              } else if (label == '') {
                return const Expanded(child: SizedBox());
              } else {
                return Expanded(
                  child: _buildKeypadButton(
                    label,
                    onTap: () => _onNumberPressed(label),
                  ),
                );
              }
            }).toList(),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEF6FF),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFF724E99),
            padding: const EdgeInsets.only(top: 63, bottom: 32, left: 16, right: 16),
            child: const Text(
              'Budgeting',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      _buildBudgetTile(label: 'Weekly Budget Limit', amountValue: weeklyBudget, mode: 'weekly'),
                      _buildBudgetTile(label: 'Monthly Budget Limit', amountValue: monthlyBudget, mode: 'monthly'),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (currentMode.isNotEmpty) _buildKeypad(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
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
}
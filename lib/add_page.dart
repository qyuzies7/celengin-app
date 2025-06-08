import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

const apiBaseUrl = 'http://3.1.207.173/api';

class AddPage extends StatefulWidget {
  const AddPage({super.key});

  @override
  State<AddPage> createState() => _AddPageState();
}

class _AddPageState extends State<AddPage> {
  String? selectedType = 'Expenses';
  String? selectedCategory;
  int? selectedCategoryId;
  String amount = '0';
  String note = '';
  DateTime? selectedDate;

  final List<String> types = ['Expenses', 'Income'];
  Map<String, List<Map<String, dynamic>>> categories = {
    'Expenses': [],
    'Income': [],
  };
  bool isLoadingCategories = true;
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    fetchCategories();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token')?.trim();
    if (token == null || token.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sesi kadaluarsa, silakan login kembali')),
        );
        Navigator.pushReplacementNamed(context, '/login');
      }
      return null;
    }
    return token;
  }

  Future<void> fetchCategories() async {
    setState(() {
      isLoadingCategories = true;
    });
    try {
      final token = await _getToken();
      if (token == null) return;

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      };

      final responses = await Future.wait([
        http.get(Uri.parse('$apiBaseUrl/income'), headers: headers),
        http.get(Uri.parse('$apiBaseUrl/outcome'), headers: headers),
      ]);

      final incomeRes = responses[0];
      final outcomeRes = responses[1];

      if (incomeRes.statusCode == 200 && outcomeRes.statusCode == 200) {
        final incomeData = jsonDecode(incomeRes.body);
        final outcomeData = jsonDecode(outcomeRes.body);

        final incomeList = incomeData is List ? incomeData : incomeData['data'] ?? [];
        final outcomeList = outcomeData is List ? outcomeData : outcomeData['data'] ?? [];

        setState(() {
          categories['Income'] = incomeList.map<Map<String, dynamic>>((e) {
            return {
              'id': e['id'],
              'label': e['nama']?.toString() ?? e['name']?.toString() ?? 'Unknown',
              'icon': e['icon']?.toString() ?? '',
            };
          }).toList();
          categories['Expenses'] = outcomeList.map<Map<String, dynamic>>((e) {
            return {
              'id': e['id'],
              'label': e['nama']?.toString() ?? e['name']?.toString() ?? 'Unknown',
              'icon': e['icon']?.toString() ?? '',
            };
          }).toList();
          isLoadingCategories = false;
        });
      } else {
        if (mounted) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    } catch (e) {
      setState(() {
        isLoadingCategories = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat kategori: $e')),
        );
      }
    }
  }

  double _evaluateExpression(String expression) {
    try {
      expression = expression.replaceAll('×', '*').replaceAll('÷', '/').replaceAll('−', '-');
      final tokens = _tokenize(expression);
      return _parseExpression(tokens);
    } catch (e) {
      return 0.0;
    }
  }

  List<String> _tokenize(String expression) {
    final tokens = <String>[];
    String currentToken = '';
    
    for (int i = 0; i < expression.length; i++) {
      final char = expression[i];
      if (['+', '-', '*', '/'].contains(char)) {
        if (currentToken.isNotEmpty) {
          tokens.add(currentToken);
          currentToken = '';
        }
        tokens.add(char);
      } else if (char == '.' || RegExp(r'[0-9]').hasMatch(char)) {
        currentToken += char;
      }
    }
    
    if (currentToken.isNotEmpty) {
      tokens.add(currentToken);
    }
    
    return tokens;
  }

  double _parseExpression(List<String> tokens) {
    if (tokens.isEmpty) return 0.0;
    
    for (int i = 1; i < tokens.length - 1; i += 2) {
      if (tokens[i] == '*' || tokens[i] == '/') {
        final left = double.tryParse(tokens[i - 1]) ?? 0.0;
        final right = double.tryParse(tokens[i + 1]) ?? 0.0;
        final result = tokens[i] == '*' ? left * right : (right != 0 ? left / right : 0.0);
        
        tokens[i - 1] = result.toString();
        tokens.removeAt(i + 1);
        tokens.removeAt(i);
        i -= 2;
      }
    }
    
    double result = double.tryParse(tokens[0]) ?? 0.0;
    for (int i = 1; i < tokens.length - 1; i += 2) {
      final operator = tokens[i];
      final operand = double.tryParse(tokens[i + 1]) ?? 0.0;
      
      if (operator == '+') {
        result += operand;
      } else if (operator == '-') {
        result -= operand;
      }
    }
    
    return result;
  }

  void _onNumberPressed(String value) {
    setState(() {
      if (value == '.' && amount.contains('.') && !RegExp(r'[+\-*/×÷−]').hasMatch(amount)) return;
      if (amount == '0' && value != '.') amount = '';
      amount += value;
    });
  }

  void _onOperatorPressed(String op) {
    setState(() {
      if (amount.isNotEmpty && !RegExp(r'[×\+\−\÷\*\/\-\+]$').hasMatch(amount)) {
        amount += op;
      }
    });
  }

  void _onDeletePressed() {
    setState(() {
      if (amount.isNotEmpty) {
        amount = amount.substring(0, amount.length - 1);
        if (amount.isEmpty) amount = '0';
      }
    });
  }

  void _onEqualsPressed() {
    setState(() {
      if (amount.isNotEmpty) {
        final result = _evaluateExpression(amount);
        amount = result.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '');
      }
    });
  }

  Future<void> _onConfirmPressed() async {
    String finalAmount = amount;
    if (RegExp(r'[×\+\−\÷]').hasMatch(amount)) {
      final result = _evaluateExpression(amount);
      finalAmount = result.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '');
    }

    final cleanedAmount = finalAmount.replaceAll(RegExp(r'[×\+\−\÷]'), '');
    if (cleanedAmount.isEmpty || double.tryParse(cleanedAmount) == null || double.parse(cleanedAmount) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan jumlah nominal yang valid!')),
      );
      return;
    }
    if (selectedCategory == null || selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kategori!')),
      );
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    final transactionDate = selectedDate ?? DateTime.now();
    final amountValue = double.parse(cleanedAmount) * (selectedType == 'Expenses' ? -1 : 1);
    
    final data = {
      'jenis': selectedType == 'Income' ? 'income' : 'outcome',
      selectedType == 'Income' ? 'income_id' : 'outcome_id': selectedCategoryId,
      'nominal': amountValue,
      'keterangan': note,
      'tanggal': DateFormat('yyyy-MM-dd HH:mm:ss').format(transactionDate),
    };

    try {
      final token = await _getToken();
      if (token == null) return;

      final response = await http.post(
        Uri.parse('$apiBaseUrl/transaksi'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        await _updateCache(transactionDate, amountValue, responseData['id']);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transaksi berhasil disimpan!')),
          );
          
          await _navigateToCorrectPeriod(transactionDate);
        }
      } else {
        if (mounted) {
          final errorData = jsonDecode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorData['message'] ?? 'Gagal menyimpan transaksi')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  Future<void> _updateCache(DateTime transactionDate, double amountValue, int transactionId) async {
    final prefs = await SharedPreferences.getInstance();
    
    final transactionData = {
      'id': transactionId,
      'title': selectedCategory,
      'description': note,
      'date': transactionDate.toIso8601String(),
      'amount': amountValue,
      'icon': categories[selectedType]!.firstWhere((c) => c['id'] == selectedCategoryId)['icon'],
      'type': selectedType == 'Income' ? 'income' : 'outcome',
    };

    // Update Weekly Cache
    final weekStart = _getWeekStart(transactionDate);
    final weekNumber = _getWeekNumber(transactionDate);
    final weekKey = '${transactionDate.year}_$weekNumber';
    
    List<Map<String, dynamic>> weeklyTransactions = [];
    final cachedWeeklyTx = prefs.getString('transactions_weekly_$weekKey');
    if (cachedWeeklyTx != null) {
      weeklyTransactions = List<Map<String, dynamic>>.from(jsonDecode(cachedWeeklyTx));
    }
    weeklyTransactions.add(transactionData);
    await prefs.setString('transactions_weekly_$weekKey', jsonEncode(weeklyTransactions));
    
    final weeklyBalance = prefs.getDouble('balance_weekly_$weekKey') ?? 0.0;
    await prefs.setDouble('balance_weekly_$weekKey', weeklyBalance + amountValue);

    // Update Monthly Cache
    final monthKey = '${transactionDate.year}_${transactionDate.month}';
    
    List<Map<String, dynamic>> monthlyTransactions = [];
    final cachedMonthlyTx = prefs.getString('transactions_monthly_$monthKey');
    if (cachedMonthlyTx != null) {
      monthlyTransactions = List<Map<String, dynamic>>.from(jsonDecode(cachedMonthlyTx));
    }
    monthlyTransactions.add(transactionData);
    await prefs.setString('transactions_monthly_$monthKey', jsonEncode(monthlyTransactions));
    
    final monthlyBalance = prefs.getDouble('balance_monthly_$monthKey') ?? 0.0;
    await prefs.setDouble('balance_monthly_$monthKey', monthlyBalance + amountValue);

    // Update Yearly Cache
    final yearKey = '${transactionDate.year}';
    
    List<Map<String, dynamic>> yearlyTransactions = [];
    final cachedYearlyTx = prefs.getString('transactions_yearly_$yearKey');
    if (cachedYearlyTx != null) {
      yearlyTransactions = List<Map<String, dynamic>>.from(jsonDecode(cachedYearlyTx));
    }
    yearlyTransactions.add(transactionData);
    await prefs.setString('transactions_yearly_$yearKey', jsonEncode(yearlyTransactions));
    
    final yearlyBalance = prefs.getDouble('balance_yearly_$yearKey') ?? 0.0;
    await prefs.setDouble('balance_yearly_$yearKey', yearlyBalance + amountValue);
  }

  Future<void> _navigateToCorrectPeriod(DateTime transactionDate) async {
    final now = DateTime.now();
    
    if (transactionDate.year != now.year) {
      Navigator.pushReplacementNamed(context, '/home_year');
    } else if (transactionDate.month != now.month) {
      Navigator.pushReplacementNamed(context, '/home_month');
    } else {
      final nowWeekStart = _getWeekStart(now);
      final txWeekStart = _getWeekStart(transactionDate);
      
      if (nowWeekStart != txWeekStart) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    }
  }

  DateTime _getWeekStart(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  int _getWeekNumber(DateTime date) {
    final firstJan = DateTime(date.year, 1, 1);
    final days = date.difference(firstJan).inDays;
    return ((days + firstJan.weekday) / 7).ceil();
  }

  Widget _buildKeypadButton(String label, {VoidCallback? onTap, Widget? icon}) {
    return Padding(
      padding: const EdgeInsets.all(6.0),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFEF6FF),
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.all(20),
          elevation: 0,
        ),
        child: icon ?? Text(
          label,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    final List<List<dynamic>> keypadLayout = [
      [
        {'label': 'Today', 'span': 2},
        {'label': '+', 'icon': Icons.add},
        {'label': 'check', 'icon': Icons.check_circle_rounded}
      ],
      [
        {'label': '×', 'icon': Icons.close},
        {'label': '7'},
        {'label': '8'},
        {'label': '9'}
      ],
      [
        {'label': '−', 'icon': Icons.remove},
        {'label': '4'},
        {'label': '5'},
        {'label': '6'}
      ],
      [
        {'label': '÷'},
        {'label': '1'},
        {'label': '2'},
        {'label': '3'}
      ],
      [
        {'label': 'delete', 'icon': Icons.backspace},
        {'label': '.'},
        {'label': '0'},
        {'label': '='}
      ],
    ];

    return Container(
      color: const Color(0xFF724E99),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: keypadLayout.map((row) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((item) {
              final label = item['label'] as String;
              final icon = item['icon'] as IconData?;
              final span = item['span'] as int? ?? 1;
              return Expanded(
                flex: span,
                child: _buildKeypadButton(
                  label,
                  onTap: () async {
                    if (label == 'Today') {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        builder: (context, child) {
                          return Theme(
                            data: ThemeData.light().copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: Color(0xFF724E99),
                                onPrimary: Colors.white,
                                surface: Color(0xFFFEF6FF),
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (pickedDate != null) {
                        setState(() {
                          selectedDate = pickedDate;
                        });
                      }
                    } else if (label == 'check') {
                      await _onConfirmPressed();
                    } else if (label == 'delete') {
                      _onDeletePressed();
                    } else if (label == '=') {
                      _onEqualsPressed();
                    } else if (RegExp(r'^\d+$|\.').hasMatch(label)) {
                      _onNumberPressed(label);
                    } else {
                      _onOperatorPressed(label);
                    }
                  },
                  icon: icon != null ? Icon(icon, color: Colors.black) : null,
                ),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String displayAmount;
    if (RegExp(r'[×\+\−\÷]').hasMatch(amount)) {
      final result = _evaluateExpression(amount);
      displayAmount = NumberFormat('#,##0.##', 'id_ID').format(result);
    } else {
      final parsedAmount = double.tryParse(amount) ?? 0;
      displayAmount = NumberFormat('#,##0.##', 'id_ID').format(parsedAmount);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFEF6FF),
      body: isSubmitting || isLoadingCategories
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: types.map((type) {
                      final isSelected = selectedType == type;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedType = type;
                            selectedCategory = null;
                            selectedCategoryId = null;
                            amount = '0';
                            note = '';
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF724E99) : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            type == 'Expenses' ? 'Expenses' : 'Income',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: isSelected ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  if (selectedType != null)
                    Expanded(
                      child: categories[selectedType]!.isEmpty
                          ? const Center(
                              child: Text('Tidak ada kategori tersedia',
                                  style: TextStyle(fontFamily: 'Poppins')))
                          : SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: GridView.count(
                                  crossAxisCount: 4,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  children: categories[selectedType]!.map((category) {
                                    final isSelected = selectedCategory == category['label'];
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          selectedCategory = category['label'];
                                          selectedCategoryId = category['id'];
                                        });
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: isSelected ? const Color(0xFF724E99) : Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            if (category['icon'].isNotEmpty)
                                              FutureBuilder<String?>(
                                                future: _getToken(),
                                                builder: (context, snapshot) {
                                                  if (!snapshot.hasData || snapshot.data == null) {
                                                    return const Icon(Icons.category, size: 40);
                                                  }
                                                  return SvgPicture.network(
                                                    category['icon'].startsWith('http')
                                                        ? category['icon']
                                                        : 'http://3.1.207.173/storage/${category['icon']}',
                                                    headers: {
                                                      'Authorization': 'Bearer ${snapshot.data}',
                                                      'Accept': 'application/json',
                                                    },
                                                    width: 40,
                                                    height: 40,
                                                    colorFilter: ColorFilter.mode(
                                                      isSelected ? Colors.white : Colors.black,
                                                      BlendMode.srcIn,
                                                    ),
                                                    placeholderBuilder: (context) => const Icon(Icons.category, size: 40),
                                                  );
                                                },
                                              )
                                            else
                                              Icon(
                                                Icons.category,
                                                size: 40,
                                                color: isSelected ? Colors.white : Colors.black,
                                              ),
                                            const SizedBox(height: 6),
                                            Text(
                                              category['label'],
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontFamily: 'Poppins',
                                                color: isSelected ? Colors.white : Colors.black,
                                              ),
                                              textAlign: TextAlign.center,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                    ),
                  if (selectedType != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: 'Note',
                          labelStyle: const TextStyle(color: Colors.black, fontFamily: 'Poppins'),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF724E99), width: 2),
                          ),
                        ),
                        style: const TextStyle(color: Colors.black, fontFamily: 'Poppins'),
                        onChanged: (val) => setState(() => note = val),
                        controller: TextEditingController(text: note)
                          ..selection = TextSelection.fromPosition(TextPosition(offset: note.length)),
                      ),
                    ),
                  if (selectedType != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (RegExp(r'[×\+\−\÷]').hasMatch(amount))
                            Text(
                              amount,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          Text(
                            '(IDR) $displayAmount',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF724E99),
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (selectedDate != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, right: 16),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Tanggal: ${DateFormat('dd/MM/yyyy').format(selectedDate!)}',
                          style: const TextStyle(
                            color: Color(0xFF724E99),
                            fontFamily: 'Poppins',
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  if (selectedType != null) _buildKeypad(),
                ],
              ),
            ),
    );
  }
}
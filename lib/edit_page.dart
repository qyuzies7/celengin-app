import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

const apiBaseUrl = 'http://10.0.2.2:8000/api';

class EditPage extends StatefulWidget {
  const EditPage({super.key});

  @override
  State<EditPage> createState() => _EditPageState();
}

class _EditPageState extends State<EditPage> {
  String? selectedType;
  String? selectedCategory;
  int? selectedCategoryId;
  String amount = '0';
  String note = '';
  DateTime? selectedDate;
  Map<String, dynamic>? transaction;
  bool isLoadingCategories = true;
  bool isSubmitting = false;

  final List<String> types = ['Expenses', 'Income'];
  Map<String, List<Map<String, dynamic>>> categories = {
    'Expenses': [],
    'Income': [],
  };

  @override
  void initState() {
    super.initState();
    _initializeState();
  }

  Future<void> _initializeState() async {
    await fetchCategories();
    if (mounted) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        setState(() {
          transaction = args;
          selectedType = args['type'] == 'income' ? 'Income' : 'Expenses';
          selectedCategory = args['title']?.toString();
          // Validasi amount
          final rawAmount = args['amount'];
          amount = (rawAmount is num ? rawAmount.abs().toString() : '0');
          note = args['description']?.toString() ?? '';
          selectedDate = args['date'] is String ? DateTime.tryParse(args['date']) : args['date'] as DateTime?;
          debugPrint('Initialized transaction: type=$selectedType, category=$selectedCategory, amount=$amount');
        });
      } else {
        debugPrint('No transaction data found in arguments');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No transaction data provided')),
        );
        Navigator.pop(context);
      }
    }
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
    debugPrint('Token retrieved: $token');
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

      final incomeRes = await http.get(Uri.parse('$apiBaseUrl/income'), headers: headers);
      final outcomeRes = await http.get(Uri.parse('$apiBaseUrl/outcome'), headers: headers);

      debugPrint('Income response: ${incomeRes.statusCode}');
      debugPrint('Outcome response: ${outcomeRes.statusCode}');

      if (incomeRes.statusCode == 200 && outcomeRes.statusCode == 200) {
        final incomeData = jsonDecode(incomeRes.body);
        final outcomeData = jsonDecode(outcomeRes.body);

        final incomeList = incomeData is List ? incomeData : incomeData['data'] ?? [];
        final outcomeList = outcomeData is List ? outcomeData : outcomeData['data'] ?? [];

        setState(() {
          categories['Income'] = incomeList.map<Map<String, dynamic>>((e) {
            return {
              'id': e['id'],
              'label': e['nama']?.toString() ?? 'Unknown',
              'icon': e['icon']?.toString() ?? '',
            };
          }).toList();
          categories['Expenses'] = outcomeList.map<Map<String, dynamic>>((e) {
            return {
              'id': e['id'],
              'label': e['nama']?.toString() ?? 'Unknown',
              'icon': e['icon']?.toString() ?? '',
            };
          }).toList();
          isLoadingCategories = false;

          // Revalidate selected category
          if (transaction != null && selectedType != null && selectedCategory != null) {
            final categoryList = categories[selectedType!] ?? [];
            final category = categoryList.firstWhere(
              (cat) => cat['label'].toLowerCase() == selectedCategory!.toLowerCase(),
              orElse: () => {},
            );
            if (category.isNotEmpty && category['id'] != null) {
              selectedCategoryId = category['id'];
              debugPrint('Revalidated category: ${category['label']} with ID: ${category['id']}');
            } else {
              debugPrint('Category not found for title: $selectedCategory');
              selectedCategory = null;
              selectedCategoryId = null;
            }
          }
        });
      } else if (incomeRes.statusCode == 401 || outcomeRes.statusCode == 401) {
        if (mounted) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('token');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sesi kadaluarsa, silakan login kembali')),
          );
          Navigator.pushReplacementNamed(context, '/login');
        }
      } else {
        throw Exception('Gagal memuat kategori: Income(${incomeRes.statusCode}), Outcome(${outcomeRes.statusCode})');
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
      debugPrint('Error fetching categories: $e');
    }
  }

  void _onNumberPressed(String value) {
    setState(() {
      if (value == '.' && amount.contains('.')) return;
      if (amount == '0' && value != '.') amount = ''; // Hapus leading zero
      amount += value;
      final cleanedAmount = amount.replaceAll(RegExp(r'[×\+\−\÷]'), '');
      if (cleanedAmount.isNotEmpty && double.tryParse(cleanedAmount) == null) {
        amount = amount.substring(0, amount.length - 1); // Batalkan input tidak valid
      }
    });
  }

  void _onOperatorPressed(String op) {
    setState(() {
      if (amount.isNotEmpty && !RegExp(r'[×\+\−\÷]$').hasMatch(amount)) {
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

  Future<void> _onConfirmPressed() async {
    final cleanedAmount = amount.replaceAll(RegExp(r'[×\+\−\÷]'), '');
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
    if (selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih tanggal!')),
      );
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    final jenis = selectedType == 'Income' ? 'income' : 'outcome';
    final data = {
      'jenis': jenis,
      selectedType == 'Income' ? 'income_id' : 'outcome_id': selectedCategoryId,
      'nominal': double.parse(cleanedAmount) * (selectedType == 'Expenses' ? -1 : 1),
      'keterangan': note,
      'tanggal': DateFormat('yyyy-MM-dd HH:mm:ss').format(selectedDate!),
    };

    debugPrint('Mengirim data: ${jsonEncode(data)}');

    try {
      final token = await _getToken();
      if (token == null) return;

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      };

      final response = await http.put(
        Uri.parse('$apiBaseUrl/transaksi/${transaction?['id']}'),
        headers: headers,
        body: jsonEncode(data),
      );

      debugPrint('Respons: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transaksi berhasil diperbarui!')),
          );
          Navigator.pop(context, true);
        }
      } else {
        String errorMessage = 'Gagal memperbarui transaksi: ${response.statusCode}';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['message'] ?? errorMessage;
        } catch (_) {}
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
      debugPrint('Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
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
        child: icon ??
            Text(
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
                              dialogBackgroundColor: Colors.white,
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
                      // Tidak ada aksi untuk '=' saat ini
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
    final cleanedAmount = amount.replaceAll(RegExp(r'[×\+\−\÷]'), '');
    final displayAmount = cleanedAmount.isEmpty || double.tryParse(cleanedAmount) == null
        ? '0'
        : NumberFormat('#,##0', 'id_ID').format(double.parse(cleanedAmount));

    return Scaffold(
      backgroundColor: const Color(0xFFFEF6FF),
      appBar: AppBar(
        title: const Text('Edit Transaction', style: TextStyle(fontFamily: 'Poppins')),
        backgroundColor: const Color(0xFF724E99),
        foregroundColor: Colors.white,
      ),
      body: isSubmitting || isLoadingCategories
          ? const Center(child: CircularProgressIndicator())
          : transaction == null
              ? const Center(child: Text('No transaction data', style: TextStyle(fontFamily: 'Poppins')))
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
                                                            : 'http://10.0.2.2:8000/storage/${category['icon']}',
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
                                                        errorBuilder: (context, error, stackTrace) {
                                                          debugPrint('SVG load error: $error');
                                                          return const Icon(Icons.image_not_supported, size: 40);
                                                        },
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
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF724E99), width: 2),
                              ),
                              focusedBorder: OutlineInputBorder(
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
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              '(IDR) $displayAmount',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF724E99),
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ),
                      if (selectedDate != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8, right: 16),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'Date: ${DateFormat('dd/MM/yyyy').format(selectedDate!)}',
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
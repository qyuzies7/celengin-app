import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AddPage extends StatefulWidget {
  const AddPage({Key? key}) : super(key: key);

  @override
  State<AddPage> createState() => _AddPageState();
}

class _AddPageState extends State<AddPage> {
  String? selectedType;
  String? selectedCategory;
  String amount = '';
  String note = '';

  final List<String> types = ['Expenses', 'Income'];

  final Map<String, List<Map<String, dynamic>>> categories = {
    'Expenses': [
      {'label': 'Food', 'icon': 'assets/icons/drink.svg'},
      {'label': 'Shopping', 'icon': 'assets/icons/shopping.svg'},
      {'label': 'Laundry', 'icon': 'assets/icons/laundry.svg'},
      {'label': 'Health', 'icon': 'assets/icons/health.svg'},
      {'label': 'Hangout', 'icon': 'assets/icons/hangout.svg'},
    ],
    'Income': [
      {'label': 'Parents', 'icon': 'assets/icons/parents.svg'},
      {'label': 'Scholar', 'icon': 'assets/icons/scholar.svg'},
    ],
  };

  void _onNumberPressed(String value) {
    setState(() {
      amount += value;
    });
  }

  void _onDeletePressed() {
    setState(() {
      if (amount.isNotEmpty) {
        amount = amount.substring(0, amount.length - 1);
      }
    });
  }

  void _onConfirmPressed() {
    print("Saved: Type=$selectedType, Category=$selectedCategory, Amount=$amount, Note=$note");
  }

  Widget _buildKeypadButton(String label,
      {VoidCallback? onTap, Color? color, Color? textColor, Widget? icon}) {
    return Padding(
      padding: const EdgeInsets.all(6.0),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? const Color(0xFFFEF6FF),
          foregroundColor: textColor ?? Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(20),
          elevation: 0,
        ),
        child: icon ??
            Text(
              label,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Container(
      color: const Color(0xFF724E99),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildKeypadButton(
                  'Today',
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (pickedDate != null) {
                      setState(() {
                        note = '${pickedDate.day}/${pickedDate.month}/${pickedDate.year}';
                      });
                    }
                  },
                ),
              ),
              Expanded(child: _buildKeypadButton('+', onTap: () => _onNumberPressed('+'))),
              Expanded(
                child: _buildKeypadButton(
                  '',
                  onTap: _onConfirmPressed,
                  icon: const Icon(Icons.check, color: Colors.black),
                ),
              ),
            ],
          ),
          Row(
            children: ['×', '7', '8', '9']
                .map((label) => Expanded(child: _buildKeypadButton(label, onTap: () => _onNumberPressed(label))))
                .toList(),
          ),
          Row(
            children: ['÷', '4', '5', '6']
                .map((label) => Expanded(child: _buildKeypadButton(label, onTap: () => _onNumberPressed(label))))
                .toList(),
          ),
          Row(
            children: ['-', '1', '2', '3']
                .map((label) => Expanded(child: _buildKeypadButton(label, onTap: () => _onNumberPressed(label))))
                .toList(),
          ),
          Row(
            children: ['+', '.', '0', 'x']
                .map((label) => Expanded(
                      child: _buildKeypadButton(label, onTap: () {
                        if (label == 'x') {
                          _onDeletePressed();
                        } else {
                          _onNumberPressed(label);
                        }
                      }),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEF6FF),
      body: SafeArea(
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
                      amount = '';
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
                      type,
                      style: TextStyle(
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
                child: SingleChildScrollView(
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
                                SvgPicture.asset(
                                  category['icon'],
                                  width: 24,
                                  height: 24,
                                  colorFilter: ColorFilter.mode(
                                    isSelected ? Colors.white : Colors.black,
                                    BlendMode.srcIn,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  category['label'],
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isSelected ? Colors.white : Colors.black,
                                  ),
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
                    labelStyle: const TextStyle(color: Colors.black),
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
                  style: const TextStyle(color: Colors.black),
                  onChanged: (val) => setState(() => note = val),
                ),
              ),

            if (selectedType != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '(IDR) ${amount.isEmpty ? '0' : amount}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF724E99),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),

            if (selectedType != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildKeypad(),
              ),
          ],
        ),
      ),
    );
  }
}

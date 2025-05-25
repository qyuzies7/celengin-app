import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:math_expressions/math_expressions.dart';

class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key});

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  String amount = '';
  int weeklyBudget = 0;
  int monthlyBudget = 0;
  String currentMode = ''; // 'weekly' atau 'monthly'

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
    setState(() {
      int parsedAmount = int.tryParse(amount.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      if (currentMode == 'weekly') {
        weeklyBudget = parsedAmount;
      } else if (currentMode == 'monthly') {
        monthlyBudget = parsedAmount;
      }
      amount = '';
      currentMode = '';
    });
  }

  void _onTodayPressed() async {
    DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selectedDate != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Selected date: ${selectedDate.toLocal()}'.split(' ')[0])),
      );
    }
  }

  String evaluateExpression(String input) {
    try {
      String sanitized = input.replaceAll('×', '*').replaceAll('÷', '/').replaceAll('−', '-');
      Parser p = Parser();
      Expression exp = p.parse(sanitized);
      ContextModel cm = ContextModel();
      double eval = exp.evaluate(EvaluationType.REAL, cm);
      return eval.toStringAsFixed(eval.truncateToDouble() == eval ? 0 : 2);
    } catch (e) {
      return 'Error';
    }
  }

  Widget _buildBudgetTile({required String label, required int amountValue, required String mode}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
            const SizedBox(height: 8),
            Text('IDR $amountValue',
                style: const TextStyle(
                  fontSize: 20,
                  color: Color(0xFF724E99),
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                )),
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
              controller: TextEditingController(text: amount),
              style: const TextStyle(fontFamily: 'Poppins'),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    currentMode = mode;
                    _onConfirmPressed();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF724E99),
                  foregroundColor: Colors.white,
                ),
                child: const Text('SAVE BUDGET', style: TextStyle(fontFamily: 'Poppins')),
              ),
            ),
            if (currentMode == mode)
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

  Widget _buildKeypadButton(String label, {VoidCallback? onTap, Color? color, Color? textColor, Widget? icon}) {
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
                fontFamily: 'Poppins',
              ),
            ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        color: const Color(0xFF724E99),
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: _buildKeypadButton('Today', onTap: _onTodayPressed)),
                Expanded(child: _buildKeypadButton('+', onTap: () => _onNumberPressed('+'))),
                Expanded(child: _buildKeypadButton('', onTap: _onConfirmPressed, icon: const Icon(Icons.check, color: Colors.black))),
              ],
            ),
            Row(
              children: ['×', '7', '8', '9'].map((label) => Expanded(child: _buildKeypadButton(label, onTap: () => _onNumberPressed(label)))).toList(),
            ),
            Row(
              children: ['−', '4', '5', '6'].map((label) => Expanded(child: _buildKeypadButton(label, onTap: () => _onNumberPressed(label)))).toList(),
            ),
            Row(
              children: ['÷', '1', '2', '3'].map((label) => Expanded(child: _buildKeypadButton(label, onTap: () => _onNumberPressed(label)))).toList(),
            ),
            Row(
              children: [
                Expanded(child: _buildKeypadButton('', onTap: _onDeletePressed, icon: const Icon(Icons.backspace_outlined, color: Colors.black))),
                Expanded(child: _buildKeypadButton('.', onTap: () => _onNumberPressed('.'))),
                Expanded(child: _buildKeypadButton('0', onTap: () => _onNumberPressed('0'))),
                Expanded(child: _buildKeypadButton('=', onTap: () => setState(() => amount = evaluateExpression(amount)))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEF6FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF724E99),
        title: const Text('Budgeting', style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 320),
            child: Column(
              children: [
                const SizedBox(height: 16),
                _buildBudgetTile(label: 'Weekly Budget Limit', amountValue: weeklyBudget, mode: 'weekly'),
                _buildBudgetTile(label: 'Monthly Budget Limit', amountValue: monthlyBudget, mode: 'monthly'),
              ],
            ),
          ),
          if (currentMode.isNotEmpty) _buildKeypad(),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

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
      int parsedAmount = int.tryParse(amount) ?? 0;
      if (currentMode == 'weekly') {
        weeklyBudget = parsedAmount;
      } else if (currentMode == 'monthly') {
        monthlyBudget = parsedAmount;
      }
      amount = '';
      currentMode = '';
    });
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
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('IDR $amountValue',
                style: const TextStyle(
                  fontSize: 20,
                  color: Color(0xFF724E99),
                  fontWeight: FontWeight.bold,
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
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              controller: TextEditingController(text: amount),
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
                child: const Text('SAVE BUDGET'),
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
              ),
            ),
      ),
    );
  }

  Widget _buildKeypad() {
    if (currentMode.isEmpty) return const SizedBox(); // Tidak tampil jika tidak aktif

    return Container(
      color: const Color(0xFF724E99),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          Row(
            children: ['7', '8', '9']
                .map((label) => Expanded(child: _buildKeypadButton(label, onTap: () => _onNumberPressed(label))))
                .toList(),
          ),
          Row(
            children: ['4', '5', '6']
                .map((label) => Expanded(child: _buildKeypadButton(label, onTap: () => _onNumberPressed(label))))
                .toList(),
          ),
          Row(
            children: ['1', '2', '3']
                .map((label) => Expanded(child: _buildKeypadButton(label, onTap: () => _onNumberPressed(label))))
                .toList(),
          ),
          Row(
            children: [
              Expanded(child: _buildKeypadButton('0', onTap: () => _onNumberPressed('0'))),
              Expanded(
                  child: _buildKeypadButton('', onTap: _onDeletePressed, icon: const Icon(Icons.backspace_outlined))),
              Expanded(
                  child: _buildKeypadButton('', onTap: _onConfirmPressed, icon: const Icon(Icons.check_circle_outline))),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEF6FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF724E99),
        title: const Text('Budgeting', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 16),
            _buildBudgetTile(label: 'Weekly Budget Limit', amountValue: weeklyBudget, mode: 'weekly'),
            _buildBudgetTile(label: 'Monthly Budget Limit', amountValue: monthlyBudget, mode: 'monthly'),
            if (currentMode.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
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
            if (currentMode.isNotEmpty) _buildKeypad(),
          ],
        ),
      ),
    );
  }
}

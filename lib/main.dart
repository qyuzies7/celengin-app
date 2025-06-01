import 'package:flutter/material.dart';
import 'login_page.dart';
import 'register_page.dart';
import 'home_page.dart';
import 'home_month.dart' as month;
import 'home_year.dart' as year;
import 'add_page.dart';
import 'edit_page.dart';
import 'chart_page.dart';
import 'budget_page.dart';

void main() {
  runApp(const CelenginApp());
}

class CelenginApp extends StatelessWidget {
  const CelenginApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Celengin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        fontFamily: 'Poppins',
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/home': (context) => const HomePage(),
        '/home_month': (context) => const month.HomeMonthPage(),
        '/home_year': (context) => const year.HomeYearPage(),
        '/add_page': (context) => const AddPage(),
        '/edit_page': (context) => const EditPage(),
        '/chart_page': (context) => const ChartPage(),
        '/budget_page': (context) => const BudgetPage(),
      },
    );
  }
}
import 'package:flutter/material.dart';
import 'login_page.dart';
import 'register_page.dart';
import 'home_page.dart';
import 'home_month.dart';
import 'home_year.dart';
import 'add_page.dart';
import 'chart_page.dart';


void main() {
  runApp(CelenginApp());
}

class CelenginApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Celengin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => LoginPage(),
        '/register': (context) => RegisterPage(),
        '/home': (context) => HomePage(),
        '/home_month': (context) => HomeMonthPage(),
        '/home_year': (context) => HomeYearPage(),
        '/add_page': (context) => AddPage(),
        '/chart_page': (context) => ChartPage(),
        
      },
    );
  }
}

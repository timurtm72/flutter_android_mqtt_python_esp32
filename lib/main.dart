import 'package:flutter/material.dart';
import 'login_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Корневой виджет приложения
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Умный дом',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Настройки темы приложения
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
        // Настройки шрифтов и других параметров темы
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

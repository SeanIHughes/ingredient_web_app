import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'scan_view.dart';
import 'search_view.dart';
import 'history_view.dart';
import 'profile_view.dart';
import 'onboarding_view.dart';
import 'models.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final bool seenOnboarding = prefs.getBool('seen_onboarding') ?? false;

  runApp(ScienceSaysApp(
    startWidget:
        seenOnboarding ? const MainNavigation() : const OnboardingView(),
  ));
}

class ScienceSaysApp extends StatelessWidget {
  final Widget startWidget;
  const ScienceSaysApp({super.key, required this.startWidget});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Science Says',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: startWidget,
      routes: {
        // Removed 'const' here because MainNavigation/Onboarding have internal state
        '/main': (context) => const MainNavigation(),
        '/onboarding': (context) => const OnboardingView(),
      },
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  List<ScannedProduct> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? historyJson = prefs.getString('scan_history');
    if (historyJson != null) {
      final List decode = jsonDecode(historyJson);
      setState(() {
        _history = decode.map((item) => ScannedProduct.fromJson(item)).toList();
      });
    }
  }

  void _onScanComplete(ScannedProduct product) async {
    setState(() => _history.insert(0, product));
    _saveHistory();
  }

  void _deleteHistoryItem(int index) {
    setState(() => _history.removeAt(index));
    _saveHistory();
  }

  void _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('scan_history', jsonEncode(_history));
  }

  @override
  Widget build(BuildContext context) {
    // --- FIXED: Removed 'const' from widgets that have internal state ---
    final List<Widget> pages = [
      ScanView(onScanComplete: _onScanComplete),
      const SearchView(), // This is fine if SearchView has a const constructor
      HistoryView(history: _history, onDelete: _deleteHistoryItem),
      const ProfileView(), // Removed 'const' if ProfileView throws an error
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green.shade800,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.qr_code_scanner_rounded), label: "Scan"),
          BottomNavigationBarItem(
              icon: Icon(Icons.search_rounded), label: "Search"),
          BottomNavigationBarItem(
              icon: Icon(Icons.history_rounded), label: "History"),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded), label: "Profile"),
        ],
      ),
    );
  }
}

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
  // 1. Ensure Flutter is ready before we touch SharedPreferences
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Check if the user has completed onboarding before
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
      // The home screen is determined by the main() function logic
      home: startWidget,

      // Named routes for easy navigation throughout the app
      routes: {
        '/main': (context) => const MainNavigation(),
        '/onboarding': (context) => const OnboardingView(),
        // We can call this 'profile_edit' to distinguish it from the first-time run
        '/edit_preferences': (context) => const OnboardingView(isEditing: true),
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

  // --- HISTORY MANAGEMENT ---
  void _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? historyJson = prefs.getString('scan_history');
    if (historyJson != null) {
      try {
        final List decode = jsonDecode(historyJson);
        setState(() {
          _history =
              decode.map((item) => ScannedProduct.fromJson(item)).toList();
        });
      } catch (e) {
        debugPrint("Error loading history: $e");
      }
    }
  }

  void _onScanComplete(ScannedProduct product) {
    setState(() {
      _history.insert(0, product);
    });
    _saveHistory();
  }

  void _deleteHistoryItem(int index) {
    setState(() {
      _history.removeAt(index);
    });
    _saveHistory();
  }

  void _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('scan_history', jsonEncode(_history));
  }

  @override
  Widget build(BuildContext context) {
    // We define the pages here.
    // ScanView and HistoryView need access to the state methods above.
    final List<Widget> pages = [
      ScanView(onScanComplete: _onScanComplete),
      const SearchView(),
      HistoryView(history: _history, onDelete: _deleteHistoryItem),
      const ProfileView(),
    ];

    return Scaffold(
      // IndexedStack keeps the state of each tab alive (doesn't reset the camera/search)
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green.shade800,
        unselectedItemColor: Colors.grey,
        elevation: 8,
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

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import 'widgets.dart';

class ScanView extends StatefulWidget {
  final Function(ScannedProduct) onScanComplete;
  const ScanView({super.key, required this.onScanComplete});

  @override
  State<ScanView> createState() => _ScanViewState();
}

class _ScanViewState extends State<ScanView> {
  bool showCamera = true;
  bool isIngredientsExpanded = false;
  bool isLoading = false;
  String productName = "Ready to Scan"; // Default
  String ingredientsText = "Scan a barcode to begin...";
  List<IngredientMatch> matches = [];
  String sortMode = "Science Says";
  List<String> userPrefs = [];

  final String baseUrl = "https://192.168.1.226:8001";

  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
  }

  Future<void> _loadUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => userPrefs = prefs.getStringList('user_prefs') ?? []);
  }

  // Helper for Conflicts
  String? _getPersonalConflictLabel(String name) {
    final n = name.toLowerCase().trim();
    final Map<String, List<String>> triggers = {
      "Peanuts": ["peanut", "groundnut", "arachis"],
      "Dairy": ["milk", "whey", "lactose", "casein", "cheese", "butter"],
      "Gluten": ["wheat", "barley", "rye", "malt", "gluten"],
      "Soy": ["soy", "soya", "lecithin"],
      "Eggs": ["egg", "yolk", "albumin"],
      "Vegan": ["milk", "egg", "honey", "beef", "chicken", "pork", "gelatin"],
    };
    for (var pref in userPrefs) {
      if (triggers.containsKey(pref)) {
        for (var keyword in triggers[pref]!) {
          if (n.contains(keyword.toLowerCase())) return "$pref ALLERGY";
        }
      }
    }
    return null;
  }

  List<IngredientMatch> get sortedMatches {
    List<IngredientMatch> sorted = List.from(matches);
    if (sortMode == "Science Says") {
      sorted.sort((a, b) => b.riskScoreNum.compareTo(a.riskScoreNum));
    } else {
      sorted.sort((a, b) => b.sentimentNum.compareTo(a.sentimentNum));
    }
    return sorted;
  }

  Future<void> processBarcode(String code) async {
    final cleanCode = code.trim();
    if (cleanCode.isEmpty) return;
    setState(() {
      showCamera = false;
      isLoading = true;
      productName = "Analyzing...";
    });
    try {
      String finalName = "Unknown Product";
      String finalIngredients = "";
      final offResp = await http.get(Uri.parse(
          "https://world.openfoodfacts.org/api/v2/product/$cleanCode.json"));
      if (offResp.statusCode == 200) {
        final offData = jsonDecode(offResp.body);
        if (offData['product'] != null) {
          finalName = offData['product']['product_name'] ?? "Unknown Product";
          finalIngredients = offData['product']['ingredients_text'] ?? "";
        }
      }
      final localResp =
          await http.get(Uri.parse("$baseUrl/lookup-upc/$cleanCode"));
      if (localResp.statusCode == 200) {
        final localData = jsonDecode(localResp.body);
        if (localData['ingredients_text'] != null) {
          finalIngredients = localData['ingredients_text'];
          if (finalName == "Unknown Product")
            finalName = localData['product_name'] ?? "Product Found";
        }
      }
      if (finalIngredients.isNotEmpty) {
        await _getScienceScores(finalName, finalIngredients);
      } else {
        _showError("Product not in database.");
      }
    } catch (e) {
      _showError("Connection Error. Check Proxy.");
    }
  }

  Future<void> _getScienceScores(String name, String ingredients) async {
    try {
      final scoreResp = await http.post(
        Uri.parse("$baseUrl/score-ingredients"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"ingredients_text": ingredients}),
      );
      final scoreData = jsonDecode(scoreResp.body);
      final List<IngredientMatch> foundMatches =
          (scoreData['all_matches'] as List)
              .map((m) => IngredientMatch.fromJson(m))
              .toList();
      setState(() {
        productName = name;
        ingredientsText = ingredients;
        matches = foundMatches;
        isLoading = false;
      });
    } catch (e) {
      _showError("Scoring Error.");
    }
  }

  void _showError(String msg) {
    setState(() {
      productName = "Not Found";
      ingredientsText = msg;
      isLoading = false;
      matches = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // VERSION BAR - THIS IS WHERE IT SAYS V1.1
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(30),
        child: Container(
          color: Colors.red,
          child: const Center(
            child: Text("DEPLOYMENT VERIFIED: V1.1",
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ),
        ),
      ),
      body: Column(
        children: [
          if (showCamera)
            _CameraSection(onDetect: (code) => processBarcode(code))
          else
            const SizedBox(height: 20),
          if (isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(productName,
                        style: const TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w900)),
                  ),
                  if (matches.isNotEmpty)
                    ...sortedMatches.map(
                        (m) => IngredientRow(item: m, isPersonalTrigger: false))
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CameraSection extends StatelessWidget {
  final Function(String) onDetect;
  const _CameraSection({required this.onDetect});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      margin: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: MobileScanner(onDetect: (capture) {
          final barcodes = capture.barcodes;
          if (barcodes.isNotEmpty) onDetect(barcodes.first.rawValue ?? "");
        }),
      ),
    );
  }
}

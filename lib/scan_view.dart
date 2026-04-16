import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import 'widgets.dart'; // IMPORTANT: This is where IngredientRow lives now

class ScanView extends StatefulWidget {
  final Function(ScannedProduct) onScanComplete;
  const ScanView({super.key, required this.onScanComplete});

  @override
  State<ScanView> createState() => _ScanViewState();
}

class _ScanViewState extends State<ScanView> {
  // --- State ---
  bool showCamera = true;
  bool isIngredientsExpanded = false;
  bool isLoading = false;
  String productName = "";
  String ingredientsText = "Scan a barcode to begin...";
  List<IngredientMatch> matches = [];
  String sortMode = "Science Says";
  List<String> userPrefs = [];

  final List<String> _allergyList = [
    "Peanuts",
    "Dairy",
    "Gluten",
    "Soy",
    "Eggs",
    "Shellfish"
  ];

  final Map<String, List<String>> _triggerKeywords = {
    "Peanuts": ["peanut", "groundnut", "arachis", "nut oil"],
    "Dairy": [
      "milk",
      "whey",
      "lactose",
      "casein",
      "cheese",
      "butter",
      "cream",
      "yogurt",
      "ghee"
    ],
    "Gluten": [
      "wheat",
      "barley",
      "rye",
      "malt",
      "gluten",
      "flour",
      "semolina",
      "spelt"
    ],
    "Soy": ["soy", "soya", "lecithin", "edamame", "tofu", "tempeh"],
    "Eggs": ["egg", "albumin", "yolk", "mayonnaise", "ovomucin"],
    "Shellfish": [
      "shrimp",
      "crab",
      "lobster",
      "prawn",
      "mussel",
      "clam",
      "scallop"
    ],
    "Vegan": [
      "milk",
      "egg",
      "honey",
      "beef",
      "chicken",
      "pork",
      "gelatin",
      "whey",
      "lard",
      "casein",
      "carmine",
      "fish",
      "anchovy",
      "tallow"
    ],
    "Vegetarian": [
      "beef",
      "chicken",
      "pork",
      "lard",
      "gelatin",
      "carmine",
      "fish"
    ],
  };

  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
  }

  Future<void> _loadUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => userPrefs = prefs.getStringList('user_prefs') ?? []);
  }

  String? _getPersonalConflictLabel(String name) {
    final n = name.toLowerCase().trim();
    for (var pref in userPrefs) {
      if (_triggerKeywords.containsKey(pref)) {
        for (var keyword in _triggerKeywords[pref]!) {
          if (n.contains(keyword.toLowerCase())) {
            String category = _allergyList.contains(pref) ? "ALLERGY" : "DIET";
            return "${pref.toUpperCase()} $category";
          }
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
    setState(() {
      showCamera = false;
      isLoading = true;
      productName = "Analyzing...";
    });
    try {
      String finalName = "Unknown Product";
      String finalIngredients = "";

      final offResp = await http.get(Uri.parse(
          "https://world.openfoodfacts.org/api/v2/product/$code.json"));
      final offData = jsonDecode(offResp.body);
      if (offData['product'] != null) {
        finalName = offData['product']['product_name'] ?? "Unknown Product";
        finalIngredients = offData['product']['ingredients_text'] ?? "";
      }

      final localResp = await http
          .get(Uri.parse("http://192.168.1.226:8000/lookup-upc/$code"));
      if (localResp.statusCode == 200) {
        final localData = jsonDecode(localResp.body);
        if (localData['ingredients_text'] != null &&
            localData['ingredients_text'].isNotEmpty) {
          finalIngredients = localData['ingredients_text'];
        }
      }

      if (finalIngredients.isNotEmpty) {
        await _getScienceScores(finalName, finalIngredients);
      } else {
        _showError("No ingredients found.");
      }
    } catch (e) {
      _showError("Connection Error.");
    }
  }

  Future<void> _getScienceScores(String name, String ingredients) async {
    final scoreResp = await http.post(
      Uri.parse("http://192.168.1.226:8000/score-ingredients"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"ingredients_text": ingredients}),
    );
    final scoreData = jsonDecode(scoreResp.body);
    final List<IngredientMatch> foundMatches =
        (scoreData['all_matches'] as List)
            .map((m) => IngredientMatch.fromJson(m))
            .toList();

    if (foundMatches.any((m) => _getPersonalConflictLabel(m.name) != null)) {
      HapticFeedback.vibrate();
    }

    setState(() {
      productName = name;
      ingredientsText = ingredients;
      matches = foundMatches;
      isLoading = false;
    });
    widget.onScanComplete(ScannedProduct(
        name: name,
        date: DateTime.now(),
        ingredients: ingredients,
        matches: foundMatches));
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
      body: Column(
        children: [
          if (showCamera)
            _CameraSection(onDetect: (code) => processBarcode(code))
          else
            const SizedBox(height: 60),
          if (isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                children: [
                  _Header(
                      productName: productName,
                      sortMode: sortMode,
                      onSortChange: (v) => setState(() => sortMode = v),
                      hasMatches: matches.isNotEmpty),
                  if (userPrefs.isNotEmpty && matches.isNotEmpty)
                    _PersonalAlertBanner(userPrefs: userPrefs),
                  _CollapsibleIngredients(
                      text: ingredientsText,
                      isExpanded: isIngredientsExpanded,
                      onTap: () => setState(() =>
                          isIngredientsExpanded = !isIngredientsExpanded)),
                  const SizedBox(height: 10),
                  ...sortedMatches.map((m) {
                    final conflictLabel = _getPersonalConflictLabel(m.name);
                    return IngredientRow(
                      item: m,
                      isPersonalTrigger: conflictLabel != null,
                      personalTriggerLabel: conflictLabel,
                    );
                  }),
                  const SizedBox(height: 80),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: !showCamera
          ? FloatingActionButton.extended(
              onPressed: () => setState(() {
                showCamera = true;
                productName = "";
                matches = [];
              }),
              backgroundColor: Colors.green.shade800,
              icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
              label: const Text("SCAN AGAIN",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }
}

// --- Supporting Widgets ---
class _CameraSection extends StatelessWidget {
  final Function(String) onDetect;
  const _CameraSection({required this.onDetect});
  @override
  Widget build(BuildContext context) {
    return Container(
        height: 320,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: Colors.greenAccent.withOpacity(0.5), width: 2)),
        clipBehavior: Clip.antiAlias,
        child: MobileScanner(onDetect: (capture) {
          if (capture.barcodes.isNotEmpty)
            onDetect(capture.barcodes.first.rawValue ?? "");
        }));
  }
}

class _PersonalAlertBanner extends StatelessWidget {
  final List<String> userPrefs;
  const _PersonalAlertBanner({required this.userPrefs});
  @override
  Widget build(BuildContext context) {
    return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withOpacity(0.2))),
        child: Row(children: [
          const Icon(Icons.shield_outlined, color: Colors.blue, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text("Guarding for: ${userPrefs.join(', ')}",
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.blue)))
        ]));
  }
}

class _Header extends StatelessWidget {
  final String productName, sortMode;
  final Function(String) onSortChange;
  final bool hasMatches;
  const _Header(
      {required this.productName,
      required this.sortMode,
      required this.onSortChange,
      required this.hasMatches});
  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(productName.isEmpty ? "Ready to Scan" : productName,
                    style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5)),
                const Text("VERIFIED BY SCIENCE SAYS™ ENGINE",
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        letterSpacing: 1))
              ])),
          if (hasMatches)
            DropdownButtonHideUnderline(
                child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12)),
                    child: DropdownButton<String>(
                        value: sortMode,
                        items: ["Science Says", "Social Says"]
                            .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(s,
                                    style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold))))
                            .toList(),
                        onChanged: (v) => onSortChange(v!))))
        ]));
  }
}

class _CollapsibleIngredients extends StatelessWidget {
  final String text;
  final bool isExpanded;
  final VoidCallback onTap;
  const _CollapsibleIngredients(
      {required this.text, required this.isExpanded, required this.onTap});
  @override
  Widget build(BuildContext context) {
    if (text == "Scan a barcode to begin...") return const SizedBox();
    return ListTile(
        dense: true,
        title: const Text("FULL INGREDIENT PANEL",
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey)),
        trailing:
            Icon(isExpanded ? Icons.expand_less : Icons.expand_more, size: 16),
        onTap: onTap);
  }
}

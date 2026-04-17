import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
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
  bool isLoading = false;
  String productName = "Ready to Scan"; 
  List<IngredientMatch> matches = [];
  final String baseUrl = "https://192.168.1.226:8001";

  Future<void> processBarcode(String code) async {
    final cleanCode = code.trim();
    if (cleanCode.isEmpty) return;
    
    setState(() {
      showCamera = false;
      isLoading = true;
      productName = "Analyzing...";
    });

    try {
      // 1. Open Food Facts
      final offResp = await http.get(Uri.parse("https://world.openfoodfacts.org/api/v2/product/$cleanCode.json"));
      String name = "Unknown Product";
      String ingredients = "";
      
      if (offResp.statusCode == 200) {
        final data = jsonDecode(offResp.body);
        if (data['product'] != null) {
          name = data['product']['product_name'] ?? "Unknown";
          ingredients = data['product']['ingredients_text'] ?? "";
        }
      }

      // 2. Score via Proxy
      if (ingredients.isNotEmpty) {
        final scoreResp = await http.post(
          Uri.parse("$baseUrl/score-ingredients"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"ingredients_text": ingredients}),
        );
        final scoreData = jsonDecode(scoreResp.body);
        setState(() {
          productName = name;
          matches = (scoreData['all_matches'] as List).map((m) => IngredientMatch.fromJson(m)).toList();
          isLoading = false;
        });
      } else {
        setState(() { productName = "Product Not Found"; isLoading = false; });
      }
    } catch (e) {
      setState(() { productName = "Scanner Error"; isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(30),
        child: Container(
          color: Colors.red,
          child: const Center(
            child: Text("V1.6 - RAW SCANNER (NO BUTTONS)",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
          ),
        ),
      ),
      body: Column(
        children: [
          if (showCamera)
            Container(
              height: 350, // Slightly larger for easier scanning
              margin: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: MobileScanner(
                  onDetect: (capture) {
                    final barcode = capture.barcodes.first.rawValue;
                    if (barcode != null) processBarcode(barcode);
                  },
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton(
                onPressed: () => setState(() { showCamera = true; matches = []; productName = "Ready to Scan"; }),
                child: const Text("Scan Another Item"),
              ),
            ),
          if (isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(productName, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                  ),
                  ...matches.map((m) => IngredientRow(item: m, isPersonalTrigger: false))
                ],
              ),
            ),
        ],
      ),
    );
  }
}
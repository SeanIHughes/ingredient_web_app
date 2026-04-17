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
      // 1. Fetch from Open Food Facts
      final offResp = await http.get(Uri.parse(
          "https://world.openfoodfacts.org/api/v2/product/$cleanCode.json"));
      String name = "Unknown Product";
      String ingredients = "";

      if (offResp.statusCode == 200) {
        final data = jsonDecode(offResp.body);
        if (data['product'] != null) {
          name = data['product']['product_name'] ?? "Unknown";
          ingredients = data['product']['ingredients_text'] ?? "";
        }
      }

      // 2. Score via Local Proxy
      if (ingredients.isNotEmpty) {
        final scoreResp = await http.post(
          Uri.parse("$baseUrl/score-ingredients"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"ingredients_text": ingredients}),
        );
        
        if (scoreResp.statusCode == 200) {
          final scoreData = jsonDecode(scoreResp.body);
          final List<IngredientMatch> foundMatches = (scoreData['all_matches'] as List)
              .map((m) => IngredientMatch.fromJson(m))
              .toList();

          setState(() {
            productName = name;
            matches = foundMatches;
            isLoading = false;
          });

          // --- HISTORY LOGIC: MATCHES YOUR MODELS.商 ---
          // Note: barcode is omitted because ScannedProduct doesn't have it.
          final newProduct = ScannedProduct(
            name: name,
            date: DateTime.now(), // Changed from scanDate to date
            ingredients: ingredients,
            matches: foundMatches,
          );
          
          widget.onScanComplete(newProduct);
          // ------------------------------------------

        } else {
          _showError("Scoring Error");
        }
      } else {
        _handleError("Product Not Found");
      }
    } catch (e) {
      _showError("Scanner Error/Connection Issues");
    }
  }

  void _showError(String msg) {
    setState(() {
      productName = msg;
      isLoading = false;
    });
  }

  void _handleError(String msg) {
    _showError(msg);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan Product", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          if (showCamera)
            Container(
              height: 350,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
              ),
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
              child: ElevatedButton.icon(
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text("Scan Another Item"),
                onPressed: () => setState(() {
                  showCamera = true;
                  matches = [];
                  productName = "Ready to Scan";
                }),
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
                    child: Text(productName,
                        style: const TextStyle(
                            fontSize: 26, fontWeight: FontWeight.bold)),
                  ),
                  ...matches.map(
                      (m) => IngredientRow(item: m, isPersonalTrigger: false))
                ],
              ),
            ),
        ],
      ),
    );
  }
}
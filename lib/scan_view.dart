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
      String finalName = "Unknown Product";
      String finalIngredients = "";

      // 1. Open Food Facts
      final offResp = await http.get(Uri.parse("https://world.openfoodfacts.org/api/v2/product/$cleanCode.json"));
      if (offResp.statusCode == 200) {
        final offData = jsonDecode(offResp.body);
        if (offData['product'] != null) {
          finalName = offData['product']['product_name'] ?? "Unknown";
          finalIngredients = offData['product']['ingredients_text'] ?? "";
        }
      }

      // 2. Local Proxy
      final localResp = await http.get(Uri.parse("$baseUrl/lookup-upc/$cleanCode"));
      if (localResp.statusCode == 200) {
        final localData = jsonDecode(localResp.body);
        if (localData['ingredients_text'] != null) {
          finalIngredients = localData['ingredients_text'];
          finalName = localData['product_name'] ?? finalName;
        }
      }

      if (finalIngredients.isNotEmpty) {
        final scoreResp = await http.post(
          Uri.parse("$baseUrl/score-ingredients"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"ingredients_text": finalIngredients}),
        );
        final scoreData = jsonDecode(scoreResp.body);
        setState(() {
          productName = finalName;
          matches = (scoreData['all_matches'] as List).map((m) => IngredientMatch.fromJson(m)).toList();
          isLoading = false;
        });
      } else {
        setState(() { productName = "Not Found"; isLoading = false; });
      }
    } catch (e) {
      setState(() { productName = "Connection Error"; isLoading = false; });
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
            child: Text("NULL-SAFE DEPLOYMENT: V1.4",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
          ),
        ),
      ),
      body: Column(
        children: [
          if (showCamera)
            _CameraSection(onDetect: (code) => processBarcode(code))
          else
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: ElevatedButton(
                onPressed: () => setState(() => showCamera = true),
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
                    child: Text(productName,
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
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

class _CameraSection extends StatefulWidget {
  final Function(String) onDetect;
  const _CameraSection({required this.onDetect});

  @override
  State<_CameraSection> createState() => _CameraSectionState();
}

class _CameraSectionState extends State<_CameraSection> {
  bool _activated = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: _activated 
          ? MobileScanner(
              // We do NOT pass a controller here. 
              // Letting the widget create its own internal controller 
              // is the safest way to avoid Null Check errors.
              onDetect: (capture) {
                final barcode = capture.barcodes.first.rawValue;
                if (barcode != null) widget.onDetect(barcode);
              },
            )
          : Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt),
                label: const Text("Start Scanner"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: () {
                  setState(() {
                    _activated = true;
                  });
                },
              ),
            ),
      ),
    );
  }
}
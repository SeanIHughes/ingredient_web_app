import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class IngredientMatch {
  final String name;
  final String? riskScore;
  final int riskScoreNum;
  final String? sentiment;
  final int sentimentNum;
  final String? classification;
  final String? summary;
  final String? synonyms;

  IngredientMatch({
    required this.name,
    this.riskScore,
    required this.riskScoreNum,
    this.sentiment,
    required this.sentimentNum,
    this.classification,
    this.summary,
    this.synonyms,
  });

  // This is the "Codable" equivalent for your Python JSON
  factory IngredientMatch.fromJson(Map<String, dynamic> json) {
    return IngredientMatch(
      name: json['name'] ?? "",
      riskScore: json['risk_score'],
      riskScoreNum: json['risk_score_num'] ?? 0,
      sentiment: json['sentiment'],
      sentimentNum: json['sentiment_num'] ?? 0,
      classification: json['classification'],
      summary: json['summary'],
      synonyms: json['synonyms'],
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'risk_score': riskScore,
    'risk_score_num': riskScoreNum,
    'sentiment': sentiment,
    'sentiment_num': sentimentNum,
    'classification': classification,
    'summary': summary,
    'synonyms': synonyms,
  };
}

class ScannedProduct {
  final String name;
  final DateTime date;
  final String ingredients;
  final List<IngredientMatch> matches;

  ScannedProduct({
    required this.name,
    required this.date,
    required this.ingredients,
    required this.matches,
  });

  factory ScannedProduct.fromJson(Map<String, dynamic> json) {
    return ScannedProduct(
      name: json['name'],
      date: DateTime.parse(json['date']),
      ingredients: json['ingredients'],
      matches: (json['matches'] as List)
          .map((i) => IngredientMatch.fromJson(i))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'date': date.toIso8601String(),
    'ingredients': ingredients,
    'matches': matches.map((m) => m.toJson()).toList(),
  };
}

class HistoryManager {
  static const String _key = "scanned_history";

  static Future<void> save(List<ScannedProduct> history) async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(history.map((p) => p.toJson()).toList());
    await prefs.setString(_key, encoded);
  }

  static Future<List<ScannedProduct>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_key);
    if (data == null) return [];
    final List decoded = jsonDecode(data);
    return decoded.map((p) => ScannedProduct.fromJson(p)).toList();
  }
}

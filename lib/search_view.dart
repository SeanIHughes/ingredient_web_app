import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'widgets.dart';

class SearchView extends StatefulWidget {
  const SearchView({super.key});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  // --- State Variables ---
  List<String> _suggestions = [];
  List<String> userPrefs = [];
  bool _isLoading = false;
  Timer? _debounce;
  final TextEditingController _controller = TextEditingController();

  final String _baseUrl = "http://192.168.1.226:8000";

  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
  }

  Future<void> _loadUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => userPrefs = prefs.getStringList('user_prefs') ?? []);
  }

  bool _isPersonalTrigger(String name) {
    final n = name.toLowerCase().trim();
    for (var pref in userPrefs) {
      if (n.contains(pref.toLowerCase().trim())) return true;
    }
    return false;
  }

  // --- IMPROVED: Type Safety & List Scrubber ---
  String _ensureString(dynamic value) {
    if (value == null) return "Not available";
    String result;
    if (value is List) {
      result = value.join(", ");
    } else {
      result = value.toString();
    }

    // Scrubber: Removes [' ', " "] and other artifacts from the database format
    return result
        .replaceAll("[", "")
        .replaceAll("]", "")
        .replaceAll("'", "")
        .replaceAll('"', "")
        .trim();
  }

  // --- Score Color Logic ---
  Color _getScienceColor(int score) {
    if (score >= 7) return Colors.red.shade700;
    if (score >= 4) return Colors.orange.shade700;
    return Colors.green.shade700;
  }

  Color _getSocialColor(int sentimentNum) {
    if (sentimentNum >= 3) return Colors.red.shade700;
    if (sentimentNum == 2) return Colors.orange.shade700;
    return Colors.green.shade700;
  }

  // --- API Logic ---

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (query.length >= 2) _fetchSuggestions(query);
    });
  }

  Future<void> _fetchSuggestions(String q) async {
    setState(() => _isLoading = true);
    try {
      final resp =
          await http.get(Uri.parse("$_baseUrl/suggest-ingredients?q=$q"));
      if (resp.statusCode == 200) {
        setState(() {
          _suggestions = (jsonDecode(resp.body) as List).cast<String>();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _showIngredientDetail(String name) async {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Analyzing $name..."),
        duration: const Duration(milliseconds: 500)));

    try {
      final url = Uri.parse("$_baseUrl/ingredient-detail")
          .replace(queryParameters: {'name': name});
      final resp = await http.get(url);

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);

        final match = IngredientMatch(
          name: _ensureString(data['name']),
          riskScore: _ensureString(data['risk_score']),
          riskScoreNum: data['risk_score_num'] ?? 0,
          sentiment: _ensureString(data['sentiment']),
          sentimentNum: data['sentiment_num'] ?? 2,
          summary: _ensureString(data['summary']),
        );

        if (!mounted) return;

        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => _ScienceDetailModal(
            item: match,
            isTrigger: _isPersonalTrigger(name),
            uses: _ensureString(data['uses']),
            safety: _ensureString(data['safety']),
            group: _ensureString(data['synonyms']),
            scienceColor: _getScienceColor(match.riskScoreNum),
            socialColor: _getSocialColor(match.sentimentNum),
          ),
        );
      }
    } catch (e) {
      print("Search Detail Error: $e");
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text("Science Search",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _controller,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: "Search (e.g. MSG, Red 40, Soy)",
                prefixIcon: const Icon(Icons.search, color: Colors.green),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _suggestions.length,
              separatorBuilder: (context, i) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final name = _suggestions[i];
                final isTrigger = _isPersonalTrigger(name);
                return ListTile(
                  leading: Icon(Icons.science,
                      color: isTrigger ? Colors.red : Colors.green),
                  title: Text(name,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color:
                              isTrigger ? Colors.red.shade900 : Colors.black)),
                  subtitle: isTrigger
                      ? const Text("PERSONAL CONFLICT",
                          style: TextStyle(
                              color: Colors.red,
                              fontSize: 10,
                              fontWeight: FontWeight.bold))
                      : null,
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => _showIngredientDetail(name),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// --- Detail Modal ---

class _ScienceDetailModal extends StatelessWidget {
  final IngredientMatch item;
  final bool isTrigger;
  final String uses, safety, group;
  final Color scienceColor, socialColor;

  const _ScienceDetailModal({
    required this.item,
    required this.isTrigger,
    required this.uses,
    required this.safety,
    required this.group,
    required this.scienceColor,
    required this.socialColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10))),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(item.name,
                    style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1)),
                Text("GROUP: $group",
                    style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 1.5)),
                const SizedBox(height: 25),

                if (isTrigger)
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 25),
                    decoration: BoxDecoration(
                        color: Colors.red.shade900,
                        borderRadius: BorderRadius.circular(15)),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.white),
                        SizedBox(width: 12),
                        Text("PERSONAL CONFLICT DETECTED",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 13)),
                      ],
                    ),
                  ),

                // --- NEW: THE SCORE BADGES ROW ---
                Row(
                  children: [
                    _scoreBadge("Science Says", item.riskScore ?? "Unknown",
                        scienceColor),
                    const SizedBox(width: 12),
                    _scoreBadge("Social Says", item.sentiment ?? "Neutral",
                        socialColor),
                  ],
                ),

                const SizedBox(height: 30),
                _buildDataRow("EXECUTIVE SUMMARY",
                    item.summary ?? "No scientific summary available."),
                const SizedBox(height: 25),
                _buildDataRow("COMMON USES", uses),
                const SizedBox(height: 25),
                _buildDataRow("SAFETY STATEMENTS", safety),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreBadge(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: color,
                    letterSpacing: 0.5)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Colors.black38,
                letterSpacing: 1.2)),
        const SizedBox(height: 8),
        Text(content,
            style: const TextStyle(
                fontSize: 15, height: 1.6, color: Colors.black87)),
      ],
    );
  }
}

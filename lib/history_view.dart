import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class HistoryView extends StatefulWidget {
  final List<ScannedProduct> history;
  final Function(int) onDelete;

  const HistoryView({super.key, required this.history, required this.onDelete});

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  List<String> userPrefs = [];

  // --- Fuzzy Logic Mapping (Synced with ScanView) ---
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

  // --- Conflict Label Logic ---
  String? _getConflictLabel(String name) {
    final n = name.toLowerCase().trim();
    const allergies = [
      "Peanuts",
      "Dairy",
      "Gluten",
      "Soy",
      "Eggs",
      "Shellfish"
    ];

    for (var pref in userPrefs) {
      if (_triggerKeywords.containsKey(pref)) {
        for (var keyword in _triggerKeywords[pref]!) {
          if (n.contains(keyword.toLowerCase())) {
            String category = allergies.contains(pref) ? "ALLERGY" : "DIET";
            return "${pref.toUpperCase()} $category";
          }
        }
      }
    }
    return null;
  }

  // --- Color Coding Logic ---
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

  void _showHistoryDetail(ScannedProduct product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _HistoryDetailModal(
        product: product,
        getLabel: _getConflictLabel,
        scienceColor: _getScienceColor,
        socialColor: _getSocialColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text("Scan History",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
      ),
      body: widget.history.isEmpty
          ? const Center(child: Text("Your scan history will appear here."))
          : ListView.builder(
              itemCount: widget.history.length,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              itemBuilder: (context, i) {
                final product = widget.history[i];
                return Dismissible(
                  key: Key(product.date.toString()),
                  direction: DismissDirection.endToStart,
                  onDismissed: (direction) => widget.onDelete(i),
                  background: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                        color: Colors.red.shade900,
                        borderRadius: BorderRadius.circular(15)),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child:
                        const Icon(Icons.delete_outline, color: Colors.white),
                  ),
                  child: Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                        side: BorderSide(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(15)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      title: Text(product.name,
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                      subtitle: Text(
                          "${product.matches.length} Ingredients Analyzed"),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _showHistoryDetail(product),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// --- The Science Panel Modal ---

class _HistoryDetailModal extends StatelessWidget {
  final ScannedProduct product;
  final String? Function(String) getLabel;
  final Color Function(int) scienceColor;
  final Color Function(int) socialColor;

  const _HistoryDetailModal({
    required this.product,
    required this.getLabel,
    required this.scienceColor,
    required this.socialColor,
  });

  @override
  Widget build(BuildContext context) {
    // Sort history ingredients by science risk (high to low) by default
    final sortedMatches = List<IngredientMatch>.from(product.matches);
    sortedMatches.sort((a, b) => b.riskScoreNum.compareTo(a.riskScoreNum));

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
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
                Text(product.name,
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5)),
                const Text("HISTORICAL ANALYSIS",
                    style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 1.5)),
                const SizedBox(height: 25),
                ...sortedMatches.map((m) {
                  final conflictLabel = getLabel(m.name);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: conflictLabel != null
                              ? Colors.red.shade200
                              : Colors.grey.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (conflictLabel != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text("⚠️ $conflictLabel",
                                style: TextStyle(
                                    color: Colors.red.shade900,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10)),
                          ),
                        Text(m.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 18)),
                        const SizedBox(height: 12),

                        // --- Worded Score Badges ---
                        Row(
                          children: [
                            _scoreBadge(
                                "Science Says",
                                m.riskScore ?? "Unknown",
                                scienceColor(m.riskScoreNum)),
                            const SizedBox(width: 10),
                            _scoreBadge("Social Says", m.sentiment ?? "Neutral",
                                socialColor(m.sentimentNum)),
                          ],
                        ),

                        const SizedBox(height: 15),
                        const Text("EXECUTIVE SUMMARY",
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                                letterSpacing: 1)),
                        const SizedBox(height: 5),
                        Text(m.summary ?? "No summary available.",
                            style: const TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: Colors.black87)),
                      ],
                    ),
                  );
                }).toList(),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
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
          Text(value,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }
}

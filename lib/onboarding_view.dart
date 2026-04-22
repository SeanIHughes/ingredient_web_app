import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final List<String> _allergies = [
    "Peanuts",
    "Dairy",
    "Gluten",
    "Soy",
    "Eggs",
    "Shellfish"
  ];
  final List<String> _diets = ["Vegan", "Vegetarian", "Paleo", "Keto"];

  final Set<String> _selectedPreferences = {};
  bool _isFirstTime = true; // Flag to track if we show "Welcome" or "Edit"

  @override
  void initState() {
    super.initState();
    _loadExistingPrefs();
  }

  void _loadExistingPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final bool seen = prefs.getBool('seen_onboarding') ?? false;
    final List<String>? existing = prefs.getStringList('user_prefs');

    setState(() {
      _isFirstTime = !seen;
      if (existing != null) {
        _selectedPreferences.addAll(existing);
      }
    });
  }

  void _saveAndContinue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('user_prefs', _selectedPreferences.toList());
    await prefs.setBool('seen_onboarding', true);

    if (!mounted) return;

    // If they are just editing, go back. If it's the first time, go to main.
    if (!_isFirstTime) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/main');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade900.withOpacity(0.8), Colors.black],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30.0, vertical: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 40),
                            // --- DYNAMIC HEADER ---
                            Text(
                              _isFirstTime ? "WELCOME TO" : "EDIT PREFERENCES",
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
                            const Text(
                              "Science Says",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 15),
                            Text(
                              _isFirstTime
                                  ? "Let's personalize your safety engine to flag ingredients that don't fit your lifestyle."
                                  : "Update your triggers and dietary goals to keep your safety engine accurate.",
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  height: 1.4),
                            ),
                            const SizedBox(height: 40),

                            _buildSectionTitle("ALLERGIES"),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: _allergies
                                  .map((a) => _buildCustomChip(a))
                                  .toList(),
                            ),

                            const SizedBox(height: 30),
                            _buildSectionTitle("DIETARY LIFESTYLE"),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: _diets
                                  .map((d) => _buildCustomChip(d))
                                  .toList(),
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                        Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: 65,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.greenAccent.shade700,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18)),
                                ),
                                onPressed: _saveAndContinue,
                                child: Text(
                                  _isFirstTime
                                      ? "START SCANNING"
                                      : "SAVE SETTINGS",
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (_isFirstTime) // Only show skip on first run
                              Center(
                                child: TextButton(
                                  onPressed: _saveAndContinue,
                                  child: const Text("Skip for now",
                                      style: TextStyle(
                                          color: Colors.white38, fontSize: 14)),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: const TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5),
      ),
    );
  }

  Widget _buildCustomChip(String label) {
    final isSelected = _selectedPreferences.contains(label);
    return GestureDetector(
      onTap: () => setState(() => isSelected
          ? _selectedPreferences.remove(label)
          : _selectedPreferences.add(label)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.greenAccent.shade400
              : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isSelected ? Colors.white : Colors.white24, width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: isSelected ? Colors.black : Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14),
        ),
      ),
    );
  }
}

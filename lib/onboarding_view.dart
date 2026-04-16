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

  void _saveAndContinue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('user_prefs', _selectedPreferences.toList());
    await prefs.setBool('seen_onboarding', true);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/main');
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
                // <--- THE OVERFLOW FIX
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight, // Fills screen if empty
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30.0, vertical: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment
                          .spaceBetween, // Keeps buttons at bottom
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- TOP CONTENT SECTION ---
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 40),
                            const Text(
                              "WELCOME TO",
                              style: TextStyle(
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
                            const Text(
                              "Let's personalize your safety engine to flag ingredients that don't fit your lifestyle.",
                              style: TextStyle(
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
                            const SizedBox(height: 40), // Buffer before buttons
                          ],
                        ),

                        // --- BOTTOM BUTTONS SECTION ---
                        Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: 65,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.greenAccent.shade700,
                                  foregroundColor: Colors.black,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                onPressed: _saveAndContinue,
                                child: const Text(
                                  "START SCANNING",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Center(
                              child: TextButton(
                                onPressed: _saveAndContinue,
                                child: const Text(
                                  "Skip for now",
                                  style: TextStyle(
                                      color: Colors.white38, fontSize: 14),
                                ),
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
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildCustomChip(String label) {
    final isSelected = _selectedPreferences.contains(label);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedPreferences.remove(label);
          } else {
            _selectedPreferences.add(label);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.greenAccent.shade400
              : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white24,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

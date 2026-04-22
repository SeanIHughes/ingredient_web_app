import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  List<String> _currentPrefs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Load the preferences from storage
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentPrefs = prefs.getStringList('user_prefs') ?? [];
      _isLoading = false;
    });
  }

  // PROFESSIONAL FIX: We don't "reset" the seen_onboarding flag.
  // We simply navigate to the edit version of the page.
  Future<void> _navigateToEdit() async {
    // We use the named route we set up in main.dart that passes isEditing: true
    await Navigator.pushNamed(context, '/edit_preferences');
    
    // When the user comes back from editing, we refresh the chips
    _load();
  }

  @override
  Widget build(BuildContext context) {
    // Wrapping in Scaffold provides the correct Material context 
    // so you don't need 'TextDecoration.none' on every text widget.
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 1. FIXED HEADER
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
              child: Row(
                children: [
                  const Text(
                    "My Profile",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 28,
                    ),
                  ),
                  const Spacer(),
                  CircleAvatar(
                    backgroundColor: Colors.green.shade50,
                    child: Icon(Icons.shield_rounded, color: Colors.green.shade800),
                  ),
                ],
              ),
            ),

            // 2. SCROLLABLE AREA
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: Colors.black))
                : ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      const SizedBox(height: 20),
                      _buildUserCard(),
                      const SizedBox(height: 40),
                      const Text(
                        "CURRENT TRIGGERS",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.black38,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildTriggerWrap(),
                      const SizedBox(height: 40),
                    ],
                  ),
            ),

            // 3. FIXED BUTTON (The "Action" Area)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, -4),
                    blurRadius: 10,
                  )
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: _navigateToEdit,
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text("UPDATE PREFERENCES"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                    textStyle: const TextStyle(
                        fontWeight: FontWeight.w900, letterSpacing: 1),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_circle, size: 50, color: Colors.black26),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Verified Human",
                style: TextStyle(
                  fontWeight: FontWeight.w900, 
                  fontSize: 16, 
                  color: Colors.black
                ),
              ),
              Text(
                "Personalized Safety Engine Active",
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTriggerWrap() {
    if (_currentPrefs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          "No triggers selected. Your engine is currently allowing all ingredients.",
          style: TextStyle(color: Colors.black38, fontSize: 13, height: 1.4),
        ),
      );
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _currentPrefs
          .map((p) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red.shade900,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      p.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}
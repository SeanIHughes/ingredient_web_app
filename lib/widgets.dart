import 'package:flutter/material.dart';
import 'models.dart';

class IngredientRow extends StatefulWidget {
  final IngredientMatch item;
  final bool isPersonalTrigger;
  final String?
      personalTriggerLabel; // This handles the specific "PEANUT ALLERGY" text

  const IngredientRow({
    super.key,
    required this.item,
    this.isPersonalTrigger = false,
    this.personalTriggerLabel,
  });

  @override
  State<IngredientRow> createState() => _IngredientRowState();
}

class _IngredientRowState extends State<IngredientRow> {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.isPersonalTrigger
            ? Colors.red.shade50
            : Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withOpacity(0.3),
        borderRadius: BorderRadius.circular(24),
        border: widget.isPersonalTrigger
            ? Border.all(color: Colors.red.shade200, width: 2)
            : Border.all(color: Colors.transparent),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- SPECIFIC ALLERGY/DIET ALERT ---
          if (widget.isPersonalTrigger)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.shade800,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      (widget.personalTriggerLabel ?? "PERSONAL CONFLICT")
                          .toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.item.name.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    letterSpacing: -0.5,
                    color: widget.isPersonalTrigger
                        ? Colors.red.shade900
                        : Colors.black,
                  ),
                ),
              ),
              _Badge(
                text: widget.item.classification ?? "COMMON",
                color: _getClassColor(widget.item.classification),
              ),
            ],
          ),

          if (widget.item.synonyms != null && widget.item.synonyms!.isNotEmpty)
            _SynonymSection(synonyms: widget.item.synonyms!),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, thickness: 0.5),
          ),

          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: "SCIENCE SAYS",
                  value: widget.item.riskScore ?? "Unknown",
                  icon: Icons.biotech_rounded,
                  color: _getRiskColor(widget.item.riskScore),
                ),
              ),
              Expanded(
                child: _Metric(
                  label: "SOCIAL SAYS",
                  value: widget.item.sentiment ?? "NEUTRAL",
                  icon: Icons.auto_awesome_rounded,
                  color: _getSentColor(widget.item.sentiment),
                ),
              ),
            ],
          ),

          if (widget.item.summary != null && widget.item.summary!.isNotEmpty)
            _ExpandableSummary(summary: widget.item.summary!),
        ],
      ),
    );
  }

  Color _getRiskColor(String? r) {
    if (r == null) return Colors.grey;
    if (r.contains("Very High") || r.contains("High"))
      return Colors.red.shade700;
    if (r.contains("Moderate")) return Colors.orange.shade700;
    if (r.contains("Low") || r.contains("Minimal"))
      return Colors.green.shade700;
    return Colors.blueGrey;
  }

  Color _getSentColor(String? s) {
    switch (s) {
      case "Very Negative":
        return Colors.red.shade900;
      case "Negative":
        return Colors.red.shade400;
      case "Neutral":
        return Colors.grey.shade600;
      case "Positive":
        return Colors.green.shade400;
      case "Very Positive":
        return Colors.green.shade900;
      default:
        return Colors.blueGrey;
    }
  }

  Color _getClassColor(String? c) {
    switch (c?.toLowerCase()) {
      case "additive":
        return Colors.orange.shade800;
      case "chemical":
        return Colors.purple.shade700;
      case "natural":
        return Colors.green.shade800;
      default:
        return Colors.blue.shade700;
    }
  }
}

// --- Internal Helper Widgets ---
class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3))),
      child: Text(text.toUpperCase(),
          style: TextStyle(
              color: color, fontSize: 9, fontWeight: FontWeight.w900)),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _Metric(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: Colors.black38,
                letterSpacing: 1.1)),
        const SizedBox(height: 6),
        Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Flexible(
              child: Text(value.toUpperCase(),
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w900, fontSize: 13)))
        ]),
      ],
    );
  }
}

class _ExpandableSummary extends StatefulWidget {
  final String summary;
  const _ExpandableSummary({required this.summary});
  @override
  State<_ExpandableSummary> createState() => _ExpandableSummaryState();
}

class _ExpandableSummaryState extends State<_ExpandableSummary> {
  bool expanded = false;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => setState(() => expanded = !expanded),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: Text(widget.summary,
                maxLines: expanded ? null : 3,
                overflow:
                    expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.black.withOpacity(0.7),
                    fontSize: 14,
                    height: 1.5)),
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
            onTap: () => setState(() => expanded = !expanded),
            child: Text(
                expanded ? "SHOW LESS" : "READ FULL SCIENTIFIC ANALYSIS",
                style: TextStyle(
                    color: Colors.blue.shade800,
                    fontWeight: FontWeight.w900,
                    fontSize: 10))),
      ],
    );
  }
}

class _SynonymSection extends StatefulWidget {
  final String synonyms;
  const _SynonymSection({required this.synonyms});
  @override
  State<_SynonymSection> createState() => _SynonymSectionState();
}

class _SynonymSectionState extends State<_SynonymSection> {
  bool show = false;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        InkWell(
            onTap: () => setState(() => show = !show),
            child: Text(show ? "HIDE ALIASES" : "SHOW SCIENTIFIC SYNONYMS",
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    decoration: TextDecoration.underline))),
        if (show)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(widget.synonyms,
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      fontStyle: FontStyle.italic))),
      ],
    );
  }
}

// lib/widgets/result_card.dart
import 'package:flutter/material.dart';

class ResultCard extends StatelessWidget {
  final String standard;
  final double ageGrade;
  final String ageGradeMessage;
  final String guidance;

  const ResultCard({
    super.key,
    required this.standard,
    required this.ageGrade,
    required this.ageGradeMessage,
    required this.guidance,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final _ResultStyle style = _mapStandardToStyle(standard);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 71, 5, 226),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Badge row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: style.badgeColor.withOpacity(0.18),
                child: Icon(style.icon, color: style.badgeColor, size: 26),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  style.displayLabel,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Age grade
          Text(
            'Age Grade: ${ageGrade.toStringAsFixed(1)}%',
            style: const TextStyle(
              color: Colors.yellowAccent,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            ageGradeMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),

          const SizedBox(height: 16),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 16),

          Text(
            guidance,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  _ResultStyle _mapStandardToStyle(String raw) {
    final label = raw.trim().toUpperCase();

    if (label.startsWith('GOLD')) {
      return _ResultStyle(
        displayLabel: 'GOLD',
        badgeColor: const Color(0xFFFFD300),
        icon: Icons.emoji_events_rounded,
      );
    }
    if (label.startsWith('SILVER')) {
      return _ResultStyle(
        displayLabel: 'SILVER',
        badgeColor: const Color(0xFFC0C0C0),
        icon: Icons.emoji_events_rounded,
      );
    }
    if (label.startsWith('BRONZE')) {
      return _ResultStyle(
        displayLabel: 'BRONZE',
        badgeColor: const Color(0xFFCD7F32),
        icon: Icons.emoji_events_rounded,
      );
    }
    if (label.startsWith('PLATINUM')) {
      return _ResultStyle(
        displayLabel: 'PLATINUM',
        badgeColor: const Color(0xFFB0E0E6),
        icon: Icons.workspace_premium_rounded,
      );
    }

    // Default / UNRANKED
    return _ResultStyle(
      displayLabel: label.isEmpty ? 'UNRANKED' : label,
      badgeColor: Colors.grey.shade400,
      icon: Icons.flag_rounded,
    );
  }
}

class _ResultStyle {
  final String displayLabel;
  final Color badgeColor;
  final IconData icon;

  _ResultStyle({
    required this.displayLabel,
    required this.badgeColor,
    required this.icon,
  });
}

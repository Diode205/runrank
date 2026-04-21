// lib/widgets/result_card.dart
import 'package:flutter/material.dart';

class ResultCard extends StatelessWidget {
  final String standard;
  final double ageGrade;
  final String ageGradeMessage;
  final String guidance;
  final Color backgroundColor;
  final Color accentColor;
  final Color primaryTextColor;
  final Color secondaryTextColor;

  const ResultCard({
    super.key,
    required this.standard,
    required this.ageGrade,
    required this.ageGradeMessage,
    required this.guidance,
    required this.backgroundColor,
    required this.accentColor,
    this.primaryTextColor = Colors.white,
    this.secondaryTextColor = Colors.white70,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final _ResultStyle style = _mapStandardToStyle(standard);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
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
                backgroundColor: style.badgeColor.withValues(alpha: 0.18),
                child: Icon(style.icon, color: style.badgeColor, size: 26),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  style.displayLabel,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: primaryTextColor,
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
            style: TextStyle(
              color: accentColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            ageGradeMessage,
            textAlign: TextAlign.center,
            style: TextStyle(color: primaryTextColor, fontSize: 16),
          ),

          const SizedBox(height: 16),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 16),

          Text(
            guidance,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: secondaryTextColor,
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

    if (label.startsWith('DIAMOND')) {
      return _ResultStyle(
        displayLabel: 'DIAMOND',
        badgeColor: const Color(0xFF00E5FF),
        icon: Icons.diamond_rounded,
      );
    }
    if (label.startsWith('EMERALD')) {
      return _ResultStyle(
        displayLabel: 'EMERALD',
        badgeColor: const Color(0xFF2ECC71),
        icon: Icons.auto_awesome_rounded,
      );
    }
    if (label.startsWith('PLATINUM')) {
      return _ResultStyle(
        displayLabel: 'PLATINUM',
        badgeColor: const Color(0xFFB0E0E6),
        icon: Icons.workspace_premium_rounded,
      );
    }

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
    if (label.startsWith('COPPER')) {
      return _ResultStyle(
        displayLabel: 'COPPER',
        badgeColor: const Color(0xFFB87333),
        icon: Icons.military_tech_rounded,
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

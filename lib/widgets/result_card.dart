// result_card.dart
import 'package:flutter/material.dart';

class ResultCard extends StatelessWidget {
  final String standard; // e.g. 'Silver'
  final double ageGrade; // numeric %
  final String guidance; // guidance text block
  final String? ageGradeMessage; // optional message when no world-best exists

  const ResultCard({
    super.key,
    required this.standard,
    required this.ageGrade,
    required this.guidance,
    this.ageGradeMessage,
  });

  // color selection
  Color _getColor(String level) {
    switch (level.toLowerCase()) {
      case 'diamond':
        return Colors.cyan;
      case 'gold':
        return const Color(0xFFFFD700);
      case 'silver':
        return const Color(0xFFC0C0C0);
      case 'bronze':
        return const Color(0xFFCD7F32);
      case 'copper':
        return const Color(0xFFB87333);
      default:
        return Colors.grey.shade400;
    }
  }

  // icon selection
  IconData _getIcon(String level) {
    switch (level.toLowerCase()) {
      case 'diamond':
        return Icons.diamond;
      case 'gold':
      case 'silver':
      case 'bronze':
        return Icons.emoji_events;
      case 'copper':
        return Icons.local_florist;
      default:
        return Icons.flag;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _getColor(standard);
    final icon = _getIcon(standard);

    return Card(
      elevation: 6,
      margin: const EdgeInsets.only(top: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // title
            Text(
              'Your Result',
              style: theme.textTheme.titleLarge!.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),

            // main box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color, width: 2),
              ),
              child: Column(
                children: [
                  // icon + standard
                  Row(
                    children: [
                      Icon(icon, size: 48, color: color),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          standard.toUpperCase(),
                          style: theme.textTheme.headlineSmall!.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // age grade (if available)
                  Text(
                    ageGrade > 0.0
                        ? 'Age Grade: ${ageGrade.toStringAsFixed(1)}%'
                        : 'Age Grade: N/A',
                    style: theme.textTheme.titleMedium!.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // optional message (e.g. no record)
                  if (ageGrade <= 0.0 && ageGradeMessage != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Text(
                        ageGradeMessage!,
                        style: theme.textTheme.bodySmall!.copyWith(
                          color: Colors.black54,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  const SizedBox(height: 12),

                  // guidance block
                  Text(
                    guidance,
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

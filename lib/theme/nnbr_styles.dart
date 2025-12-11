import 'package:flutter/material.dart';

/// Shared visual styles for NNBR look & feel
class NNBRStyles {
  /// Dark rounded card with soft shadow
  static final BoxDecoration card = BoxDecoration(
    color: const Color(0xFF111111), // dark grey, not pure black
    borderRadius: BorderRadius.circular(18),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.4),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  );

  /// Default padding used inside cards
  static const EdgeInsets cardPadding = EdgeInsets.all(16);

  /// Small pill used for tags / badges (if we need later)
  static final BoxDecoration pill = BoxDecoration(
    color: const Color(0xFF0057B7).withOpacity(0.15),
    borderRadius: BorderRadius.circular(999),
    border: Border.all(color: const Color(0xFF0057B7)),
  );
}

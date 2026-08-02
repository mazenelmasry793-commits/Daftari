import 'package:debt_tracker/data/models/entry.dart';
import 'package:flutter/material.dart';

class EntryTypeBadge extends StatelessWidget {
  const EntryTypeBadge({required this.type, super.key});

  final EntryType type;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (type) {
      EntryType.owedToMe => ('To Me', const Color(0xFF1976D2)),
      EntryType.owedByMe => ('I Owe', const Color(0xFFE87500)),
      _ => ('To Me', const Color(0xFF1976D2)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

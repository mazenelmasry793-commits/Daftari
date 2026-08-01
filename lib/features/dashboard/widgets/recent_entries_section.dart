import 'package:debt_tracker/data/models/entry.dart';
import 'package:debt_tracker/features/dashboard/widgets/recent_entry_row.dart';
import 'package:flutter/material.dart';

class RecentEntriesSection extends StatelessWidget {
  const RecentEntriesSection({
    required this.entries,
    required this.onTap,
    super.key,
  });

  final List<Entry> entries;
  final ValueChanged<Entry> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.32),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(
          children: [
            for (var index = 0; index < entries.length; index++) ...[
              RecentEntryRow(
                entry: entries[index],
                onTap: () => onTap(entries[index]),
              ),
              if (index != entries.length - 1)
                Padding(
                  padding: const EdgeInsets.only(left: 88, right: 16),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: scheme.outlineVariant.withValues(alpha: 0.45),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

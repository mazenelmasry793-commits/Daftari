import 'package:debt_tracker/core/utils/formatters.dart';
import 'package:debt_tracker/data/models/entry.dart';
import 'package:flutter/material.dart';

class EntryCard extends StatelessWidget {
  const EntryCard({
    required this.entry,
    this.onTap,
    this.trailing,
    this.compact = false,
    super.key,
  });

  final Entry entry;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool compact;

  Color _colorForType(BuildContext context) {
    switch (entry.type) {
      case EntryType.owedToMe:
        return const Color(0xFF1976D2); // Blue
      case EntryType.owedByMe:
        return const Color(0xFFF57C00); // Orange
      default:
        return const Color(0xFF1976D2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _colorForType(context);
    final note = entry.note?.trim();

    IconData getIcon() {
      switch (entry.type) {
        case EntryType.owedToMe:
          return Icons.south_west_rounded;
        case EntryType.owedByMe:
          return Icons.north_east_rounded;
        default:
          return Icons.south_west_rounded;
      }
    }

    final isCompleted = entry.status == EntryStatus.completed ||
        (entry.amount ?? 0) > 0 && entry.remainingAmount <= 0;

    return AnimatedScale(
      scale: 1,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.3)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(getIcon(), color: color, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSurface,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppFormatters.date.format(entry.debtDate ?? entry.createdAt),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                          if (!compact && note != null && note.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              note,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.outline),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          AppFormatters.moneyValue(entry.remainingAmount),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: color,
                              ),
                        ),
                        if (isCompleted) ...[
                          const SizedBox(height: 4),
                          const _StatusChip(label: 'Completed', color: Colors.green),
                        ],
                      ],
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 8),
                      trailing!,
                    ],
                  ],
                ),
                if (!isCompleted) ...[
                  const SizedBox(height: 16),
                  Builder(
                    builder: (context) {
                      final original = entry.amount ?? 0.0;
                      double progress = 0;
                      if (original > 0) {
                        progress = entry.paidAmount / original;
                        if (progress > 1.0) progress = 1.0;
                        if (progress < 0.0) progress = 0.0;
                      }
                      if (progress == 0) return const SizedBox.shrink();
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Paid', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                              Text('${(progress * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w800)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                            value: progress,
                            backgroundColor: scheme.surfaceContainerHighest,
                            color: color,
                            minHeight: 4,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

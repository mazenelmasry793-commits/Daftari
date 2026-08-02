import 'package:debt_tracker/core/utils/formatters.dart';
import 'package:debt_tracker/data/models/entry.dart';
import 'package:debt_tracker/features/dashboard/widgets/entry_type_badge.dart';
import 'package:flutter/material.dart';

class RecentEntryRow extends StatelessWidget {
  const RecentEntryRow({required this.entry, required this.onTap, super.key});

  final Entry entry;
  final VoidCallback onTap;

  Color _color(BuildContext context) => switch (entry.type) {
    EntryType.owedToMe => const Color(0xFF1976D2),
    EntryType.owedByMe => const Color(0xFFE87500),
    _ => const Color(0xFF1976D2),
  };

  IconData get _icon => switch (entry.type) {
    EntryType.owedToMe => Icons.south_west_rounded,
    EntryType.owedByMe => Icons.north_east_rounded,
    _ => Icons.south_west_rounded,
  };

  String get _amount => AppFormatters.moneyValue(entry.remainingAmount);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _color(context);
    return Semantics(
      button: true,
      label: '${entry.title}, ${entry.type.label}, $_amount',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 360;
              final iconDimension = compact ? 48.0 : 58.0;
              final amountWidth = compact ? 78.0 : 112.0;
              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 12 : 16,
                  vertical: 14,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: iconDimension,
                      height: iconDimension,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.11),
                      ),
                      child: Icon(_icon, color: color, size: compact ? 25 : 30),
                    ),
                    SizedBox(width: compact ? 8 : 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 7,
                            runSpacing: 2,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              EntryTypeBadge(type: entry.type),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 112,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.calendar_month_outlined,
                                      size: 16,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        AppFormatters.date.format(
                                          entry.debtDate ?? entry.createdAt,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: compact ? 4 : 8),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: amountWidth),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          _amount,
                          maxLines: 1,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: color,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: scheme.outline,
                      size: compact ? 24 : 27,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

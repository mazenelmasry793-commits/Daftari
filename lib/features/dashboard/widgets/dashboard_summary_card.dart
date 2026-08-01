import 'package:flutter/material.dart';

class DashboardSummaryCard extends StatelessWidget {
  const DashboardSummaryCard({
    required this.title,
    required this.amount,
    required this.isIncoming,
    super.key,
  });

  final String title;
  final String amount;
  final bool isIncoming;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isIncoming
        ? (dark ? const Color(0xFF3975D6) : const Color(0xFF2F80ED))
        : (dark ? const Color(0xFFD87520) : const Color(0xFFF58A25));
    final accentColor = isIncoming
        ? (dark ? const Color(0xFF6E9EED) : const Color(0xFF72A7F7))
        : (dark ? const Color(0xFFFFA45C) : const Color(0xFFFFB36D));
    final icon = isIncoming
        ? Icons.south_west_rounded
        : Icons.north_east_rounded;

    return Semantics(
      container: true,
      label: '$title, $amount',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < 150 || constraints.maxHeight < 230;
          final padding = compact ? 10.0 : 18.0;
          final iconSize = compact ? 44.0 : 60.0;
          final textTheme = Theme.of(context).textTheme;
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [accentColor, baseColor],
              ),
              boxShadow: [
                BoxShadow(
                  color: baseColor.withValues(alpha: dark ? 0.22 : 0.18),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Stack(
                children: [
                  Positioned(
                    right: -constraints.maxWidth * 0.28,
                    bottom: -constraints.maxHeight * 0.18,
                    child: Container(
                      width: constraints.maxWidth * 1.05,
                      height: constraints.maxWidth * 1.05,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(
                          alpha: dark ? 0.05 : 0.09,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      padding,
                      padding,
                      padding,
                      compact ? 10 : 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: iconSize,
                          height: iconSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.19),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Icon(
                            icon,
                            color: Colors.white,
                            size: compact ? 25 : 34,
                          ),
                        ),
                        const Spacer(),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style:
                                (compact
                                        ? textTheme.bodyMedium
                                        : textTheme.titleMedium)
                                    ?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.96,
                                      ),
                                      fontWeight: FontWeight.w600,
                                      height: 1.15,
                                    ),
                          ),
                        ),
                        SizedBox(height: compact ? 3 : 6),
                        SizedBox(
                          width: double.infinity,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              amount,
                              maxLines: 1,
                              style:
                                  (compact
                                          ? textTheme.titleLarge
                                          : textTheme.headlineMedium)
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.7,
                                      ),
                            ),
                          ),
                        ),
                        SizedBox(height: compact ? 6 : 12),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 7 : 8,
                            vertical: compact ? 5 : 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isIncoming
                                    ? Icons.people_outline_rounded
                                    : Icons.account_balance_wallet_outlined,
                                color: Colors.white.withValues(alpha: 0.95),
                                size: compact ? 15 : 19,
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  isIncoming
                                      ? "You're owed money"
                                      : 'You owe money',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      (compact
                                              ? textTheme.labelSmall
                                              : textTheme.labelLarge)
                                          ?.copyWith(
                                            color: Colors.white.withValues(
                                              alpha: 0.95,
                                            ),
                                            fontWeight: FontWeight.w600,
                                          ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

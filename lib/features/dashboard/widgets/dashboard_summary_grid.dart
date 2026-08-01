import 'package:flutter/material.dart';
import 'package:debt_tracker/features/dashboard/widgets/dashboard_summary_card.dart';

class DashboardSummaryGrid extends StatelessWidget {
  const DashboardSummaryGrid({
    required this.owedToMe,
    required this.iOwe,
    super.key,
  });

  final String owedToMe;
  final String iOwe;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 12) / 2;
        final cardHeight = (cardWidth * 1.22).clamp(220.0, 292.0);
        return SizedBox(
          height: cardHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: DashboardSummaryCard(
                  title: 'Total Money Owed To Me',
                  amount: owedToMe,
                  isIncoming: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DashboardSummaryCard(
                  title: 'Total Money I Owe',
                  amount: iOwe,
                  isIncoming: false,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

import 'package:debt_tracker/core/utils/formatters.dart';
import 'package:debt_tracker/features/dashboard/widgets/dashboard_empty_state.dart';
import 'package:debt_tracker/features/dashboard/widgets/dashboard_summary_grid.dart';
import 'package:debt_tracker/features/dashboard/widgets/recent_entries_section.dart';
import 'package:debt_tracker/features/entry_details/entry_details_screen.dart';
import 'package:debt_tracker/presentation/providers/app_providers.dart';
import 'package:debt_tracker/presentation/widgets/app_page_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({
    required this.onSearch,
    required this.onAdd,
    super.key,
  });

  final VoidCallback onSearch;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibleAsync = ref.watch(visibleEntriesProvider);

    return visibleAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(error.toString())),
      data: (entries) {
        final totals = calculateDashboardTotals(entries);
        final recent = entries.take(6).toList();

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              sliver: SliverToBoxAdapter(
                child: DashboardSummaryGrid(
                  owedToMe: AppFormatters.money.format(totals.owedToMe),
                  iOwe: AppFormatters.money.format(totals.iOwe),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              sliver: SliverToBoxAdapter(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(
                        'Recent Entries',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      '${recent.length} ${recent.length == 1 ? 'item' : 'items'}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              sliver: SliverToBoxAdapter(
                child: recent.isEmpty
                    ? const DashboardEmptyState()
                    : RecentEntriesSection(
                        entries: recent,
                        onTap: (entry) => Navigator.of(context).push(
                          AppPageRoute(
                            child: EntryDetailsScreen(entryId: entry.id),
                          ),
                        ),
                      ),
              ),
            ),
            // AppShell's native bottom controls float above the Flutter body.
            // Keep the final content clear of that overlay on every platform.
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        );
      },
    );
  }
}

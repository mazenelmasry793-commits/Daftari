import 'dart:async';

import 'package:debt_tracker/core/utils/formatters.dart';
import 'package:debt_tracker/core/platform/ios_navigation_channel.dart';
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
        // Keep enough recent content for the native large-title bridge to
        // receive a real scroll offset on tall iPhones, without adding a
        // decorative spacer solely to force scrolling.
        final recent = entries.take(18).toList();

        return _DashboardScrollBridge(
          child: CustomScrollView(
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
          ),
        );
      },
    );
  }
}

/// UINavigationController cannot observe Flutter's CustomScrollView directly.
/// This sends a coalesced offset to the native navigation bar so it can switch
/// between Apple's expanded and inline title states without per-pixel traffic.
class _DashboardScrollBridge extends StatefulWidget {
  const _DashboardScrollBridge({required this.child});

  final Widget child;

  @override
  State<_DashboardScrollBridge> createState() => _DashboardScrollBridgeState();
}

class _DashboardScrollBridgeState extends State<_DashboardScrollBridge> {
  Timer? _timer;
  double _pendingOffset = 0;
  double _lastSentOffset = -1;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    _pendingOffset = notification.metrics.pixels.clamp(0, double.infinity);
    final isScrollEnd = notification is ScrollEndNotification;
    if (isScrollEnd || (_pendingOffset - _lastSentOffset).abs() >= 8) {
      _scheduleSend(immediate: isScrollEnd);
    }
    return false;
  }

  void _scheduleSend({required bool immediate}) {
    if (immediate) {
      _timer?.cancel();
      _timer = null;
      _sendOffset();
      return;
    }
    if (_timer != null) return;
    _timer = Timer(const Duration(milliseconds: 50), () {
      _timer = null;
      _sendOffset();
    });
  }

  void _sendOffset() {
    if ((_pendingOffset - _lastSentOffset).abs() < 1) return;
    _lastSentOffset = _pendingOffset;
    unawaited(iosNavigationChannel.setDashboardScrollOffset(_pendingOffset));
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: widget.child,
    );
  }
}

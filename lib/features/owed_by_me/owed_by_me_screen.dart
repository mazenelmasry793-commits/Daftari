import 'package:debt_tracker/core/widgets/confirm_dialog.dart';
import 'package:debt_tracker/core/platform/app_toast_service.dart';
import 'package:debt_tracker/core/widgets/empty_state.dart';
import 'package:debt_tracker/features/entry_details/entry_details_screen.dart';
import 'package:debt_tracker/presentation/providers/app_providers.dart';
import 'package:debt_tracker/presentation/widgets/app_page_route.dart';
import 'package:debt_tracker/presentation/widgets/entry_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OwedByMeScreen extends ConsumerWidget {
  const OwedByMeScreen({required this.onAdd, super.key});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(owedByMeEntriesProvider);
    final repository = ref.watch(entryRepositoryProvider);

    return entriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(error.toString())),
      data: (entries) {
        if (entries.isEmpty) {
          return EmptyState(
            icon: Icons.call_made_rounded,
            title: 'Nothing owed by you',
            message: 'Add a debt here when you owe money to someone.',
            action: FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Owed By Me'),
            ),
          );
        }
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              sliver: SliverList.separated(
                itemCount: entries.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return EntryCard(
                    entry: entry,
                    onTap: () => Navigator.of(context).push(
                      AppPageRoute(
                        child: EntryDetailsScreen(entryId: entry.id),
                      ),
                    ),
                    trailing: PopupMenuButton<_Action>(
                      icon: const Icon(Icons.more_vert_rounded),
                      onSelected: (action) async {
                        switch (action) {
                          case _Action.details:
                            if (context.mounted) {
                              Navigator.of(context).push(
                                AppPageRoute(
                                  child: EntryDetailsScreen(entryId: entry.id),
                                ),
                              );
                            }
                            break;
                          case _Action.complete:
                            try {
                              await repository.markCompleted(entry.id);
                              await appToastService.show(
                                'Marked as completed',
                                type: AppToastType.success,
                              );
                            } catch (_) {
                              await appToastService.show(
                                'Something went wrong',
                                type: AppToastType.error,
                              );
                            }
                            break;
                          case _Action.delete:
                            final confirm = await showConfirmationDialog(
                              context,
                              title: 'Move to trash?',
                              message:
                                  'This entry will be moved to Trash and can be restored later.',
                              confirmLabel: 'Move',
                              destructive: true,
                            );
                            if (confirm) {
                              try {
                                await repository.softDelete(entry.id);
                                await appToastService.show(
                                  'Moved to trash',
                                  type: AppToastType.success,
                                );
                              } catch (_) {
                                await appToastService.show(
                                  'Something went wrong',
                                  type: AppToastType.error,
                                );
                              }
                            }
                            break;
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: _Action.details,
                          child: Text('Open details'),
                        ),
                        PopupMenuItem(
                          value: _Action.complete,
                          child: Text('Mark completed'),
                        ),
                        PopupMenuItem(
                          value: _Action.delete,
                          child: Text('Delete'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

enum _Action { details, complete, delete }

import 'package:debt_tracker/core/widgets/confirm_dialog.dart';
import 'package:debt_tracker/core/widgets/empty_state.dart';
import 'package:debt_tracker/features/entry_details/entry_details_screen.dart';
import 'package:debt_tracker/presentation/providers/app_providers.dart';
import 'package:debt_tracker/presentation/widgets/app_page_route.dart';
import 'package:debt_tracker/presentation/widgets/entry_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(trashEntriesProvider);
    final repository = ref.read(entryRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Trash')),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(error.toString())),
      data: (entries) {
        if (entries.isEmpty) {
          return const EmptyState(
            icon: Icons.delete_outline_rounded,
            title: 'Trash is empty',
            message: 'Deleted entries will appear here until you restore or delete them forever.',
          );
        }
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList.separated(
                itemCount: entries.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return EntryCard(
                    entry: entry,
                    onTap: () => Navigator.of(context).push(
                      AppPageRoute(child: EntryDetailsScreen(entryId: entry.id)),
                    ),
                    trailing: PopupMenuButton<_Action>(
                      icon: const Icon(Icons.more_vert_rounded),
                      onSelected: (action) async {
                        switch (action) {
                          case _Action.details:
                            if (context.mounted) {
                              Navigator.of(context).push(
                                AppPageRoute(child: EntryDetailsScreen(entryId: entry.id)),
                              );
                            }
                            break;
                          case _Action.restore:
                            await repository.restore(entry.id);
                            break;
                          case _Action.deleteForever:
                            final confirm = await showConfirmationDialog(
                              context,
                              title: 'Delete forever?',
                              message: 'This permanently removes the entry from your device.',
                              confirmLabel: 'Delete Forever',
                              destructive: true,
                            );
                            if (confirm) {
                              await repository.permanentlyDelete(entry.id);
                            }
                            break;
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: _Action.details, child: Text('Open details')),
                        PopupMenuItem(value: _Action.restore, child: Text('Restore')),
                        PopupMenuItem(value: _Action.deleteForever, child: Text('Delete forever')),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    ));
  }
}

enum _Action { details, restore, deleteForever }

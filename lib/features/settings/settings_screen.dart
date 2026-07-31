import 'dart:convert';

import 'package:debt_tracker/core/utils/file_saver.dart';
import 'package:debt_tracker/core/widgets/confirm_dialog.dart';
import 'package:debt_tracker/features/lock/change_pin_screen.dart';
import 'package:debt_tracker/features/lock/pin_setup_screen.dart';
import 'package:debt_tracker/features/trash/trash_screen.dart';
import 'package:debt_tracker/presentation/providers/app_providers.dart';
import 'package:debt_tracker/presentation/providers/security_controller.dart';
import 'package:debt_tracker/domain/repositories/entry_repository.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final securityAsync = ref.watch(securityControllerProvider);
    final repository = ref.read(entryRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: securityAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (security) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionCard(
                title: 'Security',
                children: [
                  if (!security.hasPin)
                    ListTile(
                      leading: const Icon(Icons.lock_reset_rounded),
                      title: const Text('Set PIN'),
                      subtitle: const Text('Create your first lock PIN.'),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PinSetupScreen())),
                    )
                  else ...[
                    ListTile(
                      leading: const Icon(Icons.password_rounded),
                      title: const Text('Change PIN'),
                      subtitle: const Text('Update your current PIN.'),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChangePinScreen())),
                    ),
                    ListTile(
                      leading: const Icon(Icons.lock_open_rounded),
                      title: Text(security.enabled ? 'Disable PIN' : 'Enable PIN'),
                      subtitle: Text(
                        security.enabled
                            ? 'Skip the lock screen on launch.'
                            : 'Require a PIN on launch again.',
                      ),
                      onTap: () async {
                        if (security.enabled) {
                          final confirm = await showConfirmationDialog(
                            context,
                            title: 'Disable PIN?',
                            message: 'The app will open without a lock screen until you re-enable it.',
                            confirmLabel: 'Disable',
                            destructive: true,
                          );
                          if (confirm) {
                            await ref.read(securityControllerProvider.notifier).disablePin();
                          }
                        } else {
                          await ref.read(securityControllerProvider.notifier).enablePin();
                        }
                      },
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Data',
                children: [
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded),
                    title: const Text('Trash'),
                    subtitle: const Text('View or restore deleted entries.'),
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TrashScreen()));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.file_upload_outlined),
                    title: const Text('Export local database to JSON'),
                    subtitle: const Text('Save a backup file on this device.'),
                    onTap: () async {
                      final json = await repository.exportJson();
                      final fileName = 'debt_tracker_backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json';
                      final savedPath = await saveTextFile(fileName: fileName, content: json);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Backup saved as $savedPath')),
                        );
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.file_download_outlined),
                    title: const Text('Import JSON backup'),
                    subtitle: const Text('Restore entries from a backup file.'),
                    onTap: () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: const ['json'],
                        withData: true,
                      );
                      final file = result?.files.single;
                      if (file == null) return;
                      if (file.bytes == null) return;
                      
                      final contents = utf8.decode(file.bytes!);
                      final preview = await repository.previewImport(contents);
                      
                      ImportStrategy strategy = ImportStrategy.skipExisting;
                      
                      if (preview.conflictingEntries > 0) {
                        if (!context.mounted) return;
                        final dialogResult = await showDialog<ImportStrategy>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Import Conflicts'),
                            content: Text(
                              'Found ${preview.newEntries} new entries and ${preview.conflictingEntries} entries that already exist.\n\n'
                              'How would you like to handle the existing entries?'
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(null),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(ImportStrategy.skipExisting),
                                child: const Text('Skip Existing'),
                              ),
                              FilledButton.tonal(
                                onPressed: () => Navigator.of(context).pop(ImportStrategy.replaceExisting),
                                child: const Text('Replace Existing'),
                              ),
                            ],
                          ),
                        );
                        if (dialogResult == null) return;
                        strategy = dialogResult;
                      }

                      final importResult = await repository.importJson(contents, strategy: strategy);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Imported: ${importResult.inserted} new, ${importResult.replaced} replaced, ${importResult.skipped} skipped.')),
                        );
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Danger Zone',
                children: [
                  ListTile(
                    leading: Icon(Icons.delete_sweep_outlined, color: Theme.of(context).colorScheme.error),
                    title: const Text('Empty Trash'),
                    subtitle: const Text('Permanently delete all items in Trash.'),
                    onTap: () async {
                      final confirm = await showConfirmationDialog(
                        context,
                        title: 'Empty Trash?',
                        message: 'This permanently deletes every item in Trash.',
                        confirmLabel: 'Empty',
                        destructive: true,
                      );
                      if (confirm) {
                        await repository.emptyTrash();
                      }
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.delete_forever_outlined, color: Theme.of(context).colorScheme.error),
                    title: const Text('Delete All Data'),
                    subtitle: const Text('Remove every entry from the device.'),
                    onTap: () async {
                      final confirm = await showConfirmationDialog(
                        context,
                        title: 'Delete all data?',
                        message: 'This removes every entry, including completed items and scratchpad notes.',
                        confirmLabel: 'Delete All',
                        destructive: true,
                      );
                      if (confirm) {
                        await repository.deleteAllData();
                      }
                    },
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

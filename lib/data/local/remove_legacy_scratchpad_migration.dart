import 'dart:convert';
import 'dart:io';

import 'package:debt_tracker/data/models/entry.dart';
import 'package:isar_community/isar.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

/// Removes legacy Scratchpad records only after writing a local backup.
///
/// `EntryType.scratchpad` remains in the persisted model solely so old Isar
/// records can be identified during this one-time migration.
Future<void> removeLegacyScratchpadRecords(Isar isar) async {
  // Flutter's widget-test host has no application Documents directory plugin;
  // keep the migration exercised there without blocking app bootstrap.
  final documents = Platform.environment.containsKey('FLUTTER_TEST')
      ? Directory.systemTemp
      : await getApplicationDocumentsDirectory();
  final flag = File(
    '${documents.path}/daftari_removed_scratchpad_migration_v1.flag',
  );
  if (await flag.exists()) return;

  final legacy = await isar.entries
      .filter()
      .typeEqualTo(EntryType.scratchpad)
      .findAll();

  if (legacy.isNotEmpty) {
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final backup = File(
      '${documents.path}/daftari_removed_scratchpad_backup_$timestamp.json',
    );
    final payload = {
      'schemaVersion': 1,
      'removedAt': DateTime.now().toUtc().toIso8601String(),
      'entries': legacy.map((entry) => entry.toJson()).toList(),
    };
    await backup.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      flush: true,
    );
    await isar.writeTxn(() async {
      await isar.entries.deleteAll(legacy.map((entry) => entry.id).toList());
    });
  }

  await flag.writeAsString('completed', flush: true);
}

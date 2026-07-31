import 'dart:async';

import 'package:debt_tracker/data/models/entry.dart';

enum ImportStrategy { skipExisting, replaceExisting }

class ImportResult {
  const ImportResult({
    required this.inserted,
    required this.replaced,
    required this.skipped,
  });

  final int inserted;
  final int replaced;
  final int skipped;
  int get total => inserted + replaced + skipped;
}

class ImportPreview {
  const ImportPreview({
    required this.newEntries,
    required this.conflictingEntries,
  });

  final int newEntries;
  final int conflictingEntries;
  int get total => newEntries + conflictingEntries;
}

abstract class EntryRepository {
  Stream<List<Entry>> watchRecentEntries({int limit = 6});
  Stream<List<Entry>> watchActiveByType(EntryType type);
  Stream<List<Entry>> watchTrash();
  Stream<List<Entry>> watchAllVisible();
  Future<List<Entry>> search(String query);
  Future<double> totalOwedToMe();
  Future<double> totalIOwe();
  Future<Entry?> getById(int id);
  Future<Entry> save(Entry entry);
  Future<void> markCompleted(int id);
  Future<void> softDelete(int id);
  Future<void> restore(int id);
  Future<void> permanentlyDelete(int id);
  Future<void> emptyTrash();
  Future<void> deleteAllData();
  Future<String> exportJson();
  Future<ImportPreview> previewImport(String jsonString);
  Future<ImportResult> importJson(String jsonString, {ImportStrategy strategy = ImportStrategy.skipExisting});
}

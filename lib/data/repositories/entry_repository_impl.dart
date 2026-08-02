import 'dart:convert';

import 'package:debt_tracker/core/constants/app_constants.dart';
import 'package:debt_tracker/data/models/entry.dart';
import 'package:debt_tracker/domain/repositories/entry_repository.dart';
import 'package:isar_community/isar.dart';

class EntryRepositoryImpl implements EntryRepository {
  EntryRepositoryImpl(this._isar) {
    _initMigration();
  }

  final Isar _isar;

  Future<void> _initMigration() async {
    final nullDebtDates = await _isar.entries
        .filter()
        .debtDateIsNull()
        .findAll();
    final legacyDeleted = await _isar.entries
        .filter()
        .statusEqualTo(EntryStatus.deleted)
        .deletedAtIsNull()
        .findAll();
    if (nullDebtDates.isNotEmpty || legacyDeleted.isNotEmpty) {
      await _isar.writeTxn(() async {
        for (final entry in nullDebtDates) {
          entry.debtDate = entry.createdAt;
          await _isar.entries.put(entry);
        }
        for (final entry in legacyDeleted) {
          entry.deletedAt = entry.updatedAt;
          await _isar.entries.put(entry);
        }
      });
    }
  }

  @override
  Stream<List<Entry>> watchRecentEntries({int limit = 6}) {
    return _isar.entries
        .filter()
        .deletedAtIsNull()
        .watch(fireImmediately: true)
        .map((entries) {
          final sorted = entries.toList();
          sorted.sort(
            (a, b) => (b.debtDate ?? b.createdAt).compareTo(
              a.debtDate ?? a.createdAt,
            ),
          );
          return sorted.take(limit).toList();
        });
  }

  @override
  Stream<List<Entry>> watchActiveByType(EntryType type) {
    return _isar.entries
        .filter()
        .statusEqualTo(EntryStatus.active)
        .deletedAtIsNull()
        .typeEqualTo(type)
        .watch(fireImmediately: true)
        .map((entries) {
          final sorted = entries.toList();
          sorted.sort(
            (a, b) => (b.debtDate ?? b.createdAt).compareTo(
              a.debtDate ?? a.createdAt,
            ),
          );
          return sorted;
        });
  }

  @override
  Stream<List<Entry>> watchTrash() {
    return _isar.entries
        .filter()
        .deletedAtIsNotNull()
        .sortByDeletedAtDesc()
        .watch(fireImmediately: true);
  }

  @override
  Stream<List<Entry>> watchAllVisible() {
    return _isar.entries
        .filter()
        .deletedAtIsNull()
        .watch(fireImmediately: true)
        .map((entries) {
          final sorted = entries.toList();
          sorted.sort(
            (a, b) => (b.debtDate ?? b.createdAt).compareTo(
              a.debtDate ?? a.createdAt,
            ),
          );
          return sorted;
        });
  }

  @override
  Future<List<Entry>> search(String query) async {
    final term = query.trim();
    if (term.isEmpty) {
      return <Entry>[];
    }
    return _isar.entries
        .filter()
        .deletedAtIsNull()
        .group(
          (query) => query
              .titleContains(term, caseSensitive: false)
              .or()
              .noteContains(term, caseSensitive: false),
        )
        .sortByUpdatedAtDesc()
        .findAll();
  }

  @override
  Future<double> totalOwedToMe() async {
    final items = await _isar.entries
        .filter()
        .statusEqualTo(EntryStatus.active)
        .deletedAtIsNull()
        .typeEqualTo(EntryType.owedToMe)
        .findAll();
    return items.fold<double>(
      0,
      (total, entry) => total + entry.remainingAmount,
    );
  }

  @override
  Future<double> totalIOwe() async {
    final items = await _isar.entries
        .filter()
        .statusEqualTo(EntryStatus.active)
        .deletedAtIsNull()
        .typeEqualTo(EntryType.owedByMe)
        .findAll();
    return items.fold<double>(
      0,
      (total, entry) => total + entry.remainingAmount,
    );
  }

  @override
  Future<Entry?> getById(int id) {
    return _isar.entries.get(id);
  }

  @override
  Future<Entry> save(Entry entry) async {
    final now = DateTime.now();
    final existing = entry.id != Isar.autoIncrement
        ? await getById(entry.id)
        : null;
    if (existing == null) {
      entry.createdAt = now;
      entry.updatedAt = now;
      entry.debtDate ??= now;
    } else {
      entry.createdAt = existing.createdAt;
      entry.updatedAt = now;
      entry.deletedAt = existing.deletedAt; // Preserve deleted state on save
    }
    if (entry.title.trim().isEmpty) {
      throw ArgumentError('Title is required.');
    }
    if (entry.amount == null || entry.amount! <= 0) {
      throw ArgumentError('Amount is required for debt entries.');
    }
    await _isar.writeTxn(() async {
      await _isar.entries.put(entry);
    });
    return entry;
  }

  @override
  Future<void> markCompleted(int id) async {
    final entry = await getById(id);
    if (entry == null || !entry.markCompleted(completedAt: DateTime.now())) {
      return;
    }
    await _isar.writeTxn(() async {
      await _isar.entries.put(entry);
    });
  }

  @override
  Future<void> softDelete(int id) async {
    final entry = await getById(id);
    if (entry == null) {
      return;
    }
    // We preserve the old status so it still displays correctly in the trash
    entry.deletedAt = DateTime.now();
    entry.updatedAt = DateTime.now();
    await _isar.writeTxn(() async {
      await _isar.entries.put(entry);
    });
  }

  @override
  Future<void> restore(int id) async {
    final entry = await getById(id);
    if (entry == null) {
      return;
    }
    // For legacy entries that had their status overwritten, default to active
    if (entry.status == EntryStatus.deleted) {
      entry.status = EntryStatus.active;
    }
    entry.deletedAt = null;
    entry.updatedAt = DateTime.now();
    await _isar.writeTxn(() async {
      await _isar.entries.put(entry);
    });
  }

  @override
  Future<void> permanentlyDelete(int id) async {
    await _isar.writeTxn(() async {
      await _isar.entries.delete(id);
    });
  }

  @override
  Future<void> emptyTrash() async {
    final trash = await _isar.entries.filter().deletedAtIsNotNull().findAll();
    await _isar.writeTxn(() async {
      await _isar.entries.deleteAll(trash.map((entry) => entry.id).toList());
    });
  }

  @override
  Future<void> deleteAllData() async {
    await _isar.writeTxn(() async {
      await _isar.entries.clear();
    });
  }

  @override
  Future<String> exportJson() async {
    final entries = await _isar.entries.where().sortByUpdatedAtDesc().findAll();
    final payload = <String, dynamic>{
      'app': AppConstants.appName,
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'entries': entries.map((entry) => entry.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  @override
  Future<ImportPreview> previewImport(String jsonString) async {
    final decoded = jsonDecode(jsonString);
    final entries =
        (decoded is Map<String, dynamic> ? decoded['entries'] : null)
            as List<dynamic>?;
    if (entries == null) {
      throw FormatException('Invalid backup file.');
    }

    final imported = entries
        .whereType<Map<String, dynamic>>()
        .map(entryFromJson)
        .where((entry) => entry.type != EntryType.scratchpad)
        .toList(growable: false);

    int newEntries = 0;
    int conflictingEntries = 0;

    for (final entry in imported) {
      if (entry.id != Isar.autoIncrement && await getById(entry.id) != null) {
        conflictingEntries++;
      } else {
        newEntries++;
      }
    }

    return ImportPreview(
      newEntries: newEntries,
      conflictingEntries: conflictingEntries,
    );
  }

  @override
  Future<ImportResult> importJson(
    String jsonString, {
    ImportStrategy strategy = ImportStrategy.skipExisting,
  }) async {
    final decoded = jsonDecode(jsonString);
    final entries =
        (decoded is Map<String, dynamic> ? decoded['entries'] : null)
            as List<dynamic>?;
    if (entries == null) {
      throw FormatException('Invalid backup file.');
    }
    final imported = entries
        .whereType<Map<String, dynamic>>()
        .map(entryFromJson)
        .where((entry) => entry.type != EntryType.scratchpad)
        .toList(growable: false);
    if (imported.isEmpty) {
      return const ImportResult(inserted: 0, replaced: 0, skipped: 0);
    }

    int inserted = 0;
    int replaced = 0;
    int skipped = 0;

    final toSave = <Entry>[];

    for (final entry in imported) {
      if (entry.id != Isar.autoIncrement) {
        final existing = await getById(entry.id);
        if (existing != null) {
          if (strategy == ImportStrategy.replaceExisting) {
            toSave.add(entry);
            replaced++;
          } else {
            skipped++;
          }
          continue;
        }
      }
      toSave.add(entry);
      inserted++;
    }

    if (toSave.isNotEmpty) {
      await _isar.writeTxn(() async {
        await _isar.entries.putAll(toSave);
      });
    }

    return ImportResult(
      inserted: inserted,
      replaced: replaced,
      skipped: skipped,
    );
  }
}

EntryRepository createEntryRepository({required Isar isar}) {
  return EntryRepositoryImpl(isar);
}

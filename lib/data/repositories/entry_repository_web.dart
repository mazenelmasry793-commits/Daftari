import 'dart:async';
import 'dart:convert';
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:debt_tracker/core/constants/app_constants.dart';
import 'package:debt_tracker/data/models/entry.dart';
import 'package:debt_tracker/domain/repositories/entry_repository.dart';
import 'package:isar_community/isar.dart';

EntryRepository createEntryRepository({Isar? isar}) {
  return WebEntryRepository();
}

class WebEntryRepository implements EntryRepository {
  WebEntryRepository() {
    _loadFromStorage();
  }

  static const String _storageKey = 'debt_tracker_entries_v1';

  final List<Entry> _entries = <Entry>[];
  final StreamController<void> _changes = StreamController<void>.broadcast();
  bool _loaded = false;
  int _nextId = 1;

  void _loadFromStorage() {
    if (_loaded) {
      return;
    }
    _loaded = true;

    final raw = html.window.localStorage[_storageKey];
    if (raw == null || raw.trim().isEmpty) {
      _nextId = 1;
      return;
    }

    var migratedLegacyDeleted = false;
    try {
      final decoded = jsonDecode(raw);
      final entries =
          (decoded is Map<String, dynamic> ? decoded['entries'] : null)
              as List<dynamic>?;
      if (entries != null) {
        _entries
          ..clear()
          ..addAll(
            entries
                .whereType<Map<String, dynamic>>()
                .map((e) {
                  final entry = entryFromJson(e);
                  entry.debtDate ??= entry.createdAt;
                  if (entry.status == EntryStatus.deleted &&
                      entry.deletedAt == null) {
                    entry.deletedAt = entry.updatedAt;
                    migratedLegacyDeleted = true;
                  }
                  return entry;
                })
                .toList(growable: false),
          );
      }
    } catch (_) {
      _entries.clear();
    }
    _syncNextId();
    if (migratedLegacyDeleted) {
      _persist();
    }
  }

  void _syncNextId() {
    final maxId = _entries.fold<int>(
      0,
      (maxValue, entry) => entry.id > maxValue ? entry.id : maxValue,
    );
    _nextId = maxId + 1;
  }

  void _persist() {
    final payload = <String, dynamic>{
      'app': AppConstants.appName,
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'entries': _entries.map((entry) => entry.toJson()).toList(),
    };
    html.window.localStorage[_storageKey] = const JsonEncoder.withIndent(
      '  ',
    ).convert(payload);
    _changes.add(null);
  }

  Entry _cloneEntry(Entry entry) => entryFromJson(entry.toJson());

  List<Entry> _sortedVisibleEntries() {
    final entries = _entries
        .where((entry) => !entry.isDeleted)
        .map(_cloneEntry)
        .toList();
    entries.sort(
      (a, b) =>
          (b.debtDate ?? b.createdAt).compareTo(a.debtDate ?? a.createdAt),
    );
    return entries;
  }

  List<Entry> _sortedActiveByType(EntryType type) {
    final entries = _entries
        .where(
          (entry) =>
              !entry.isDeleted &&
              entry.status == EntryStatus.active &&
              entry.type == type,
        )
        .map(_cloneEntry)
        .toList();
    entries.sort(
      (a, b) =>
          (b.debtDate ?? b.createdAt).compareTo(a.debtDate ?? a.createdAt),
    );
    return entries;
  }

  List<Entry> _sortedTrash() {
    final entries = _entries
        .where((entry) => entry.isDeleted)
        .map(_cloneEntry)
        .toList();
    entries.sort((a, b) {
      final left = b.deletedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final right = a.deletedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return left.compareTo(right);
    });
    return entries;
  }

  List<Entry> _recentEntries(int limit) {
    final entries = _entries
        .where((entry) => entry.deletedAt == null)
        .map(_cloneEntry)
        .toList();
    entries.sort(
      (a, b) =>
          (b.debtDate ?? b.createdAt).compareTo(a.debtDate ?? a.createdAt),
    );
    return entries.take(limit).toList(growable: false);
  }

  List<Entry> _snapshot() {
    final entries = _entries.map(_cloneEntry).toList();
    entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return entries;
  }

  Stream<List<Entry>> _watch(List<Entry> Function() selector) {
    late final StreamController<List<Entry>> controller;
    StreamSubscription<void>? subscription;

    controller = StreamController<List<Entry>>.broadcast(
      onListen: () {
        Future.microtask(() {
          if (!controller.isClosed) controller.add(selector());
        });
        subscription = _changes.stream.listen((_) {
          if (!controller.isClosed) {
            controller.add(selector());
          }
        });
      },
      onCancel: () async {
        await subscription?.cancel();
      },
    );

    return controller.stream;
  }

  Entry? _findById(int id) {
    for (final entry in _entries) {
      if (entry.id == id) {
        return entry;
      }
    }
    return null;
  }

  @override
  Stream<List<Entry>> watchRecentEntries({int limit = 6}) {
    return _watch(() => _recentEntries(limit));
  }

  @override
  Stream<List<Entry>> watchActiveByType(EntryType type) {
    return _watch(() => _sortedActiveByType(type));
  }

  @override
  Stream<List<Entry>> watchTrash() {
    return _watch(_sortedTrash);
  }

  @override
  Stream<List<Entry>> watchAllVisible() {
    return _watch(_sortedVisibleEntries);
  }

  @override
  Future<List<Entry>> search(String query) async {
    final term = query.trim().toLowerCase();
    if (term.isEmpty) {
      return <Entry>[];
    }
    final matches = _entries
        .where((entry) {
          final title = entry.title.toLowerCase();
          final note = entry.note?.toLowerCase() ?? '';
          return !entry.isDeleted &&
              (title.contains(term) || note.contains(term));
        })
        .map(_cloneEntry)
        .toList();
    matches.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return matches;
  }

  @override
  Future<double> totalOwedToMe() async {
    return _entries
        .where(
          (entry) =>
              !entry.isDeleted &&
              entry.status == EntryStatus.active &&
              entry.type == EntryType.owedToMe,
        )
        .fold<double>(0, (total, entry) => total + entry.remainingAmount);
  }

  @override
  Future<double> totalIOwe() async {
    return _entries
        .where(
          (entry) =>
              !entry.isDeleted &&
              entry.status == EntryStatus.active &&
              entry.type == EntryType.owedByMe,
        )
        .fold<double>(0, (total, entry) => total + entry.remainingAmount);
  }

  @override
  Future<Entry?> getById(int id) async {
    final entry = _findById(id);
    return entry == null ? null : _cloneEntry(entry);
  }

  @override
  Future<Entry> save(Entry entry) async {
    final now = DateTime.now();
    final existing = entry.id > 0 ? _findById(entry.id) : null;
    final record = _cloneEntry(entry);

    if (record.title.trim().isEmpty) {
      throw ArgumentError('Title is required.');
    }
    if (record.type != EntryType.scratchpad &&
        (record.amount == null || record.amount! <= 0)) {
      throw ArgumentError('Amount is required for debt entries.');
    }
    if (record.type == EntryType.scratchpad) {
      record.amount ??= null;
    }

    if (existing == null) {
      if (record.id <= 0 ||
          record.id == Isar.autoIncrement ||
          _findById(record.id) != null) {
        record.id = _nextId++;
      } else {
        _nextId = record.id >= _nextId ? record.id + 1 : _nextId;
      }
      record.createdAt = now;
      record.updatedAt = now;
      record.debtDate ??= now;
    } else {
      record.id = existing.id;
      record.createdAt = existing.createdAt;
      record.updatedAt = now;
      record.deletedAt = existing.deletedAt;
      final index = _entries.indexWhere((item) => item.id == record.id);
      if (index != -1) {
        _entries[index] = record;
        _persist();
        return _cloneEntry(record);
      }
    }

    _entries.add(record);
    _persist();
    return _cloneEntry(record);
  }

  @override
  Future<void> markCompleted(int id) async {
    final entry = _findById(id);
    if (entry == null) {
      return;
    }
    entry.status = EntryStatus.completed;
    entry.updatedAt = DateTime.now();
    _persist();
  }

  @override
  Future<void> softDelete(int id) async {
    final entry = _findById(id);
    if (entry == null) {
      return;
    }
    entry.deletedAt = DateTime.now();
    entry.updatedAt = DateTime.now();
    _persist();
  }

  @override
  Future<void> restore(int id) async {
    final entry = _findById(id);
    if (entry == null) {
      return;
    }
    if (entry.status == EntryStatus.deleted) {
      entry.status = EntryStatus.active;
    }
    entry.deletedAt = null;
    entry.updatedAt = DateTime.now();
    _persist();
  }

  @override
  Future<void> permanentlyDelete(int id) async {
    _entries.removeWhere((entry) => entry.id == id);
    _persist();
  }

  @override
  Future<void> emptyTrash() async {
    _entries.removeWhere((entry) => entry.isDeleted);
    _persist();
  }

  @override
  Future<void> deleteAllData() async {
    _entries.clear();
    _persist();
  }

  @override
  Future<String> exportJson() async {
    final payload = <String, dynamic>{
      'app': AppConstants.appName,
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'entries': _snapshot().map((entry) => entry.toJson()).toList(),
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
        .toList(growable: false);

    int newEntries = 0;
    int conflictingEntries = 0;

    for (final entry in imported) {
      if (entry.id != Isar.autoIncrement && _findById(entry.id) != null) {
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
        .toList(growable: false);
    if (imported.isEmpty) {
      return const ImportResult(inserted: 0, replaced: 0, skipped: 0);
    }

    int inserted = 0;
    int replaced = 0;
    int skipped = 0;

    for (final incoming in imported) {
      final index = _entries.indexWhere((entry) => entry.id == incoming.id);

      if (index != -1) {
        if (strategy == ImportStrategy.replaceExisting) {
          _entries[index] = incoming;
          replaced++;
        } else {
          skipped++;
        }
        continue;
      }

      if (incoming.id <= 0 || incoming.id == Isar.autoIncrement) {
        incoming.id = _nextId++;
      } else {
        _nextId = incoming.id >= _nextId ? incoming.id + 1 : _nextId;
      }

      _entries.add(incoming);
      inserted++;
    }

    _persist();
    return ImportResult(
      inserted: inserted,
      replaced: replaced,
      skipped: skipped,
    );
  }
}

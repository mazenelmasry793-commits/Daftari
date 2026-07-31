import 'package:isar_community/isar.dart';

part 'entry.g.dart';

enum EntryType {
  owedToMe('owed_to_me', 'Owed To Me'),
  owedByMe('owed_by_me', 'Owed By Me'),
  scratchpad('scratchpad', 'Scratchpad');

  const EntryType(this.dbValue, this.label);

  final String dbValue;
  final String label;

  bool get isDebt => this != scratchpad;

  static EntryType fromDbValue(String value) {
    return EntryType.values.firstWhere(
      (entryType) => entryType.dbValue == value,
      orElse: () => EntryType.owedToMe,
    );
  }
}

enum EntryStatus {
  active('active', 'Active'),
  completed('completed', 'Completed'),
  deleted('deleted', 'Deleted');

  const EntryStatus(this.dbValue, this.label);

  final String dbValue;
  final String label;

  bool get isVisible => this != deleted;

  static EntryStatus fromDbValue(String value) {
    return EntryStatus.values.firstWhere(
      (status) => status.dbValue == value,
      orElse: () => EntryStatus.active,
    );
  }
}

@collection
class Entry {
  Id id = Isar.autoIncrement;

  late String title;

  double? amount;

  String? note;

  @Enumerated(EnumType.value, 'dbValue')
  late EntryType type;

  @Enumerated(EnumType.value, 'dbValue')
  late EntryStatus status;

  late DateTime createdAt;

  late DateTime updatedAt;

  DateTime? deletedAt;

  @ignore
  bool get isDeleted => deletedAt != null || status == EntryStatus.deleted;

  @Index()
  DateTime? debtDate;

  List<Payment> payments = [];

  @ignore
  double get paidAmount => payments.fold(0.0, (sum, p) => sum + p.amount);

  @ignore
  double get remainingAmount => (amount ?? 0) - paidAmount;
}

@embedded
class Payment {
  Payment();

  late double amount;

  late DateTime date;

  String? note;
}

extension EntryJson on Entry {
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'amount': amount,
      'note': note,
      'type': type.dbValue,
      'status': status.dbValue,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'deletedAt': deletedAt?.toIso8601String(),
      'debtDate': debtDate?.toIso8601String(),
      'payments': payments
          .map(
            (p) => {
              'amount': p.amount,
              'date': p.date.toIso8601String(),
              'note': p.note,
            },
          )
          .toList(),
    };
  }
}

extension IsarEntryCollectionAlias on Isar {
  IsarCollection<Entry> get entries => entrys;
}

Entry entryFromJson(Map<String, dynamic> json) {
  final entry = Entry()
    ..id = (json['id'] as num?)?.toInt() ?? Isar.autoIncrement
    ..title = (json['title'] as String?)?.trim() ?? ''
    ..amount = (json['amount'] as num?)?.toDouble()
    ..note = json['note'] as String?
    ..type = EntryType.fromDbValue(
      (json['type'] as String?) ?? EntryType.owedToMe.dbValue,
    )
    ..status = EntryStatus.fromDbValue(
      (json['status'] as String?) ?? EntryStatus.active.dbValue,
    )
    ..createdAt =
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now()
    ..updatedAt =
        DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now()
    ..deletedAt = DateTime.tryParse(json['deletedAt'] as String? ?? '')
    ..debtDate = DateTime.tryParse(json['debtDate'] as String? ?? '')
    ..payments =
        (json['payments'] as List<dynamic>?)?.map((p) {
          final pMap = p as Map<String, dynamic>;
          return Payment()
            ..amount = (pMap['amount'] as num).toDouble()
            ..date =
                DateTime.tryParse(pMap['date'] as String? ?? '') ??
                DateTime.now()
            ..note = pMap['note'] as String?;
        }).toList() ??
        [];
  if (entry.title.isEmpty) {
    entry.title = 'Untitled entry';
  }
  return entry;
}

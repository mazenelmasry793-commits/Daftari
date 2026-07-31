import 'package:debt_tracker/core/utils/formatters.dart';
import 'package:debt_tracker/data/models/entry.dart';
import 'package:debt_tracker/presentation/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

class EntryFormScreen extends ConsumerStatefulWidget {
  const EntryFormScreen({
    required this.initialType,
    this.entry,
    this.conversionType,
    super.key,
  });

  final EntryType initialType;
  final Entry? entry;
  final EntryType? conversionType;

  @override
  ConsumerState<EntryFormScreen> createState() => _EntryFormScreenState();
}

class _EntryFormScreenState extends ConsumerState<EntryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late EntryType _type;
  late DateTime _debtDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _type = widget.conversionType ?? entry?.type ?? widget.initialType;
    _debtDate = entry?.debtDate ?? DateTime.now();
    _titleController = TextEditingController(text: entry?.title ?? '');
    _amountController = TextEditingController(
      text: entry?.amount?.toString() ?? '',
    );
    _noteController = TextEditingController(text: entry?.note ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double? _parseAmount(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed.replaceAll(',', '.'));
  }

  Future<void> _save() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid || _saving) return;

    setState(() => _saving = true);
    try {
      final repository = ref.read(entryRepositoryProvider);
      final now = DateTime.now();
      final existing = widget.entry;
      final entry = Entry()
        ..id = existing?.id ?? Isar.autoIncrement
        ..title = _titleController.text.trim()
        ..amount = _type == EntryType.scratchpad
            ? _parseAmount(_amountController.text)
            : _parseAmount(_amountController.text)!
        ..note = _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim()
        ..type = _type
        ..debtDate = _debtDate
        ..status = existing?.status ?? EntryStatus.active
        ..createdAt = existing?.createdAt ?? now
        ..updatedAt = now
        ..deletedAt = existing?.deletedAt
        ..payments = List<Payment>.from(
          existing?.payments ?? const <Payment>[],
        );

      final saved = await repository.save(entry);
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String get _typeString {
    switch (_type) {
      case EntryType.owedToMe:
        return 'Owed To Me';
      case EntryType.owedByMe:
        return 'Owed By Me';
      case EntryType.scratchpad:
        return 'Scratchpad';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isScratchpad = _type == EntryType.scratchpad;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.entry == null ? 'New $_typeString' : 'Edit $_typeString',
        ),
      ),
      body: Form(
        key: _formKey,
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              children: [
                TextFormField(
                  controller: _titleController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'Who owes what?',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Title is required.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: isScratchpad ? 'Amount (optional)' : 'Amount',
                    hintText: '0.00',
                  ),
                  validator: (value) {
                    final amount = _parseAmount(value ?? '');
                    if (!isScratchpad && (amount == null || amount <= 0)) {
                      return 'Amount is required for debt entries.';
                    }
                    if (amount != null && amount <= 0) {
                      return 'Amount must be greater than zero.';
                    }
                    final paidAmount = widget.entry?.paidAmount ?? 0;
                    if (!isScratchpad &&
                        amount != null &&
                        amount < paidAmount) {
                      return 'Amount cannot be less than the paid amount.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _noteController,
                  maxLines: 5,
                  minLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Note',
                    hintText:
                        'Add a reminder, explanation, or rough calculation.',
                  ),
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _debtDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (date != null) {
                      setState(() => _debtDate = date);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Date'),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(AppFormatters.date.format(_debtDate)),
                        const Icon(Icons.calendar_today_rounded, size: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Theme.of(context).colorScheme.surface,
                      Theme.of(
                        context,
                      ).colorScheme.surface.withValues(alpha: 0.0),
                    ],
                    stops: const [0.4, 1.0],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        child: Text(
                          widget.entry == null ? 'Save' : 'Save Changes',
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

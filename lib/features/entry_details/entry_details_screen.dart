import 'package:debt_tracker/core/utils/formatters.dart';
import 'package:debt_tracker/core/widgets/confirm_dialog.dart';
import 'package:debt_tracker/core/widgets/empty_state.dart';
import 'package:debt_tracker/data/models/entry.dart';
import 'package:debt_tracker/features/entry_details/widgets/add_payment_dialog.dart';
import 'package:debt_tracker/features/entry_form/entry_form_screen.dart';
import 'package:debt_tracker/presentation/providers/app_providers.dart';
import 'package:debt_tracker/presentation/widgets/app_page_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EntryDetailsScreen extends ConsumerStatefulWidget {
  const EntryDetailsScreen({required this.entryId, super.key});

  final int entryId;

  @override
  ConsumerState<EntryDetailsScreen> createState() => _EntryDetailsScreenState();
}

class _EntryDetailsScreenState extends ConsumerState<EntryDetailsScreen> {
  Future<Entry?>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Entry?> _load() {
    return ref.read(entryRepositoryProvider).getById(widget.entryId);
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _edit(Entry entry) async {
    final result = await Navigator.of(context).push<Entry?>(
      AppPageRoute(
        child: EntryFormScreen(entry: entry, initialType: entry.type),
      ),
    );
    if (result != null) {
      _refresh();
    }
  }

  Future<void> _markCompleted(Entry entry) async {
    if (entry.type != EntryType.scratchpad) {
      final remaining = entry.remainingAmount;
      if (remaining > 0) {
        final payment = Payment()
          ..amount = remaining
          ..date = DateTime.now()
          ..note = 'Auto-filled on completion';
        entry.payments = List<Payment>.from(entry.payments)..add(payment);
      }
    }
    entry.status = EntryStatus.completed;
    entry.updatedAt = DateTime.now();
    await ref.read(entryRepositoryProvider).save(entry);
    _refresh();
  }

  Future<void> _restore(Entry entry) async {
    await ref.read(entryRepositoryProvider).restore(entry.id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete(Entry entry) async {
    final confirm = await showConfirmationDialog(
      context,
      title: entry.isDeleted ? 'Delete forever?' : 'Move to trash?',
      message: entry.isDeleted
          ? 'This permanently deletes the entry from the database.'
          : 'The entry will move to Trash and can be restored later.',
      confirmLabel: entry.isDeleted ? 'Delete Forever' : 'Move to Trash',
      destructive: true,
    );
    if (!confirm) return;
    if (entry.isDeleted) {
      await ref.read(entryRepositoryProvider).permanentlyDelete(entry.id);
      if (mounted) Navigator.of(context).pop();
    } else {
      await ref.read(entryRepositoryProvider).softDelete(entry.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _addPayment(Entry entry) async {
    final payment = await showDialog<Payment>(
      context: context,
      builder: (_) => const AddPaymentDialog(),
    );
    if (payment == null) return;

    entry.payments = List.from(entry.payments)..add(payment);
    entry.updatedAt = DateTime.now();

    if (entry.type != EntryType.scratchpad && entry.remainingAmount <= 0) {
      entry.status = EntryStatus.completed;
    }

    await ref.read(entryRepositoryProvider).save(entry);
    _refresh();
  }

  Future<void> _deletePayment(Entry entry, Payment payment) async {
    final confirm = await showConfirmationDialog(
      context,
      title: 'Delete Payment?',
      message: 'Are you sure you want to delete this payment?',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirm) return;

    entry.payments = List.from(entry.payments)..remove(payment);
    entry.updatedAt = DateTime.now();

    if (entry.type != EntryType.scratchpad &&
        entry.remainingAmount > 0 &&
        entry.status == EntryStatus.completed) {
      entry.status = EntryStatus.active;
    }

    await ref.read(entryRepositoryProvider).save(entry);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: FutureBuilder<Entry?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final entry = snapshot.data;
          if (entry == null) {
            return const EmptyState(
              icon: Icons.find_in_page_outlined,
              title: 'Entry not found',
              message: 'This item may have been permanently deleted.',
            );
          }

          final original = entry.amount ?? 0.0;
          final paid = entry.paidAmount;
          final remaining = entry.remainingAmount;

          double progress = 0;
          if (original > 0) {
            progress = paid / original;
            if (progress > 1.0) progress = 1.0;
            if (progress < 0.0) progress = 0.0;
          }

          final bool isScratchpad = entry.type == EntryType.scratchpad;
          final bool isDeleted = entry.isDeleted;

          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                children: [
                  Text(
                    entry.title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (!isScratchpad) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _AmountCard(
                            label: 'Original',
                            amount: original,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _AmountCard(
                            label: 'Paid',
                            amount: paid,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _AmountCard(
                            label: 'Remaining',
                            amount: remaining,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(
                          alpha: 0.3,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Paid',
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${(progress * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: progress,
                            backgroundColor: scheme.surfaceContainerHighest,
                            color: Colors.blue,
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  Text(
                    'Date: ${AppFormatters.date.format(entry.debtDate ?? entry.createdAt)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (entry.note?.isNotEmpty == true)
                    Text(
                      'Note: ${entry.note}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                  if (!isScratchpad) ...[
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Payments',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        if (!isDeleted)
                          IconButton.filledTonal(
                            onPressed: () => _addPayment(entry),
                            icon: const Icon(Icons.add_rounded),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (entry.payments.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'No data yet',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ),
                      )
                    else
                      ...entry.payments.map(
                        (p) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            AppFormatters.moneyValue(p.amount),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(AppFormatters.dateTime.format(p.date)),
                              if (p.note?.isNotEmpty == true) Text(p.note!),
                            ],
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: scheme.error,
                            ),
                            onPressed: isDeleted
                                ? null
                                : () => _deletePayment(entry, p),
                          ),
                        ),
                      ),
                  ],
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
                      stops: const [0.6, 1.0],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          if (!isDeleted)
                            FilledButton.icon(
                              onPressed: () => _edit(entry),
                              icon: const Icon(Icons.edit_rounded),
                              label: const Text('Edit'),
                            ),
                          if (!isDeleted &&
                              entry.status == EntryStatus.active &&
                              entry.type != EntryType.scratchpad)
                            FilledButton.tonalIcon(
                              onPressed: () => _markCompleted(entry),
                              icon: const Icon(
                                Icons.check_circle_outline_rounded,
                              ),
                              label: const Text('Mark Completed'),
                            ),
                          if (isDeleted)
                            FilledButton.tonalIcon(
                              onPressed: () => _restore(entry),
                              icon: const Icon(Icons.restore_rounded),
                              label: const Text('Restore'),
                            ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: scheme.error,
                              foregroundColor: scheme.onError,
                            ),
                            onPressed: () => _delete(entry),
                            child: Text(
                              isDeleted ? 'Delete Forever' : 'Delete',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AmountCard extends StatelessWidget {
  const _AmountCard({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              AppFormatters.moneyValue(amount),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

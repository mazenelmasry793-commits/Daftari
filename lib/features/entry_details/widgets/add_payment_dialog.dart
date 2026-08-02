import 'package:debt_tracker/data/models/entry.dart';
import 'package:flutter/material.dart';

class AddPaymentDialog extends StatefulWidget {
  const AddPaymentDialog({super.key, this.sheetStyle = false});

  final bool sheetStyle;

  @override
  State<AddPaymentDialog> createState() => _AddPaymentDialogState();
}

class _AddPaymentDialogState extends State<AddPaymentDialog> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) return;

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) return;

    final payment = Payment()
      ..amount = amount
      ..date = DateTime.now()
      ..note = _noteController.text.trim().isNotEmpty
          ? _noteController.text.trim()
          : null;

    Navigator.of(context).pop(payment);
  }

  @override
  Widget build(BuildContext context) {
    final fields = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Amount',
            prefixText: '\$ ',
          ),
          autofocus: true,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _noteController,
          decoration: const InputDecoration(labelText: 'Note (Optional)'),
        ),
      ],
    );

    if (widget.sheetStyle) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add Payment',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              fields,
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _submit, child: const Text('Add')),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return AlertDialog(
      title: const Text('Add Payment'),
      content: fields,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}

import 'package:flutter/material.dart';

class PinDots extends StatelessWidget {
  const PinDots({
    required this.length,
    required this.maxLength,
    super.key,
  });

  final int length;
  final int maxLength;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(maxLength, (index) {
        final filled = index < length;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 6),
          height: 14,
          width: 14,
          decoration: BoxDecoration(
            color: filled ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.35),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}

class PinPad extends StatelessWidget {
  const PinPad({
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
    super.key,
  });

  final void Function(String digit) onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final keys = <String>[
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9',
      'clear',
      '0',
      'back',
    ];

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Column(
        children: [
          GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: keys.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
          ),
          itemBuilder: (context, index) {
            final key = keys[index];
            if (key == 'clear') {
              return _KeyButton(icon: Icons.refresh_rounded, onTap: onClear);
            }
            if (key == 'back') {
              return _KeyButton(icon: Icons.backspace_outlined, onTap: onBackspace);
            }
            return _KeyButton(label: key, onTap: () => onDigit(key));
          },
        ),
        ],
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({
    this.label,
    this.icon,
    required this.onTap,
  });

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Center(
          child: icon != null
              ? Icon(icon, color: scheme.onSurfaceVariant)
              : Text(
                  label!,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
        ),
      ),
    );
  }
}


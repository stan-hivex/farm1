import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BackChevron extends StatelessWidget {
  const BackChevron({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return IconButton(
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/');
        }
      },
      style: IconButton.styleFrom(
        backgroundColor: colorScheme.surfaceContainerHighest,
        foregroundColor: colorScheme.onSurface,
        hoverColor: colorScheme.primary.withAlpha(24),
        fixedSize: const Size.square(40),
        shape: const CircleBorder(),
      ),
      icon: const Icon(Icons.chevron_left_rounded),
    );
  }
}

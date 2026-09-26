import 'package:flutter/material.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF08111F),
            Color(0xFF0D1830),
            Color(0xFF101D38),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.075),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            blurRadius: 40,
            spreadRadius: -18,
            offset: const Offset(0, 22),
            color: Colors.black.withValues(alpha: 0.45),
          ),
        ],
      ),
      child: child,
    );
  }
}

class BrandTitle extends StatelessWidget {
  const BrandTitle({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: compact ? 40 : 48,
          height: compact ? 40 : 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: const LinearGradient(
              colors: <Color>[Color(0xFF4EE8C1), Color(0xFF49A9FF)],
            ),
          ),
          child: Icon(
            Icons.swap_horiz_rounded,
            size: compact ? 25 : 30,
            color: const Color(0xFF07101E),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'LanBridge 05',
          style: (compact
                  ? theme.textTheme.titleLarge
                  : theme.textTheme.headlineSmall)
              ?.copyWith(fontWeight: FontWeight.w800, color: Colors.white),
        ),
      ],
    );
  }
}

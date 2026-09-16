import 'package:flutter/material.dart';

import '../models/models.dart';

class TeamAvatar extends StatelessWidget {
  final Team? team;
  final String? icon;
  final double size;

  const TeamAvatar({super.key, this.team, this.icon, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Text(
        team?.icon ?? icon ?? '⚽',
        style: TextStyle(fontSize: size * 0.48),
      ),
    );
  }
}

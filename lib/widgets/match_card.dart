import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/league.dart';
import '../pages/match_details_page.dart';
import '../providers/app_state.dart';
import '../utils/helpers.dart';
import 'team_avatar.dart';

class MatchCard extends StatelessWidget {
  final MatchGame match;
  final bool showDate;
  final bool compact;

  const MatchCard({
    super.key,
    required this.match,
    this.showDate = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final home = state.findTeam(match.homeTeamId);
    final away = match.isBye ? null : state.findTeam(match.awayTeamId);
    final cs = Theme.of(context).colorScheme;
    final live = match.status == MatchStatus.live;
    final done = match.status == MatchStatus.finished;
    final dense = compact || state.compactCards;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => MatchDetailsPage(matchId: match.id),
          ));
        },
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: dense ? 10 : 14,
          ),
          child: Column(
            children: [
              if (showDate)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          match.stage.label(
                            week: match.week,
                            groupName: match.groupName,
                          ),
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (match.startTime != null)
                        Text(
                          formatDateTime(match.startTime!),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                        ),
                    ],
                  ),
                ),
              Row(
                children: [
                  Expanded(child: _teamCol(home?.icon, home?.name ?? '?', true)),
                  _scoreChip(context, live: live, done: done),
                  Expanded(
                    child: _teamCol(
                      away?.icon ?? (match.isBye ? '—' : '?'),
                      match.isBye ? 'Bay' : (away?.name ?? '?'),
                      false,
                    ),
                  ),
                ],
              ),
              if (live)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '• CANLI ${state.liveMinuteFor(match.id)}\' •',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              if (done && match.usedPenalties)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Pen: ${match.homePenalties} - ${match.awayPenalties}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _teamCol(String? icon, String name, bool home) {
    return Column(
      children: [
        TeamAvatar(icon: icon ?? '⚽', size: compact ? 32 : 40),
        const SizedBox(height: 6),
        Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ],
    );
  }

  Widget _scoreChip(BuildContext context, {required bool live, required bool done}) {
    final scheduled = match.status == MatchStatus.scheduled;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: live
            ? Colors.red.withOpacity(0.12)
            : (done
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : Colors.transparent),
        borderRadius: BorderRadius.circular(20),
        border: scheduled
            ? Border.all(color: Theme.of(context).colorScheme.outlineVariant)
            : null,
      ),
      child: Text(
        scheduled ? 'VS' : '${match.homeGoals} - ${match.awayGoals}',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: live ? Colors.red : Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

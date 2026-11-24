import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/sync/sync_bloc.dart';
import '../../core/theme.dart';
import '../../data/models/location_record.dart';
import '../format.dart';
import 'section_card.dart';

class RecentPointsList extends StatelessWidget {
  const RecentPointsList({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<SyncBloc, SyncState, List<LocationRecord>>(
      selector: (s) => s.recent,
      builder: (context, recent) {
        return SectionCard(
          title: 'Recent points',
          child: recent.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Start tracking to record points.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                )
              : Column(
                  children: [
                    for (final r in recent) _PointTile(record: r),
                  ],
                ),
        );
      },
    );
  }
}

class _PointTile extends StatelessWidget {
  const _PointTile({required this.record});
  final LocationRecord record;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color, String status) = record.isSynced
        ? (Icons.cloud_done_outlined, AppColors.success, 'synced')
        : record.isRetrying
            ? (
                Icons.sync_problem_outlined,
                AppColors.danger,
                'retry #${record.attempts + 1} at ${formatTime(record.nextAttemptAt)}',
              )
            : (Icons.cloud_queue_outlined, AppColors.amber, 'pending');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatCoord(record.latitude, record.longitude),
                  style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  '${formatTime(record.recordedAt)} · ${formatSpeed(record.speed)} · $status',
                  style: TextStyle(color: color.withValues(alpha: 0.85), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

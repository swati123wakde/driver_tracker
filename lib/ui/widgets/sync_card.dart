import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/sync/sync_bloc.dart';
import '../../core/theme.dart';
import '../format.dart';
import 'section_card.dart';

class NetworkCard extends StatelessWidget {
  const NetworkCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SyncBloc, SyncState>(
      builder: (context, state) {
        final bloc = context.read<SyncBloc>();
        return SectionCard(
          title: 'Network',
          trailing: _StatusChip(online: state.isOnline),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                key: const Key('simulate-offline'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Simulate offline'),
                subtitle: const Text(
                  'Points keep recording locally; upload pauses',
                  style: TextStyle(color: AppColors.textMuted),
                ),
                value: state.simulatedOffline,
                onChanged: (v) => bloc.add(SimulatedOfflineToggled(v)),
              ),
              if (state.simulationAvailable) ...[
                const Divider(height: 20),
                Row(
                  children: [
                    const Expanded(child: Text('Mock API failure rate')),
                    Text(
                      '${(state.apiFailureRate * 100).round()}%',
                      style: const TextStyle(
                        color: AppColors.amber,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: state.apiFailureRate,
                  divisions: 10,
                  onChanged: (v) => bloc.add(ApiFailureRateChanged(v)),
                ),
                Text(
                  'Server stored ${state.serverUnique} unique points · '
                  '${state.serverDuplicatesIgnored} duplicate re-sends ignored',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class SyncCard extends StatelessWidget {
  const SyncCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SyncBloc, SyncState>(
      builder: (context, state) {
        return SectionCard(
          title: 'Sync queue',
          trailing: state.isSyncing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _Stat(label: 'Pending', value: state.pending, color: AppColors.amber),
                  _Stat(label: 'Retrying', value: state.retrying, color: AppColors.danger),
                  _Stat(label: 'Synced', value: state.synced, color: AppColors.success),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                state.lastSyncAt == null
                    ? 'No sync yet'
                    : 'Last sync ${formatTime(state.lastSyncAt!)}',
                style: const TextStyle(color: AppColors.textMuted),
              ),
              if (state.lastError != null) ...[
                const SizedBox(height: 6),
                Text(
                  state.lastError!,
                  style: const TextStyle(color: AppColors.danger, fontSize: 12),
                ),
              ],
              const SizedBox(height: 14),
              OutlinedButton.icon(
                key: const Key('sync-now'),
                onPressed: state.isOnline && state.pending > 0 && !state.isSyncing
                    ? () => context.read<SyncBloc>().add(const SyncNowPressed())
                    : null,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('Sync now'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.online});
  final bool online;

  @override
  Widget build(BuildContext context) {
    final color = online ? AppColors.success : AppColors.danger;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(online ? Icons.wifi : Icons.wifi_off, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          online ? 'Online' : 'Offline',
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(label, style: const TextStyle(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

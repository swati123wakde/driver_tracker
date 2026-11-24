import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/tracking/tracking_bloc.dart';
import '../../core/theme.dart';
import '../format.dart';
import 'section_card.dart';

class TrackingCard extends StatelessWidget {
  const TrackingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TrackingBloc, TrackingState>(
      builder: (context, state) {
        final fix = state.lastFix;
        return SectionCard(
          title: 'Tracking',
          trailing: _Pill(
            label: state.sourceLabel,
            icon: Icons.satellite_alt_outlined,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _PulseDot(active: state.isTracking),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      switch (state.status) {
                        TrackingStatus.tracking => 'Tracking live',
                        TrackingStatus.idle => 'Not tracking',
                        TrackingStatus.error => 'Tracking stopped',
                      },
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${state.pointsThisSession} pts',
                    style: const TextStyle(
                      color: AppColors.amber,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _InfoRow(
                icon: Icons.place_outlined,
                text: fix == null
                    ? 'Waiting for first fix…'
                    : formatCoord(fix.latitude, fix.longitude),
              ),
              if (fix != null) ...[
                const SizedBox(height: 6),
                _InfoRow(
                  icon: Icons.speed,
                  text: '${formatSpeed(fix.speed)}  ·  ±${fix.accuracy.toStringAsFixed(0)} m  ·  ${formatTime(fix.timestamp)}',
                ),
              ],
              if (state.errorMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  state.errorMessage!,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton.icon(
                key: const Key('tracking-toggle'),
                onPressed: () => context.read<TrackingBloc>().add(
                      state.isTracking
                          ? const TrackingStopRequested()
                          : const TrackingStartRequested(),
                    ),
                style: state.isTracking
                    ? FilledButton.styleFrom(
                        backgroundColor: AppColors.surfaceHigh,
                        foregroundColor: AppColors.amber,
                        side: const BorderSide(color: AppColors.amber),
                      )
                    : null,
                icon: Icon(state.isTracking ? Icons.stop_rounded : Icons.play_arrow_rounded),
                label: Text(state.isTracking ? 'Stop tracking' : 'Start tracking'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.amber),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: AppColors.amber, fontSize: 12)),
        ],
      ),
    );
  }
}

/// A dot that softly pulses while tracking.
class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.active});
  final bool active;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _PulseDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.active) {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.active ? AppColors.amber : AppColors.textMuted;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            if (widget.active)
              BoxShadow(
                color: AppColors.amber.withValues(alpha: 0.6),
                blurRadius: 4 + 10 * _controller.value,
                spreadRadius: 1 + 3 * _controller.value,
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'widgets/recent_points_list.dart';
import 'widgets/sync_card.dart';
import 'widgets/tracking_card.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.local_shipping_outlined, color: AppColors.amber),
            SizedBox(width: 10),
            Text('Driver Tracker'),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: const [
            TrackingCard(),
            SizedBox(height: 14),
            NetworkCard(),
            SizedBox(height: 14),
            SyncCard(),
            SizedBox(height: 14),
            RecentPointsList(),
          ],
        ),
      ),
    );
  }
}

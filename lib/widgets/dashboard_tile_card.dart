import 'package:flutter/material.dart';

import '../models/dashboard_tile.dart';
import '../theme/app_theme.dart';

class DashboardTileCard extends StatelessWidget {
  const DashboardTileCard({super.key, required this.tile});

  final DashboardTile tile;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: tile.comingSoon
            ? null
            : () => Navigator.of(context).push(
                  MaterialPageRoute(builder: tile.builder),
                ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          ),
          child: Stack(
            children: [
              Opacity(
                opacity: tile.comingSoon ? 0.45 : 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: tile.color,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(tile.icon, color: Colors.white, size: 20),
                    ),
                    const Spacer(),
                    Text(
                      tile.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.royalDeep,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tile.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: AppColors.inkSoft, height: 1.25),
                    ),
                    const Spacer(),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Icon(Icons.chevron_right, size: 16, color: AppColors.inkSoft.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ),
              if (tile.comingSoon)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.royal,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Coming Soon',
                      style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

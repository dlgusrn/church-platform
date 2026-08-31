import 'package:flutter/material.dart';

import '../permission/app_permission.dart';
import '../permission/effective_permission.dart';

enum AppDestinationKey { home, video, audio, work, more }

class AppDestination {
  const AppDestination({
    required this.key,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
  final AppDestinationKey key;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

abstract final class NavigationPolicy {
  static List<AppDestination> available(Set<AppPermission> permissions) {
    final result = <AppDestination>[
      const AppDestination(
        key: AppDestinationKey.home,
        label: '홈',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
      ),
    ];
    if (EffectivePermission.hasAny(permissions, videoNavigationPermissions)) {
      result.add(
        const AppDestination(
          key: AppDestinationKey.video,
          label: '영상',
          icon: Icons.play_circle_outline_rounded,
          selectedIcon: Icons.play_circle_rounded,
        ),
      );
    }
    if (permissions.contains(AppPermission.mediaAudioView)) {
      result.add(
        const AppDestination(
          key: AppDestinationKey.audio,
          label: '음성',
          icon: Icons.headphones_outlined,
          selectedIcon: Icons.headphones_rounded,
        ),
      );
    }
    if (EffectivePermission.hasAny(permissions, workNavigationPermissions)) {
      result.add(
        const AppDestination(
          key: AppDestinationKey.work,
          label: '업무',
          icon: Icons.grid_view_outlined,
          selectedIcon: Icons.grid_view_rounded,
        ),
      );
    }
    result.add(
      const AppDestination(
        key: AppDestinationKey.more,
        label: '더보기',
        icon: Icons.more_horiz_rounded,
        selectedIcon: Icons.more_horiz_rounded,
      ),
    );
    return result;
  }
}

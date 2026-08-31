import 'package:flutter/material.dart';

import '../core/navigation/app_destination.dart';
import '../features/audio/presentation/audio_placeholder_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/more/presentation/more_screen.dart';
import '../features/video/presentation/video_placeholder_screen.dart';
import '../features/work/presentation/work_placeholder_screen.dart';
import 'app_scope.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  AppDestinationKey _selected = AppDestinationKey.home;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final destinations = NavigationPolicy.available(state.effectivePermissions);
    if (!destinations.any((item) => item.key == _selected))
      _selected = AppDestinationKey.home;
    final selectedIndex = destinations.indexWhere(
      (item) => item.key == _selected,
    );
    return Scaffold(
      body: switch (_selected) {
        AppDestinationKey.home => const HomeScreen(),
        AppDestinationKey.video => const VideoPlaceholderScreen(),
        AppDestinationKey.audio => const AudioPlaceholderScreen(),
        AppDestinationKey.work => const WorkPlaceholderScreen(),
        AppDestinationKey.more => const MoreScreen(),
      },
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE9EDEB))),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            height: 68,
            elevation: 0,
            backgroundColor: Colors.white,
            indicatorColor: const Color(0xFFE4EFEB),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) =>
                setState(() => _selected = destinations[index].key),
            destinations: [
              for (final item in destinations)
                NavigationDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.selectedIcon),
                  label: item.label,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

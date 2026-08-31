import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../home/domain/home_models.dart';
import '../data/live_access_service.dart';

class LivePlayerScreen extends StatelessWidget {
  const LivePlayerScreen._({required this.live, required this.grant});
  final LiveBroadcast live;
  final LiveAccessGrant grant;

  static Future<void> open(
    BuildContext context, {
    required LiveBroadcast live,
    required LiveAccessGrant grant,
    bool replace = false,
  }) {
    if (grant.liveId != live.id) return Future.value();
    final route = MaterialPageRoute<void>(
      builder: (_) => LivePlayerScreen._(live: live, grant: grant),
    );
    return replace
        ? Navigator.of(context).pushReplacement(route)
        : Navigator.of(context).push(route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101514),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101514),
        foregroundColor: Colors.white,
        title: const Text(
          'LIVE',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ColoredBox(
                color: Colors.black,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.church_rounded,
                      size: 120,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    Container(
                      width: 68,
                      height: 68,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: AppTheme.primary,
                        size: 44,
                      ),
                    ),
                    Positioned(
                      left: 16,
                      top: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE34848),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    live.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '현재 Mock Player 화면입니다. 실제 스트림은 Backend 연동 단계에서 연결합니다.',
                    style: TextStyle(color: Color(0xFF9EAAA6), height: 1.45),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

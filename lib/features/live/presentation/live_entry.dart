import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/permission/app_permission.dart';
import '../../home/domain/home_models.dart';
import 'live_password_screen.dart';
import 'live_player_screen.dart';

abstract final class LiveEntry {
  static Future<void> open(BuildContext context, LiveBroadcast live) async {
    final state = AppScope.of(context);
    if (state.has(AppPermission.liveAccess)) {
      final grant = state.liveAccessService.grantByPermission(live.id);
      if (context.mounted)
        LivePlayerScreen.open(context, live: live, grant: grant);
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => LivePasswordScreen(
          live: live,
          accessService: state.liveAccessService,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/app_state.dart';
import 'core/auth/mock_auth_repository.dart';
import 'features/home/data/mock_home_repository.dart';
import 'features/live/data/mock_live_access_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChurchApp(
      appState: AppState(
        authRepository: MockAuthRepository(),
        homeRepository: MockHomeRepository(),
        liveAccessService: MockLiveAccessService(),
      ),
    ),
  );
}

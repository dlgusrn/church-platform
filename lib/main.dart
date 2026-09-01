import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/app_state.dart';
import 'core/auth/mock_auth_repository.dart';
import 'core/mock/mock_app_data_store.dart';
import 'core/permission/mock_role_repository.dart';
import 'features/church/data/mock_church_repository.dart';
import 'features/church/data/mock_membership_repository.dart';
import 'features/home/data/mock_home_repository.dart';
import 'features/live/data/mock_live_access_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final store = MockAppDataStore();
  runApp(
    ChurchApp(
      appState: AppState(
        authRepository: MockAuthRepository(store),
        churchRepository: MockChurchRepository(store),
        membershipRepository: MockMembershipRepository(store),
        roleRepository: MockRoleRepository(store),
        homeRepository: MockHomeRepository(),
        liveAccessService: MockLiveAccessService(),
      ),
    ),
  );
}

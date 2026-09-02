import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'app/app.dart';
import 'app/app_state.dart';
import 'core/auth/api_auth_repository.dart';
import 'core/auth/mock_auth_repository.dart';
import 'core/mock/mock_app_data_store.dart';
import 'core/network/api_client.dart';
import 'core/network/api_config.dart';
import 'core/network/http_transport.dart';
import 'core/network/token_store.dart';
import 'core/permission/api_role_repository.dart';
import 'core/permission/mock_role_repository.dart';
import 'features/church/data/api_church_repository.dart';
import 'features/church/data/api_membership_repository.dart';
import 'features/church/data/mock_church_repository.dart';
import 'features/church/data/mock_membership_repository.dart';
import 'features/home/data/mock_home_repository.dart';
import 'features/home/data/api_home_repository.dart';
import 'features/live/data/mock_live_access_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  late final AppState appState;
  if (kDebugMode && ApiConfig.useMockRepositories) {
    final store = MockAppDataStore();
    appState = AppState(
      authRepository: MockAuthRepository(store),
      churchRepository: MockChurchRepository(store),
      membershipRepository: MockMembershipRepository(store),
      roleRepository: MockRoleRepository(store),
      homeRepository: MockHomeRepository(),
      liveAccessService: MockLiveAccessService(),
    );
  } else {
    Uri baseUri;
    try {
      baseUri = ApiConfig.requireBaseUri();
    } on ApiConfigurationException {
      baseUri = Uri();
    }
    if (kDebugMode) {
      debugPrint('[API] Base URL: $baseUri');
    }
    final client = ApiClient(
      baseUri: baseUri,
      transport: createPlatformHttpTransport(),
      tokenStore: PlatformSecureTokenStore(),
    );
    appState = AppState(
      authRepository: ApiAuthRepository(client),
      churchRepository: ApiChurchRepository(client),
      membershipRepository: ApiMembershipRepository(client),
      roleRepository: ApiRoleRepository(client),
      homeRepository: ApiHomeRepository(client),
      liveAccessService: MockLiveAccessService(),
    );
    client.onSessionExpired = appState.handleSessionExpired;
  }
  await appState.restoreSession();
  runApp(ChurchApp(appState: appState));
}

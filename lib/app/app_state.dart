import 'package:flutter/foundation.dart';

import '../core/auth/auth_repository.dart';
import '../core/permission/app_permission.dart';
import '../core/permission/effective_permission.dart';
import '../features/home/data/home_repository.dart';
import '../features/home/domain/home_models.dart';
import '../features/live/data/live_access_service.dart';
import '../shared/models/user.dart';

enum AppSessionStatus { signedOut, selectingChurch, authenticated }

class AppState extends ChangeNotifier {
  AppState({
    required this.authRepository,
    required this.homeRepository,
    required this.liveAccessService,
  });

  final AuthRepository authRepository;
  final HomeRepository homeRepository;
  final LiveAccessService liveAccessService;

  AppSessionStatus status = AppSessionStatus.signedOut;
  AppUser? currentUser;
  ChurchMembership? activeMembership;
  HomeContent? homeContent;
  bool isBusy = false;
  String? authError;
  final Set<AppPermission> _runtimeAddedPermissions = {};

  Set<AppPermission> get effectivePermissions => {
    ...?activeMembership?.effectivePermissions,
    ..._runtimeAddedPermissions,
  };

  bool has(AppPermission permission) =>
      effectivePermissions.contains(permission);
  bool hasAny(Set<AppPermission> permissions) =>
      EffectivePermission.hasAny(effectivePermissions, permissions);

  Future<void> signIn({
    required String loginId,
    required String password,
  }) async {
    isBusy = true;
    authError = null;
    notifyListeners();
    try {
      final user = await authRepository.signIn(
        loginId: loginId,
        password: password,
      );
      _clearChurchContext();
      currentUser = user;
      if (user.memberships.length == 1) {
        await activateChurch(user.memberships.single);
      } else {
        status = AppSessionStatus.selectingChurch;
      }
    } on AuthException catch (error) {
      authError = error.message;
      status = AppSessionStatus.signedOut;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> activateChurch(ChurchMembership membership) async {
    if (currentUser?.memberships.contains(membership) != true) return;
    _runtimeAddedPermissions.clear();
    activeMembership = membership;
    homeContent = null;
    status = AppSessionStatus.authenticated;
    notifyListeners();
    final content = await homeRepository.getHomeContent(membership.church.id);
    if (activeMembership == membership) {
      homeContent = content;
      notifyListeners();
    }
  }

  void requestChurchSelection() {
    if ((currentUser?.memberships.length ?? 0) > 1) {
      status = AppSessionStatus.selectingChurch;
      notifyListeners();
    }
  }

  void cancelChurchSelection() {
    if (activeMembership != null) {
      status = AppSessionStatus.authenticated;
      notifyListeners();
    }
  }

  void toggleRuntimePermission(AppPermission permission) {
    if (_runtimeAddedPermissions.contains(permission)) {
      _runtimeAddedPermissions.remove(permission);
    } else {
      _runtimeAddedPermissions.add(permission);
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    await authRepository.signOut();
    currentUser = null;
    _clearChurchContext();
    status = AppSessionStatus.signedOut;
    authError = null;
    notifyListeners();
  }

  void _clearChurchContext() {
    activeMembership = null;
    homeContent = null;
    _runtimeAddedPermissions.clear();
  }
}

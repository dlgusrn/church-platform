import 'package:flutter/foundation.dart';

import '../core/auth/auth_repository.dart';
import '../core/permission/app_permission.dart';
import '../core/permission/app_role.dart';
import '../core/permission/effective_permission.dart';
import '../core/permission/role_repository.dart';
import '../features/church/data/church_repository.dart';
import '../features/church/data/membership_repository.dart';
import '../features/home/data/home_repository.dart';
import '../features/home/domain/home_models.dart';
import '../features/live/data/live_access_service.dart';
import '../shared/models/church.dart';
import '../shared/models/user.dart';

enum AppSessionStatus {
  signedOut,
  selectingJoinChurch,
  approvalPending,
  membershipStatus,
  selectingChurch,
  authenticated,
}

class AppState extends ChangeNotifier {
  AppState({
    required this.authRepository,
    required this.churchRepository,
    required this.membershipRepository,
    required this.roleRepository,
    required this.homeRepository,
    required this.liveAccessService,
  });

  final AuthRepository authRepository;
  final ChurchRepository churchRepository;
  final MembershipRepository membershipRepository;
  final RoleRepository roleRepository;
  final HomeRepository homeRepository;
  final LiveAccessService liveAccessService;

  AppSessionStatus status = AppSessionStatus.signedOut;
  AppUser? currentUser;
  ChurchMembership? activeMembership;
  ChurchMembership? previewMembership;
  ChurchMembership? lastRequestedMembership;
  HomeContent? homeContent;
  List<Church> churches = [];
  List<AppRole> roles = [];
  bool isBusy = false;
  String? authError;
  String? registrationError;
  String? membershipError;
  final Set<AppPermission> _runtimeAddedPermissions = {};

  ChurchMembership? get currentChurchMembership =>
      activeMembership ?? previewMembership;
  Set<AppPermission> get effectivePermissions => {
    ...?activeMembership?.effectivePermissions,
    ..._runtimeAddedPermissions,
  };
  List<ChurchMembership> get approvedMemberships =>
      currentUser?.approvedMemberships ?? const [];
  List<Church> get joinableChurches {
    final existingIds =
        currentUser?.memberships
            .map((membership) => membership.church.id)
            .toSet() ??
        <String>{};
    return churches
        .where((church) => !existingIds.contains(church.id))
        .toList();
  }

  bool has(AppPermission permission) =>
      effectivePermissions.contains(permission);
  bool hasAny(Set<AppPermission> permissions) =>
      EffectivePermission.hasAny(effectivePermissions, permissions);

  Future<void> loadCatalogs() async {
    final results = await Future.wait([
      churchRepository.getChurches(),
      roleRepository.getRoles(),
    ]);
    churches = results[0] as List<Church>;
    roles = results[1] as List<AppRole>;
    notifyListeners();
  }

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
      await loadCatalogs();
      final approved = user.approvedMemberships;
      if (approved.length == 1) {
        await activateChurch(approved.single);
      } else if (approved.length > 1) {
        status = AppSessionStatus.selectingChurch;
      } else {
        final pending = user.memberships
            .where((item) => item.status == MembershipStatus.pending)
            .firstOrNull;
        if (pending != null) {
          lastRequestedMembership = pending;
          status = AppSessionStatus.approvalPending;
        } else if (user.memberships.isNotEmpty) {
          status = AppSessionStatus.membershipStatus;
        } else {
          status = AppSessionStatus.selectingJoinChurch;
        }
      }
    } on AuthException catch (error) {
      authError = error.message;
      status = AppSessionStatus.signedOut;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String name,
    required String loginId,
    required String password,
  }) async {
    isBusy = true;
    registrationError = null;
    notifyListeners();
    try {
      currentUser = await authRepository.register(
        RegisterRequest(name: name, loginId: loginId, password: password),
      );
      _clearChurchContext();
      await loadCatalogs();
      status = AppSessionStatus.selectingJoinChurch;
      return true;
    } on AuthException catch (error) {
      registrationError = error.message;
      return false;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<ChurchMembership?> requestJoin(
    Church church, {
    required bool onboarding,
  }) async {
    membershipError = null;
    try {
      final membership = await membershipRepository.requestJoin(
        userId: currentUser!.id,
        churchId: church.id,
      );
      await refreshCurrentUser();
      lastRequestedMembership = membership;
      if (onboarding) status = AppSessionStatus.approvalPending;
      notifyListeners();
      return membership;
    } on MembershipException catch (error) {
      membershipError = error.message;
      notifyListeners();
      return null;
    }
  }

  Future<void> continueFromApproval() async {
    final membership = lastRequestedMembership;
    if (membership == null) return;
    previewMembership = membership;
    activeMembership = null;
    status = AppSessionStatus.authenticated;
    await _loadHome(membership);
  }

  Future<void> activateChurch(ChurchMembership membership) async {
    if (!membership.isApproved ||
        currentUser?.memberships.any((item) => item.id == membership.id) !=
            true)
      return;
    _runtimeAddedPermissions.clear();
    previewMembership = null;
    activeMembership = membership;
    status = AppSessionStatus.authenticated;
    await _loadHome(membership);
  }

  Future<void> _loadHome(ChurchMembership membership) async {
    homeContent = null;
    notifyListeners();
    final content = await homeRepository.getHomeContent(membership.church.id);
    if (currentChurchMembership?.id == membership.id) {
      homeContent = content;
      notifyListeners();
    }
  }

  void requestChurchSelection() {
    if (approvedMemberships.length > 1) {
      status = AppSessionStatus.selectingChurch;
      notifyListeners();
    }
  }

  void cancelChurchSelection() {
    if (currentChurchMembership != null) {
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

  Future<void> refreshCurrentUser() async {
    final userId = currentUser?.id;
    if (userId == null) return;
    currentUser = await authRepository.getUser(userId);
    if (activeMembership != null) {
      activeMembership = currentUser?.memberships
          .where((item) => item.id == activeMembership!.id)
          .firstOrNull;
    }
    if (previewMembership != null) {
      previewMembership = currentUser?.memberships
          .where((item) => item.id == previewMembership!.id)
          .firstOrNull;
      if (previewMembership?.isApproved == true) {
        activeMembership = previewMembership;
        previewMembership = null;
      }
    }
    notifyListeners();
  }

  Future<AppUser?> userForMembership(ChurchMembership membership) =>
      authRepository.getUser(membership.userId);

  Future<void> approveMembership({
    required ChurchMembership membership,
    required AppRole role,
    required Set<AppPermission> addedPermissions,
    required Set<AppPermission> excludedPermissions,
  }) async {
    await membershipRepository.approve(
      membershipId: membership.id,
      role: role,
      addedPermissions: addedPermissions,
      excludedPermissions: excludedPermissions,
    );
    await refreshCurrentUser();
    notifyListeners();
  }

  Future<void> rejectMembership(ChurchMembership membership) async {
    await membershipRepository.reject(membership.id);
    await refreshCurrentUser();
    notifyListeners();
  }

  Future<void> signOut() async {
    await authRepository.signOut();
    currentUser = null;
    _clearChurchContext();
    status = AppSessionStatus.signedOut;
    authError = null;
    registrationError = null;
    membershipError = null;
    notifyListeners();
  }

  void _clearChurchContext() {
    activeMembership = null;
    previewMembership = null;
    lastRequestedMembership = null;
    homeContent = null;
    _runtimeAddedPermissions.clear();
  }
}

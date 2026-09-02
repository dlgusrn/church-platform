import 'package:flutter/foundation.dart';

import '../core/auth/auth_repository.dart';
import '../core/network/api_client.dart';
import '../core/network/api_config.dart';
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
  restoring,
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

  AppSessionStatus status = AppSessionStatus.restoring;
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
            .where(
              (membership) => membership.status != MembershipStatus.rejected,
            )
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

  Future<void> restoreSession() async {
    status = AppSessionStatus.restoring;
    notifyListeners();
    try {
      final user = await authRepository.restoreSession();
      if (user == null) {
        status = AppSessionStatus.signedOut;
        return;
      }
      currentUser = user;
      await loadCatalogs();
      await _routeAuthenticatedUser(user);
    } catch (error) {
      currentUser = null;
      _clearChurchContext();
      if (error is SessionExpiredException ||
          (error is ApiException && error.statusCode == 401)) {
        await authRepository.signOut();
      }
      authError = _message(error);
      status = AppSessionStatus.signedOut;
    } finally {
      notifyListeners();
    }
  }

  Future<void> loadCatalogs() async {
    churches = await churchRepository.getChurches();
    notifyListeners();
  }

  Future<List<AppRole>> loadRolesForActiveChurch() async {
    final churchId = activeMembership?.church.id;
    if (churchId == null || !has(AppPermission.roleView)) return const [];
    roles = await roleRepository.getRoles(churchId);
    notifyListeners();
    return roles;
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
      await _routeAuthenticatedUser(user);
    } catch (error) {
      authError = _message(error);
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
    } catch (error) {
      registrationError = _message(error);
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
    } catch (error) {
      membershipError = _message(error);
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
    membershipError = null;
    try {
      final breakdown = await membershipRepository.getPermissions(
        membership.id,
      );
      membership = membership.copyWith(
        role: membership.role == null
            ? null
            : AppRole(
                id: membership.role!.id,
                code: membership.role!.code,
                name: membership.role!.name,
                isSystem: membership.role!.isSystem,
                defaultPermissions: breakdown.rolePermissions,
              ),
        addedPermissions: breakdown.grantedPermissions,
        excludedPermissions: breakdown.deniedPermissions,
        resolvedPermissions: breakdown.effectivePermissions,
      );
      _replaceCurrentMembership(membership);
    } catch (error) {
      membershipError = _message(error);
      status = AppSessionStatus.selectingChurch;
      notifyListeners();
      return;
    }
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
      membership.applicantName == null
      ? authRepository.getUser(membership.userId)
      : Future.value(
          AppUser(
            id: membership.userId,
            name: membership.applicantName!,
            loginId: membership.applicantLoginId ?? '',
            memberships: const [],
          ),
        );

  Future<List<ChurchMembership>> getPendingMemberships() async {
    final churchId = activeMembership?.church.id;
    if (churchId == null || !has(AppPermission.memberView)) return const [];
    return membershipRepository.getPendingMemberships(churchId: churchId);
  }

  Future<bool> approveMembership({
    required ChurchMembership membership,
    required AppRole role,
    required Set<AppPermission> addedPermissions,
    required Set<AppPermission> excludedPermissions,
  }) async {
    membershipError = null;
    try {
      await membershipRepository.approve(
        churchId: membership.church.id,
        membershipId: membership.id,
        role: role,
        addedPermissions: addedPermissions,
        excludedPermissions: excludedPermissions,
      );
      await refreshCurrentUser();
      notifyListeners();
      return true;
    } catch (error) {
      membershipError = _message(error);
      notifyListeners();
      return false;
    }
  }

  Future<bool> rejectMembership(ChurchMembership membership) async {
    membershipError = null;
    try {
      await membershipRepository.reject(
        churchId: membership.church.id,
        membershipId: membership.id,
      );
      await refreshCurrentUser();
      notifyListeners();
      return true;
    } catch (error) {
      membershipError = _message(error);
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateMembershipPermissions({
    required ChurchMembership membership,
    required AppRole role,
    required Set<AppPermission> addedPermissions,
    required Set<AppPermission> excludedPermissions,
  }) async {
    membershipError = null;
    try {
      await membershipRepository.updatePermissions(
        churchId: membership.church.id,
        membershipId: membership.id,
        role: role,
        addedPermissions: addedPermissions,
        excludedPermissions: excludedPermissions,
      );
      await refreshCurrentUser();
      final refreshed = currentUser?.memberships
          .where((item) => item.id == membership.id)
          .firstOrNull;
      if (refreshed != null) await activateChurch(refreshed);
      return true;
    } catch (error) {
      membershipError = _message(error);
      notifyListeners();
      return false;
    }
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
    roles = [];
    _runtimeAddedPermissions.clear();
  }

  Future<void> handleSessionExpired() async {
    currentUser = null;
    _clearChurchContext();
    authError = '로그인 세션이 만료되었습니다. 다시 로그인해주세요.';
    status = AppSessionStatus.signedOut;
    notifyListeners();
  }

  Future<void> _routeAuthenticatedUser(AppUser user) async {
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
  }

  void _replaceCurrentMembership(ChurchMembership updated) {
    final user = currentUser;
    if (user == null) return;
    currentUser = user.copyWith(
      memberships: [
        for (final membership in user.memberships)
          if (membership.id == updated.id) updated else membership,
      ],
    );
  }

  static String _message(Object error) => switch (error) {
    AuthException(:final message) => message,
    MembershipException(:final message) => message,
    ApiException(:final message) => message,
    ApiConfigurationException(:final message) => message,
    _ => '요청을 처리하지 못했습니다. 잠시 후 다시 시도해주세요.',
  };
}

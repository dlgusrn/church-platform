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
import '../features/notices/data/notice_repository.dart';
import '../features/notices/domain/notice_models.dart';
import '../features/popup_notices/data/popup_notice_repository.dart';
import '../features/popup_notices/data/popup_suppression_store.dart';
import '../features/popup_notices/domain/popup_notice_models.dart';
import '../features/video/data/video_repository.dart';
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

enum PendingMembershipCheckResult {
  pending,
  approved,
  rejected,
  unavailable,
  error,
}

class AppState extends ChangeNotifier {
  AppState({
    required this.authRepository,
    required this.churchRepository,
    required this.membershipRepository,
    required this.roleRepository,
    required this.homeRepository,
    required this.liveAccessService,
    required this.noticeRepository,
    this.videoRepository,
    this.popupNoticeRepository,
    PopupSuppressionStore? popupSuppressionStore,
  }) : _popupSuppressionStore = popupSuppressionStore;

  final AuthRepository authRepository;
  final ChurchRepository churchRepository;
  final MembershipRepository membershipRepository;
  final RoleRepository roleRepository;
  final HomeRepository homeRepository;
  final LiveAccessService liveAccessService;
  final NoticeRepository noticeRepository;
  final VideoRepository? videoRepository;
  final PopupNoticeRepository? popupNoticeRepository;
  PopupSuppressionStore? _popupSuppressionStore;
  PopupSuppressionStore get popupSuppressionStore =>
      _popupSuppressionStore ??= PopupSuppressionStore();

  AppSessionStatus status = AppSessionStatus.restoring;
  AppUser? currentUser;
  ChurchMembership? activeMembership;
  ChurchMembership? previewMembership;
  ChurchMembership? lastRequestedMembership;
  HomeContent? homeContent;
  List<Notice>? homeNotices;
  String? homeError;
  List<Church> churches = [];
  List<AppRole> roles = [];
  bool isBusy = false;
  String? authError;
  String? registrationError;
  String? membershipError;
  final Set<AppPermission> _runtimeAddedPermissions = {};
  int _homeLoadGeneration = 0;
  int _popupGeneration = 0;
  PopupNotice? pendingPopupNotice;
  bool popupFetchInProgress = false;
  final Set<String> _popupSessionSuppressed = {};
  final Set<String> _popupClaims = {};

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
  String _popupKey(String churchId, String popupId) => '$churchId/$popupId';

  bool claimPendingPopup(PopupNotice popup) =>
      _popupClaims.add(_popupKey(popup.churchId, popup.id));
  void consumePopup(PopupNotice popup) {
    if (pendingPopupNotice?.id == popup.id &&
        pendingPopupNotice?.churchId == popup.churchId) {
      pendingPopupNotice = null;
      notifyListeners();
    }
  }

  void dismissPopupForSession(PopupNotice popup) {
    _popupSessionSuppressed.add(_popupKey(popup.churchId, popup.id));
    consumePopup(popup);
  }

  Future<void> dismissPopupForToday(PopupNotice popup) async {
    await popupSuppressionStore.suppressToday(
      popup.churchId,
      popup.id,
      DateTime.now(),
    );
    dismissPopupForSession(popup);
  }

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

  Future<PendingMembershipCheckResult> checkPendingMembershipApproval() async {
    final requested = lastRequestedMembership;
    if (requested == null) return PendingMembershipCheckResult.unavailable;

    membershipError = null;
    try {
      // The membership response is the source of truth here. A pending
      // membership must never become an active church context merely so the
      // user can leave the confirmation screen.
      await refreshCurrentUser();
      final membership = currentUser?.memberships
          .where((item) => item.id == requested.id)
          .firstOrNull;
      if (membership == null) {
        await _routeAuthenticatedUser(currentUser!);
        notifyListeners();
        return PendingMembershipCheckResult.unavailable;
      }

      lastRequestedMembership = membership;
      switch (membership.status) {
        case MembershipStatus.pending:
          activeMembership = null;
          previewMembership = null;
          status = AppSessionStatus.approvalPending;
          notifyListeners();
          return PendingMembershipCheckResult.pending;
        case MembershipStatus.approved:
          await activateChurch(membership);
          return PendingMembershipCheckResult.approved;
        case MembershipStatus.rejected:
          _clearChurchContext();
          await _routeAuthenticatedUser(currentUser!);
          notifyListeners();
          return PendingMembershipCheckResult.rejected;
      }
    } catch (error) {
      membershipError = _message(error);
      notifyListeners();
      return PendingMembershipCheckResult.error;
    }
  }

  Future<void> activateChurch(ChurchMembership membership) async {
    if (!membership.isApproved ||
        currentUser?.memberships.any((item) => item.id == membership.id) !=
            true)
      return;
    final transitionGeneration = _invalidateHomeContent();
    _runtimeAddedPermissions.clear();
    membershipError = null;
    notifyListeners();
    try {
      final breakdown = await membershipRepository.getPermissions(
        membership.id,
      );
      if (transitionGeneration != _homeLoadGeneration) return;
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
      if (transitionGeneration != _homeLoadGeneration) return;
      membershipError = _message(error);
      status = AppSessionStatus.selectingChurch;
      notifyListeners();
      return;
    }
    previewMembership = null;
    activeMembership = membership;
    status = AppSessionStatus.authenticated;
    await _loadHome(membership);
    _loadCurrentPopup(membership);
  }

  Future<void> _loadHome(ChurchMembership membership) async {
    final loadGeneration = _invalidateHomeContent();
    notifyListeners();
    try {
      final homeFuture = homeRepository.getHomeContent(
        membership.church.id,
        includeSchedules: true,
      );
      final noticesFuture =
          membership.effectivePermissions.contains(AppPermission.noticeView)
          ? noticeRepository.listNotices(membership.church.id)
          : Future.value(const <Notice>[]);
      final results = await Future.wait<Object>([homeFuture, noticesFuture]);
      final content = results[0] as HomeContent;
      final notices = results[1] as List<Notice>;
      if (loadGeneration == _homeLoadGeneration &&
          currentChurchMembership?.id == membership.id) {
        homeContent = content;
        homeNotices = notices;
        notifyListeners();
      }
    } catch (error) {
      if (loadGeneration == _homeLoadGeneration &&
          currentChurchMembership?.id == membership.id) {
        homeError = _message(error);
        notifyListeners();
      }
    }
  }

  Future<void> reloadHome() async {
    final membership = currentChurchMembership;
    if (membership != null) await _loadHome(membership);
  }

  Future<List<WorshipSchedule>> loadManagedWorshipSchedules() async {
    final churchId = activeMembership?.church.id;
    if (churchId == null || !has(AppPermission.scheduleManage)) return const [];
    return homeRepository.getWorshipSchedules(churchId, includeInactive: true);
  }

  Future<WorshipSchedule> saveWorshipSchedule(
    WorshipScheduleDraft draft, {
    String? scheduleId,
  }) async {
    final churchId = activeMembership!.church.id;
    final result = scheduleId == null
        ? await homeRepository.createWorshipSchedule(churchId, draft)
        : await homeRepository.updateWorshipSchedule(
            churchId,
            scheduleId,
            draft,
          );
    await reloadHome();
    return result;
  }

  Future<List<LiveBroadcast>> loadManagedLiveBroadcasts() async {
    final churchId = activeMembership?.church.id;
    if (churchId == null || !has(AppPermission.liveManage)) return const [];
    return homeRepository.getLiveBroadcasts(churchId);
  }

  Future<LiveBroadcast> saveLiveBroadcast(
    LiveBroadcastDraft draft, {
    String? broadcastId,
  }) async {
    final churchId = activeMembership!.church.id;
    final result = broadcastId == null
        ? await homeRepository.createLiveBroadcast(churchId, draft)
        : await homeRepository.updateLiveBroadcast(
            churchId,
            broadcastId,
            draft,
          );
    await reloadHome();
    return result;
  }

  Future<List<Notice>> loadNotices() async {
    final churchId = activeMembership?.church.id;
    if (churchId == null || !has(AppPermission.noticeView)) return const [];
    return noticeRepository.listNotices(churchId);
  }

  Future<Notice> loadNotice(String noticeId) =>
      noticeRepository.getNotice(activeMembership!.church.id, noticeId);

  Future<Notice> saveNotice(NoticeDraft draft, {String? noticeId}) {
    final churchId = activeMembership!.church.id;
    final request = noticeId == null
        ? noticeRepository.createNotice(churchId, draft)
        : noticeRepository.updateNotice(churchId, noticeId, draft);
    return request.then((notice) async {
      await _reloadHomeNotices(churchId);
      return notice;
    });
  }

  Future<void> deleteNotice(String noticeId) async {
    final churchId = activeMembership!.church.id;
    await noticeRepository.deleteNotice(churchId, noticeId);
    await _reloadHomeNotices(churchId);
  }

  Future<List<PopupNotice>> loadPopupNotices() async {
    final churchId = activeMembership?.church.id;
    if (churchId == null ||
        !has(AppPermission.popupNoticeManage) ||
        popupNoticeRepository == null)
      return const [];
    return popupNoticeRepository!.list(churchId);
  }

  Future<PopupNotice> savePopupNotice(PopupNoticeDraft draft, {String? id}) {
    final churchId = activeMembership!.church.id;
    return id == null
        ? popupNoticeRepository!.create(churchId, draft)
        : popupNoticeRepository!.update(churchId, id, draft);
  }

  Future<void> deletePopupNotice(String id) =>
      popupNoticeRepository!.delete(activeMembership!.church.id, id);
  Future<PopupNotice> setPopupNoticeActive(String id, bool value) =>
      popupNoticeRepository!.setActive(activeMembership!.church.id, id, value);
  Future<PopupNotice> uploadPopupImage(
    String id,
    List<int> bytes,
    String filename,
  ) => popupNoticeRepository!.uploadImage(
    activeMembership!.church.id,
    id,
    bytes,
    filename,
  );
  Future<PopupNotice> removePopupImage(String id) =>
      popupNoticeRepository!.removeImage(activeMembership!.church.id, id);
  Future<List<int>> popupImageBytes(String path) =>
      popupNoticeRepository!.imageBytes(path);

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
    _popupSessionSuppressed.clear();
    _popupClaims.clear();
    pendingPopupNotice = null;
    notifyListeners();
  }

  void _clearChurchContext() {
    activeMembership = null;
    previewMembership = null;
    lastRequestedMembership = null;
    _invalidateHomeContent();
    roles = [];
    _runtimeAddedPermissions.clear();
    _popupGeneration++;
    pendingPopupNotice = null;
  }

  Future<void> _loadCurrentPopup(ChurchMembership membership) async {
    final repository = popupNoticeRepository;
    if (repository == null || !membership.isApproved) return;
    final generation = ++_popupGeneration;
    popupFetchInProgress = true;
    notifyListeners();
    try {
      final popup = await repository.current(membership.church.id);
      if (generation != _popupGeneration ||
          activeMembership?.id != membership.id ||
          popup == null)
        return;
      final key = _popupKey(popup.churchId, popup.id);
      if (_popupSessionSuppressed.contains(key) ||
          await popupSuppressionStore.isSuppressedToday(
            popup.churchId,
            popup.id,
            DateTime.now(),
          ))
        return;
      if (generation == _popupGeneration &&
          activeMembership?.id == membership.id) {
        pendingPopupNotice = popup;
        notifyListeners();
      }
    } catch (_) {
      // A popup failure must not block authenticated home entry.
    } finally {
      if (generation == _popupGeneration) {
        popupFetchInProgress = false;
        notifyListeners();
      }
    }
  }

  int _invalidateHomeContent() {
    homeContent = null;
    homeNotices = null;
    homeError = null;
    return ++_homeLoadGeneration;
  }

  Future<void> _reloadHomeNotices(String churchId) async {
    if (!has(AppPermission.noticeView) ||
        activeMembership?.church.id != churchId) {
      return;
    }
    final notices = await noticeRepository.listNotices(churchId);
    if (activeMembership?.church.id == churchId) {
      homeNotices = notices;
      notifyListeners();
    }
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
    HomeDataException(:final message) => message,
    ApiException(:final message) => message,
    ApiConfigurationException(:final message) => message,
    _ => '요청을 처리하지 못했습니다. 잠시 후 다시 시도해주세요.',
  };
}

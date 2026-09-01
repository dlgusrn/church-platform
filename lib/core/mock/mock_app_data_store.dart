import '../../shared/models/church.dart';
import '../../shared/models/user.dart';
import '../permission/app_permission.dart';
import '../permission/app_role.dart';

class MockAppDataStore {
  MockAppDataStore() {
    final now = DateTime(2026, 8, 31);
    users.addAll([
      AppUser(
        id: 'user-a',
        name: '신규 가입자',
        loginId: 'new@church.app',
        memberships: [
          _approved('membership-a-sky', 'user-a', churches[0], emptyRole, now),
          _approved(
            'membership-a-bethel',
            'user-a',
            churches[1],
            emptyRole,
            now,
          ),
        ],
      ),
      AppUser(
        id: 'user-b',
        name: '일반 성도',
        loginId: 'member@church.app',
        memberships: [
          _approved('membership-b-sky', 'user-b', churches[0], memberRole, now),
        ],
      ),
      AppUser(
        id: 'user-c',
        name: '직원 관리자',
        loginId: 'staff@church.app',
        memberships: [
          _approved('membership-c-sky', 'user-c', churches[0], staffRole, now),
          _approved(
            'membership-c-bethel',
            'user-c',
            churches[1],
            memberRole,
            now,
          ),
        ],
      ),
    ]);
  }

  final List<Church> churches = const [
    Church(id: 'sky-gate', name: '하늘문교회'),
    Church(id: 'bethel', name: '브엘성회'),
  ];

  static const emptyRole = AppRole(
    id: 'legacy-new',
    name: '신규 회원',
    defaultPermissions: {},
  );
  static const memberRole = AppRole(
    id: 'member',
    name: '성도',
    defaultPermissions: {AppPermission.liveAccess, AppPermission.vodView},
  );
  static const staffRole = AppRole(
    id: 'staff',
    name: '직원',
    defaultPermissions: {
      AppPermission.liveAccess,
      AppPermission.vodView,
      AppPermission.mediaVideoView,
      AppPermission.mediaAudioView,
      AppPermission.noticeView,
      AppPermission.scheduleView,
      AppPermission.expenseView,
      AppPermission.expenseCreate,
      AppPermission.approvalView,
      AppPermission.attendanceView,
      AppPermission.documentView,
    },
  );
  static final adminRole = AppRole(
    id: 'admin',
    name: '관리자',
    defaultPermissions: Set.unmodifiable(AppPermission.values),
  );

  List<AppRole> get roles => [memberRole, staffRole, adminRole];
  final List<AppUser> users = [];
  final Map<String, String> passwords = {
    'new@church.app': 'test1234',
    'member@church.app': 'test1234',
    'staff@church.app': 'test1234',
  };

  AppUser? userById(String userId) {
    for (final user in users) {
      if (user.id == userId) return user;
    }
    return null;
  }

  void replaceUser(AppUser updated) {
    final index = users.indexWhere((user) => user.id == updated.id);
    if (index >= 0) users[index] = updated;
  }

  static ChurchMembership _approved(
    String id,
    String userId,
    Church church,
    AppRole role,
    DateTime at,
  ) => ChurchMembership(
    id: id,
    userId: userId,
    church: church,
    status: MembershipStatus.approved,
    role: role,
    requestedAt: at,
    approvedAt: at,
  );
}

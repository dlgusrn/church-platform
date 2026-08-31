import '../../shared/models/church.dart';
import '../../shared/models/user.dart';
import '../permission/app_permission.dart';
import 'auth_repository.dart';

class MockAuthRepository implements AuthRepository {
  static const _password = 'test1234';
  static const _skyGate = Church(id: 'sky-gate', name: '하늘문교회');
  static const _bethel = Church(id: 'bethel', name: '브엘성회');

  late final List<AppUser> _users = [
    const AppUser(
      id: 'user-a',
      name: '신규 가입자',
      loginId: 'new@church.app',
      memberships: [
        ChurchMembership(church: _skyGate, roleName: '신규 회원'),
        ChurchMembership(church: _bethel, roleName: '신규 회원'),
      ],
    ),
    const AppUser(
      id: 'user-b',
      name: '일반 성도',
      loginId: 'member@church.app',
      memberships: [
        ChurchMembership(
          church: _skyGate,
          roleName: '성도',
          rolePermissions: {AppPermission.liveAccess, AppPermission.vodView},
        ),
      ],
    ),
    const AppUser(
      id: 'user-c',
      name: '직원 관리자',
      loginId: 'staff@church.app',
      memberships: [
        ChurchMembership(
          church: _skyGate,
          roleName: '직원',
          rolePermissions: {
            AppPermission.liveAccess,
            AppPermission.vodView,
            AppPermission.mediaVideoView,
            AppPermission.mediaVideoDownload,
            AppPermission.mediaAudioView,
            AppPermission.mediaAudioDownload,
            AppPermission.noticeView,
            AppPermission.noticeCreate,
            AppPermission.scheduleView,
            AppPermission.expenseView,
            AppPermission.expenseCreate,
            AppPermission.approvalView,
            AppPermission.attendanceView,
            AppPermission.documentView,
            AppPermission.memberView,
          },
        ),
        ChurchMembership(
          church: _bethel,
          roleName: '성도',
          rolePermissions: {AppPermission.liveAccess, AppPermission.vodView},
        ),
      ],
    ),
  ];

  @override
  List<MockAccountHint> get accountHints => const [
    MockAccountHint(
      label: 'User A · 신규',
      loginId: 'new@church.app',
      description: '권한 없음',
    ),
    MockAccountHint(
      label: 'User B · 성도',
      loginId: 'member@church.app',
      description: 'LIVE + 최근 영상',
    ),
    MockAccountHint(
      label: 'User C · 직원',
      loginId: 'staff@church.app',
      description: '영상 + 음성 + 업무',
    ),
  ];

  @override
  Future<AppUser> signIn({
    required String loginId,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (password != _password)
      throw const AuthException('아이디 또는 비밀번호를 확인해주세요.');
    for (final user in _users) {
      if (user.loginId.toLowerCase() == loginId.trim().toLowerCase())
        return user;
    }
    throw const AuthException('아이디 또는 비밀번호를 확인해주세요.');
  }

  @override
  Future<void> signOut() async {}
}

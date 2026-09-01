import '../../shared/models/user.dart';
import '../mock/mock_app_data_store.dart';
import 'auth_repository.dart';

class MockAuthRepository implements AuthRepository {
  MockAuthRepository([MockAppDataStore? store])
    : store = store ?? MockAppDataStore();
  final MockAppDataStore store;

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
    final normalized = loginId.trim().toLowerCase();
    if (store.passwords[normalized] != password)
      throw const AuthException('아이디 또는 비밀번호를 확인해주세요.');
    for (final user in store.users) {
      if (user.loginId.toLowerCase() == normalized) return user;
    }
    throw const AuthException('아이디 또는 비밀번호를 확인해주세요.');
  }

  @override
  Future<AppUser> register(RegisterRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final normalized = request.loginId.trim().toLowerCase();
    if (request.name.trim().isEmpty ||
        normalized.isEmpty ||
        request.password.isEmpty) {
      throw const AuthException('필수 가입 정보를 모두 입력해주세요.');
    }
    if (store.passwords.containsKey(normalized))
      throw const AuthException('이미 가입된 이메일입니다.');
    final user = AppUser(
      id: 'user-${DateTime.now().microsecondsSinceEpoch}',
      name: request.name.trim(),
      loginId: normalized,
      memberships: [],
    );
    store.users.add(user);
    store.passwords[normalized] = request.password;
    return user;
  }

  @override
  Future<AppUser?> getUser(String userId) async => store.userById(userId);

  @override
  Future<void> signOut() async {}
}

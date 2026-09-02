import '../../shared/models/user.dart';
import '../network/api_client.dart';
import '../network/api_model_mapper.dart';
import 'auth_repository.dart';

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this.client);

  final ApiClient client;
  AppUser? _currentUser;

  @override
  List<MockAccountHint> get accountHints => const [];

  @override
  Future<AppUser?> restoreSession() async {
    if (await client.tokenStore.readRefreshToken() == null &&
        await client.tokenStore.readAccessToken() == null) {
      return null;
    }
    try {
      return await _loadCurrentUser();
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await client.tokenStore.clear();
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<AppUser> signIn({
    required String loginId,
    required String password,
  }) async {
    try {
      final tokens = await client.request(
        'POST',
        '/api/v1/auth/login',
        authenticated: false,
        body: {'identifier': loginId.trim(), 'password': password},
      );
      await client.saveTokens(tokens);
      return await _loadCurrentUser();
    } on ApiException catch (error) {
      throw AuthException(error.message);
    }
  }

  @override
  Future<AppUser> register(RegisterRequest request) async {
    final loginId = request.loginId.trim();
    try {
      await client.request(
        'POST',
        '/api/v1/auth/register',
        authenticated: false,
        body: {
          'name': request.name.trim(),
          if (loginId.contains('@')) 'email': loginId else 'phone': loginId,
          'password': request.password,
        },
      );
      return await signIn(loginId: loginId, password: request.password);
    } on AuthException {
      rethrow;
    } on ApiException catch (error) {
      throw AuthException(error.message);
    }
  }

  @override
  Future<AppUser?> getUser(String userId) async {
    if (_currentUser?.id == userId) return _loadCurrentUser();
    return null;
  }

  Future<AppUser> _loadCurrentUser() async {
    final userJson = await client.get('/api/v1/users/me');
    final user = ApiModelMapper.user(userJson);
    final membershipsJson = await client.get('/api/v1/users/me/memberships');
    final memberships = (membershipsJson as List)
        .map((item) => ApiModelMapper.membership(item, userId: user.id))
        .toList(growable: false);
    _currentUser = ApiModelMapper.user(userJson, memberships: memberships);
    return _currentUser!;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    await client.tokenStore.clear();
  }
}

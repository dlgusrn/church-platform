import '../../shared/models/user.dart';

abstract interface class AuthRepository {
  Future<AppUser> signIn({required String loginId, required String password});
  Future<AppUser> register(RegisterRequest request);
  Future<AppUser?> getUser(String userId);
  Future<void> signOut();
  List<MockAccountHint> get accountHints;
}

class RegisterRequest {
  const RegisterRequest({
    required this.name,
    required this.loginId,
    required this.password,
  });
  final String name;
  final String loginId;
  final String password;
}

class MockAccountHint {
  const MockAccountHint({
    required this.label,
    required this.loginId,
    required this.description,
  });
  final String label;
  final String loginId;
  final String description;
}

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
}

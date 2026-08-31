import '../../shared/models/user.dart';

abstract interface class AuthRepository {
  Future<AppUser> signIn({required String loginId, required String password});
  Future<void> signOut();
  List<MockAccountHint> get accountHints;
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

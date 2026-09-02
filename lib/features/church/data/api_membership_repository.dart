import '../../../core/network/api_client.dart';
import '../../../core/network/api_model_mapper.dart';
import '../../../core/permission/app_permission.dart';
import '../../../core/permission/app_role.dart';
import '../../../shared/models/user.dart';
import 'membership_repository.dart';

class ApiMembershipRepository implements MembershipRepository {
  ApiMembershipRepository(this.client);
  final ApiClient client;

  @override
  Future<ChurchMembership> requestJoin({
    required String userId,
    required String churchId,
  }) async => _membershipRequest(
    () => client.post('/api/v1/churches/$churchId/memberships'),
    userId: userId,
  );

  @override
  Future<List<ChurchMembership>> getPendingMemberships({
    required String churchId,
  }) async {
    try {
      return (await client.get('/api/v1/churches/$churchId/memberships/pending')
              as List)
          .map((item) => ApiModelMapper.membership(item, userId: ''))
          .toList(growable: false);
    } on ApiException catch (error) {
      throw MembershipException(error.message);
    }
  }

  @override
  Future<MembershipPermissionBreakdown> getPermissions(
    String membershipId,
  ) async {
    try {
      return ApiModelMapper.permissionBreakdown(
        await client.get('/api/v1/memberships/$membershipId/permissions'),
      );
    } on ApiException catch (error) {
      throw MembershipException(error.message);
    }
  }

  @override
  Future<ChurchMembership> approve({
    required String churchId,
    required String membershipId,
    required AppRole role,
    Set<AppPermission> addedPermissions = const {},
    Set<AppPermission> excludedPermissions = const {},
  }) => _membershipRequest(
    () => client.post(
      '/api/v1/churches/$churchId/memberships/$membershipId/approve',
      body: _permissionBody(role, addedPermissions, excludedPermissions),
    ),
  );

  @override
  Future<ChurchMembership> reject({
    required String churchId,
    required String membershipId,
  }) => _membershipRequest(
    () => client.post(
      '/api/v1/churches/$churchId/memberships/$membershipId/reject',
    ),
  );

  @override
  Future<ChurchMembership> updatePermissions({
    required String churchId,
    required String membershipId,
    required AppRole role,
    Set<AppPermission> addedPermissions = const {},
    Set<AppPermission> excludedPermissions = const {},
  }) => _membershipRequest(
    () => client.patch(
      '/api/v1/churches/$churchId/memberships/$membershipId/permissions',
      body: _permissionBody(role, addedPermissions, excludedPermissions),
    ),
  );

  Future<ChurchMembership> _membershipRequest(
    Future<dynamic> Function() request, {
    String userId = '',
  }) async {
    try {
      return ApiModelMapper.membership(await request(), userId: userId);
    } on ApiException catch (error) {
      throw MembershipException(error.message);
    }
  }

  static Map<String, dynamic> _permissionBody(
    AppRole role,
    Set<AppPermission> granted,
    Set<AppPermission> denied,
  ) => {
    'role_id': int.parse(role.id),
    'granted_permissions': granted.map((item) => item.code).toList()..sort(),
    'denied_permissions': denied.map((item) => item.code).toList()..sort(),
  };
}

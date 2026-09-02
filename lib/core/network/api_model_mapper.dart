import 'package:flutter/foundation.dart';

import '../permission/app_permission.dart';
import '../permission/app_role.dart';
import '../../features/church/data/membership_repository.dart';
import '../../shared/models/church.dart';
import '../../shared/models/user.dart';
import 'api_client.dart';

abstract final class ApiModelMapper {
  static Church church(dynamic json) {
    final map = asMap(json);
    return Church(
      id: '${map['id']}',
      code: map['code'] as String? ?? '',
      name: map['name'] as String? ?? '',
    );
  }

  static AppRole role(dynamic json, {Iterable<dynamic>? permissions}) {
    final map = asMap(json);
    return AppRole(
      id: '${map['id']}',
      code: map['code'] as String? ?? '',
      name: map['name'] as String? ?? '',
      isSystem: map['is_system'] as bool? ?? false,
      defaultPermissions: parsePermissions(
        permissions ?? map['permissions'] as List? ?? const [],
      ),
    );
  }

  static ChurchMembership membership(dynamic json, {required String userId}) {
    final map = asMap(json);
    final roleJson = map['role'];
    final userJson = map['user'];
    final userMap = userJson is Map ? asMap(userJson) : null;
    return ChurchMembership(
      id: '${map['membership_id']}',
      userId: userMap == null ? userId : '${userMap['id']}',
      church: church(map['church']),
      status: membershipStatus(map['status']),
      role: roleJson == null ? null : role(roleJson),
      resolvedPermissions: parsePermissions(
        map['effective_permissions'] as List? ?? const [],
      ),
      requestedAt: DateTime.parse(map['requested_at'] as String),
      approvedAt: map['approved_at'] == null
          ? null
          : DateTime.parse(map['approved_at'] as String),
      applicantName: userMap?['name'] as String?,
      applicantLoginId:
          userMap?['email'] as String? ?? userMap?['phone'] as String?,
    );
  }

  static AppUser user(
    dynamic json, {
    List<ChurchMembership> memberships = const [],
  }) {
    final map = asMap(json);
    final email = map['email'] as String?;
    final phone = map['phone'] as String?;
    return AppUser(
      id: '${map['id']}',
      name: map['name'] as String? ?? '',
      loginId: email ?? phone ?? '',
      email: email,
      phone: phone,
      memberships: memberships,
    );
  }

  static MembershipPermissionBreakdown permissionBreakdown(dynamic json) {
    final map = asMap(json);
    return MembershipPermissionBreakdown(
      rolePermissions: parsePermissions(
        map['role_permissions'] as List? ?? const [],
      ),
      grantedPermissions: parsePermissions(
        map['granted_permissions'] as List? ?? const [],
      ),
      deniedPermissions: parsePermissions(
        map['denied_permissions'] as List? ?? const [],
      ),
      effectivePermissions: parsePermissions(
        map['effective_permissions'] as List? ?? const [],
      ),
    );
  }

  static Set<AppPermission> parsePermissions(Iterable<dynamic> codes) {
    final parsed = AppPermission.parseCodes(codes);
    if (kDebugMode) {
      for (final code in codes.whereType<String>()) {
        if (AppPermission.fromCode(code) == null) {
          debugPrint('Ignoring unknown backend permission: $code');
        }
      }
    }
    return Set.unmodifiable(parsed);
  }

  static MembershipStatus membershipStatus(dynamic value) => switch (value) {
    'pending' => MembershipStatus.pending,
    'approved' => MembershipStatus.approved,
    'rejected' => MembershipStatus.rejected,
    _ => throw const ApiException(
      statusCode: 0,
      message: '알 수 없는 Membership 상태입니다.',
    ),
  };

  static Map<String, dynamic> asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    throw const ApiException(statusCode: 0, message: '서버 응답 형식이 올바르지 않습니다.');
  }
}

import '../../core/permission/app_permission.dart';
import '../../core/permission/app_role.dart';
import '../../core/permission/effective_permission.dart';
import 'church.dart';

enum MembershipStatus { pending, approved, rejected }

class ChurchMembership {
  const ChurchMembership({
    required this.id,
    required this.userId,
    required this.church,
    required this.status,
    required this.requestedAt,
    this.role,
    this.addedPermissions = const {},
    this.excludedPermissions = const {},
    this.resolvedPermissions,
    this.approvedAt,
    this.applicantName,
    this.applicantLoginId,
  });

  final String id;
  final String userId;
  final Church church;
  final MembershipStatus status;
  final AppRole? role;
  final Set<AppPermission> addedPermissions;
  final Set<AppPermission> excludedPermissions;
  final Set<AppPermission>? resolvedPermissions;
  final DateTime requestedAt;
  final DateTime? approvedAt;
  final String? applicantName;
  final String? applicantLoginId;

  bool get isApproved => status == MembershipStatus.approved;
  String get roleName => role?.name ?? 'Role 미지정';

  Set<AppPermission> get effectivePermissions {
    if (!isApproved) return {};
    if (resolvedPermissions != null) return resolvedPermissions!;
    if (role == null) return {};
    return EffectivePermission.calculate(
      rolePermissions: role!.defaultPermissions,
      addedPermissions: addedPermissions,
      excludedPermissions: excludedPermissions,
    );
  }

  ChurchMembership copyWith({
    MembershipStatus? status,
    AppRole? role,
    Set<AppPermission>? addedPermissions,
    Set<AppPermission>? excludedPermissions,
    Set<AppPermission>? resolvedPermissions,
    DateTime? approvedAt,
  }) => ChurchMembership(
    id: id,
    userId: userId,
    church: church,
    status: status ?? this.status,
    role: role ?? this.role,
    addedPermissions: addedPermissions ?? this.addedPermissions,
    excludedPermissions: excludedPermissions ?? this.excludedPermissions,
    resolvedPermissions: resolvedPermissions ?? this.resolvedPermissions,
    requestedAt: requestedAt,
    approvedAt: approvedAt ?? this.approvedAt,
    applicantName: applicantName,
    applicantLoginId: applicantLoginId,
  );
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.loginId,
    required this.memberships,
    this.email,
    this.phone,
  });
  final String id;
  final String name;
  final String loginId;
  final String? email;
  final String? phone;
  final List<ChurchMembership> memberships;

  List<ChurchMembership> get approvedMemberships =>
      memberships.where((membership) => membership.isApproved).toList();

  AppUser copyWith({List<ChurchMembership>? memberships}) => AppUser(
    id: id,
    name: name,
    loginId: loginId,
    email: email,
    phone: phone,
    memberships: memberships ?? this.memberships,
  );
}

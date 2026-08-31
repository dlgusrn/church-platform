import 'package:flutter/widgets.dart';

import '../../app/app_scope.dart';
import '../../core/permission/app_permission.dart';

class PermissionGuard extends StatelessWidget {
  const PermissionGuard({
    super.key,
    this.permission,
    this.anyOf,
    required this.child,
  });
  final AppPermission? permission;
  final Set<AppPermission>? anyOf;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final allowed = permission != null
        ? state.has(permission!)
        : state.hasAny(anyOf ?? const {});
    return allowed ? child : const SizedBox.shrink();
  }
}

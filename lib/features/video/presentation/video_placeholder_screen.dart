import 'package:flutter/material.dart';

import '../../../core/permission/app_permission.dart';
import '../../../shared/widgets/permission_guard.dart';
import '../../shared/presentation/placeholder_content.dart';

class VideoPlaceholderScreen extends StatelessWidget {
  const VideoPlaceholderScreen({super.key});
  @override
  Widget build(BuildContext context) => const PermissionGuard(
    anyOf: videoNavigationPermissions,
    child: PlaceholderContent(
      title: '영상',
      message: 'YouTube 다시보기와 NAS 영상을\n한곳에서 만날 수 있도록 준비 중입니다.',
      icon: Icons.video_library_outlined,
    ),
  );
}

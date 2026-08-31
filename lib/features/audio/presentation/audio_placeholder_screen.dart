import 'package:flutter/material.dart';

import '../../../core/permission/app_permission.dart';
import '../../../shared/widgets/permission_guard.dart';
import '../../shared/presentation/placeholder_content.dart';

class AudioPlaceholderScreen extends StatelessWidget {
  const AudioPlaceholderScreen({super.key});
  @override
  Widget build(BuildContext context) => const PermissionGuard(
    permission: AppPermission.mediaAudioView,
    child: PlaceholderContent(
      title: '음성',
      message: '설교와 예배 음성 콘텐츠를\n편리하게 들을 수 있도록 준비 중입니다.',
      icon: Icons.headphones_outlined,
    ),
  );
}
